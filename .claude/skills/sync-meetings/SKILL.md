---
name: sync-meetings
description: Google Meet付きカレンダー予定の文字起こし・Geminiメモを取得し、議事録としてvaultに書き出す
user-invocable: true
argument-hint: "[日付|イベントタイトル] (省略時は今日。例: today, yesterday, 2026-04-03, 4/3, スプリントレビュー)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# sync-meetings

Google Meet 付きカレンダー予定の文字起こし（トランスクリプト）・Gemini 会議メモを取得し、構造化された議事録として vault に書き出す。

## Output

- `{vault.path}/journal/meetings/{yyyyMMdd}-{sanitized-title}.md`
- 複数の会議がある場合は会議ごとに個別ファイル

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Dependencies

`gws` CLI (Google Workspace CLI) を使用する。

必要スコープ（`gws auth status` で確認）:
- `https://www.googleapis.com/auth/calendar.readonly`
- `https://www.googleapis.com/auth/meetings.space.readonly`
- `https://www.googleapis.com/auth/documents.readonly`
- `https://www.googleapis.com/auth/drive.readonly`

`gws` 実行時の注意:
- `Using keyring backend: keyring` は stderr に出る。JSON パース時は `2>/dev/null` で捨てること
- token_cache が古くなっていると 403 が出る場合がある。その場合は `rm ~/.config/gws/token_cache.json` で再取得させる

## Procedure

### 1. 設定と日時の取得

- `config.yaml` を読み、`vault.path` を取得する
- `date` コマンドで**現在の日時**を取得する（推測しない）
- 引数から対象を決定する:
  - 引数なし or `today` → 今日
  - `yesterday` → 昨日
  - `YYYY-MM-DD` or `M/D` → 指定日
  - それ以外 → イベントタイトルのフィルタとして扱い、対象日は今日

```bash
NOW=$(date '+%Y-%m-%dT%H:%M:%S')
TODAY=$(date '+%Y-%m-%d')
```

### 2. Google Calendar イベントの取得

`gws calendar events list` で対象日の予定を取得する。

```bash
gws calendar events list --params '{
  "calendarId":"primary",
  "timeMin":"{TARGET_DATE}T00:00:00+09:00",
  "timeMax":"{TARGET_DATE}T23:59:59+09:00",
  "singleEvents":true,
  "orderBy":"startTime"
}' --format json 2>/dev/null
```

フィルタ条件:
- `conferenceData.conferenceId` が存在するイベント（Google Meet 付き）
- 引数がイベントタイトルの場合、`summary` に部分一致するものに絞り込む
- 終日イベント（`start.date` だけで `start.dateTime` がないもの）は除外

各イベントから以下を抽出する:
- `summary`（タイトル）
- `start.dateTime` / `end.dateTime`
- `attendees[]`（`displayName` 優先、なければメールローカル部）
- `conferenceData.conferenceId` ← **Meet 会議コード**
- `conferenceData.entryPoints[].uri` のうち `https://meet.google.com/` で始まるもの（Meet リンク）

Meet 付きイベントがない場合は「対象日に Google Meet 付きのイベントが見つかりませんでした」と報告して終了する。

### 3. ConferenceRecord の特定

各イベントについて `space.meeting_code` で絞り込み、対象日の conferenceRecord を特定する。

```bash
gws meet conferenceRecords list --params "{
  \"filter\":\"space.meeting_code=\\\"$MEETING_CODE\\\" AND start_time>=\\\"${TARGET_DATE}T00:00:00Z\\\" AND start_time<=\\\"${NEXT_DATE}T00:00:00Z\\\"\"
}" --format json 2>/dev/null
```

複数レコードが返った場合はイベントの開始時刻に最も近いものを選ぶ。
該当レコードがない場合は「まだ会議記録が生成されていない」として扱い、イベントメタデータのみで出力する。

### 4. Transcript / SmartNotes / Participants の取得

conferenceRecord の `name`（例: `conferenceRecords/xxx`）を使って各リソースを取得する。

```bash
# transcripts
gws meet conferenceRecords transcripts list --params "{\"parent\":\"$CR_NAME\"}" --format json 2>/dev/null

# smartNotes (Geminiメモ)
gws meet conferenceRecords smartNotes list --params "{\"parent\":\"$CR_NAME\"}" --format json 2>/dev/null

# participants (参加者名)
gws meet conferenceRecords participants list --params "{\"parent\":\"$CR_NAME\"}" --format json 2>/dev/null
```

