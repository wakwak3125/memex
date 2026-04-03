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
  - ToolSearch
  - mcp__claude_ai_Google_Calendar__gcal_list_events
  - mcp__claude_ai_Google_Calendar__gcal_get_event
  - mcp__composio__COMPOSIO_SEARCH_TOOLS
  - mcp__composio__COMPOSIO_GET_TOOL_SCHEMAS
  - mcp__composio__COMPOSIO_MULTI_EXECUTE_TOOL
  - mcp__composio__COMPOSIO_MANAGE_CONNECTIONS
  - mcp__composio__COMPOSIO_WAIT_FOR_CONNECTIONS
---

# sync-meetings

Google Meet 付きカレンダー予定の文字起こし（トランスクリプト）・Gemini 会議メモを取得し、構造化された議事録として vault に書き出す。

## Output

- `{vault.path}/journal/meetings/{yyyyMMdd}-{sanitized-title}.md`
- 複数の会議がある場合は会議ごとに個別ファイル

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

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

### 2. Composio ツール探索と接続確認

Google Docs のドキュメント取得に Composio を使用する。

1. `COMPOSIO_SEARCH_TOOLS` で Google Docs 系ツールを探索する:
   ```
   queries: [{"use_case": "fetch and read a Google Docs document content"}]
   session: {"generate_id": true}
   ```
2. 接続状態を確認する。`googledocs` が未接続の場合:
   - `COMPOSIO_MANAGE_CONNECTIONS(toolkits: ["googledocs"])` で認証リンクを取得
   - ユーザーに認証リンクを提示する
   - `COMPOSIO_WAIT_FOR_CONNECTIONS(toolkits: ["googledocs"])` で接続完了を待つ
3. `COMPOSIO_GET_TOOL_SCHEMAS` で `GOOGLEDOCS_GET_DOCUMENT_PLAINTEXT` と `GOOGLEDOCS_SEARCH_DOCUMENTS` のスキーマを取得する

以降、Composio ツールの実行にはすべて `COMPOSIO_MULTI_EXECUTE_TOOL` を使用する。`session_id` は探索時に取得した ID を引き継ぐこと。

### 3. Google Calendar イベントの取得

`gcal_list_events` で対象日の予定を取得する。

```
calendarId: "primary"
timeMin: "{TARGET_DATE}T00:00:00"
timeMax: "{TARGET_DATE}T23:59:59"
timeZone: "Asia/Tokyo"
```

フィルタ条件:
- `conferenceData` に Google Meet が含まれるイベント（Meet リンクがあるもの）
- 引数がイベントタイトルの場合、タイトルに部分一致するものに絞り込む
- 終日イベントは除外する

Meet 付きイベントがない場合は「対象日に Google Meet 付きのイベントが見つかりませんでした」と報告して終了する。

### 4. イベント詳細の取得

各 Meet イベントについて `gcal_get_event` で詳細を取得する。

```
calendarId: "primary"
eventId: "{イベントID}"
```

以下を抽出する:
- イベントタイトル (summary)
- 開始・終了時刻
- 参加者リスト (attendees) — 表示名を優先、なければメールアドレスのローカル部
- Meet リンク (conferenceData.entryPoints[].uri)
- 添付ファイル (attachments[]) — Google Docs へのリンク

### 5. トランスクリプト・Gemini メモの発見

#### 5a. イベント添付ファイルから探す（優先）

`attachments[]` から以下のパターンに一致する Google Docs を抽出する:
- タイトルに "Transcript" / "transcript" / "文字起こし" を含む → **トランスクリプト**
- タイトルに "Notes" / "notes" / "メモ" / "Meeting notes" を含む → **Gemini メモ**
- URL パターン: `https://docs.google.com/document/d/{docId}/...` から `docId` を抽出する

#### 5b. Google Docs 検索（フォールバック）

添付ファイルからドキュメントが見つからない場合、Composio の `GOOGLEDOCS_SEARCH_DOCUMENTS` で検索する:

```
query: "{イベントタイトル}"
modified_after: "{TARGET_DATE}T00:00:00Z"
max_results: 5
```

検索結果からトランスクリプト・Gemini メモを同定する:
- ファイル名に "Transcript" を含む → トランスクリプト
- ファイル名に "Notes" / "Meeting notes" を含む → Gemini メモ

### 6. ドキュメント内容の取得

発見した各ドキュメントについて、Composio の `GOOGLEDOCS_GET_DOCUMENT_PLAINTEXT` で内容を取得する:

```
COMPOSIO_MULTI_EXECUTE_TOOL:
  tool_name: "GOOGLEDOCS_GET_DOCUMENT_PLAINTEXT"
  arguments: {"document_id": "{docId}"}
  session_id: "{session_id}"
```

レスポンスの `response.data.plain_text` からテキストを取得する。

### 7. 要約・構造化

取得したトランスクリプト・Gemini メモ・イベントメタデータを統合し、以下のテンプレートに沿って議事録を生成する。

**要約のルール:**
- データソースにない情報は推測しない
- トランスクリプトから議論の要点を抽出し、発言者ごとの主張を整理する
- Gemini メモがあればそれも参照し、補完的に使う
- アクションアイテムは「誰が」「何を」「いつまでに」を明確にする
- 1ファイル200行以内を目安にする

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
source: google-calendar
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

- Transcript: {Google Docs URL or "なし"}
- Gemini Notes: {Google Docs URL or "なし"}

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