### 5. Transcript entries の取得

transcript が存在する場合、発言単位のエントリを取得する。`--page-all` で自動ページング。

```bash
gws meet conferenceRecords transcripts entries list \
  --params "{\"parent\":\"$TRANSCRIPT_NAME\",\"pageSize\":100}" \
  --page-all --page-limit 20 \
  --format json 2>/dev/null
```

各 entry は以下を持つ:
- `startTime` / `endTime`
- `participant`（participants list と突き合わせて話者名に変換）
- `text`（発言内容）

`participant` リソース名から participants list の `signedinUser.displayName` に名前解決する。

### 6. SmartNotes ドキュメントの取得

smartNotes が存在する場合、`docsDestination.document` を使って Doc 本文を取得する。

```bash
gws docs documents get --params "{\"documentId\":\"$DOC_ID\"}" --format json 2>/dev/null
```

レスポンスの `body.content[]` を走査し、`paragraph.elements[].textRun.content` を連結してプレーンテキスト化する。

### 7. 要約・構造化

取得したデータを統合し、Output Template に沿って議事録を生成する。

**要約のルール:**
- データソース（transcript entries / smartNotes / event メタデータ）にない情報は推測しない
- transcript entries が多い会議は要点に絞る（1ファイル200行以内）
- 話者ごとの主張を整理し、時系列の雑談は省略してよい
- smartNotes があればそれを優先的に使い、transcript で補完する
- アクションアイテムは「誰が」「何を」「いつまでに」を明確にする

### 8. vault への書き出し

出力先: `{vault.path}/journal/meetings/{yyyyMMdd}-{sanitized-title}.md`

**ファイル名のサニタイズ:**
- スペースをハイフンに変換
- 英数字・ハイフン・日本語のみ残す
- 連続するハイフンを1つに
- 50文字以内（日付部分除く）
- 例: `20260403-スプリントレビュー.md`

`journal/meetings/` ディレクトリがなければ作成する:
```bash
mkdir -p "{vault.path}/journal/meetings"
```

同じ日の同じ会議の再実行は**上書き**する。

### 9. vault へのコミット

```bash
bash scripts/commit-vault.sh
```

## Output Template

```markdown
---
source: google-meet
type: meeting-note
meeting_date: YYYY-MM-DD
meeting_time: "HH:MM-HH:MM"
collected_at: YYYY-MM-DDThh:mm
ttl: 30d
auto_generated: true
has_transcript: true/false
has_gemini_notes: true/false
---

# {Meeting Title}

- **日時**: YYYY-MM-DD HH:MM - HH:MM
- **参加者**: {参加者リスト（表示名, カンマ区切り）}
- **Meet**: {Meet link}

## 概要

{会議全体の要約を3-5文で。何のための会議で、何が話されたかの概要}

## 議論した重要事項

- **{トピック1}**: {議論の要点}
- **{トピック2}**: {議論の要点}

## 決定事項

- {決定事項1}
- {決定事項2}

## アクションアイテム

| 担当 | タスク | 期限 |
|------|--------|------|
| {名前} | {やること} | {期限があれば} |

## 残論点・TODO

- {持ち越しになった議題}
- {次回までに確認すべきこと}

---

<details>
<summary>ソースドキュメント</summary>

- Transcript Doc: {Google Docs URL or "なし"}
- Gemini Notes Doc: {Google Docs URL or "なし"}
- ConferenceRecord: {conferenceRecords/... or "なし"}

</details>
```

## Rules

- `date` コマンドで日時を取得する。推測しない
- データソースにない情報は書かない。推測で議事録を埋めない
- 文字起こしも Gemini メモも見つからない場合は、イベントメタデータのみで簡易ノートを作成し、`## 概要` に「文字起こし・メモが見つかりませんでした」と記載する
- 参加者名は表示名を使用する（メールアドレスのフル表記は含めない）
- 1ファイル200行以内を目安にする。長い会議は要点に絞る
- frontmatter の `auto_generated` は `true`
- 同じ日の同じ会議の再実行は上書き
- 複数の会議がある場合は各会議ごとに個別ファイルを作成する
- `gws` コマンドの stderr は `2>/dev/null` で捨て、stdout のみを JSON パースする
