---
name: daily-planner
description: 指定日のカレンダー・Linear・Slackを統合してTODOを生成しjournalに書き出す
user-invocable: true
argument-hint: "[日付] (省略時は明日。例: today, tomorrow, 2026-04-05, 4/5)"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - ToolSearch
  - mcp__claude_ai_Google_Calendar__gcal_list_events
  - mcp__claude_ai_Linear__list_issues
  - mcp__claude_ai_Linear__list_cycles
  - mcp__claude_ai_Linear__get_issue
---

# daily-planner

指定日の TODO を自動生成し、journal に書き出す。
カレンダー、Linear、直近の Slack snapshot を統合して1日の見通しを作る。

## Output

- `{vault.path}/journal/{対象日}.md` に新規作成 or 更新

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 1. 設定と日時の取得

- `config.yaml` を読み、`vault.path` を取得する
- `date` コマンドで**現在の日時**を取得する（推測しない）
- 引数から対象日を決定する:
  - 引数なし or `tomorrow` → 明日
  - `today` → 今日
  - `YYYY-MM-DD` or `M/D` → 指定日

```bash
NOW=$(date '+%H:%M')
# 対象日は引数に応じて決定
TARGET_DATE="2026-04-02"  # 例
```

### 2. Google Calendar の取得

`gcal_list_events` で対象日の予定を取得する。

```
calendarId: "primary"
timeMin: "{TARGET_DATE}T00:00:00"
timeMax: "{TARGET_DATE}T23:59:59"
timeZone: "Asia/Tokyo"
condenseEventDetails: true
```

イベントを以下に分類:
- **ミーティング**: `eventType: "default"` で `numAttendees >= 2`
- **作業ブロック**: `eventType: "focusTime"` または summary に「作業」を含む
- **プライベート**: `eventType: "outOfOffice"` または育児・登園系
- **Reclaim 自動生成**: description に "Reclaim" を含む（Decompress, ランチ等）

### 3. Linear Issue の取得

`list_issues(assignee="me", limit=20, orderBy="updatedAt")` で自分の Issue を取得。

以下のステータスに絞る:
- In Progress
- Todo
- In Review

### 4. Slack snapshot の確認

対象日の前日の snapshot `{vault.path}/snapshot/{前日}/slack.md` が存在すれば読み込み、未対応のアクションアイテムがないか確認する。
対象日が今日の場合は今日の snapshot も確認する。

### 5. TODO の生成

収集した情報を統合して以下の構造で TODO を生成する:

```markdown
## TODO

### タイムライン
- 07:00-08:30 登園
- 10:00-10:30 [EMR-K] スプリントレビュー
- 10:30-11:30 [EMR-K] スプリントレトロ
- ...
- 13:15-18:00 ✏ 作業時間
- 18:00-21:00 育児タイム

### 開発
1. {Issue ID} {タイトル}（{ステータス}）
2. ...

### 対応・準備
- {Slack や前日の文脈から拾ったアクションアイテム}

### 事務
- {勤怠・経費等、直近の Slack で言及されたもの}
```

#### 生成ルール

- タイムラインはミーティングと大きなブロックのみ。Decompress 等の短い自動ブロックは省略可
- 開発 Issue は優先度順（In Progress > In Review > Todo）
- Slack からのアクションアイテムは「メンションされて未回答」「依頼を受けた」ものを抽出
- 推測で TODO を作らない。データソースにないものは書かない

### 6. journal への書き出し

`{vault.path}/journal/{TARGET_DATE}.md` に書き出す。
TODO は journal の**先頭**（frontmatter 直後、`# YYYY-MM-DD` 見出しの直後）に配置する。

#### a) ファイルが存在しない → 新規作成

```markdown
---
date: YYYY-MM-DD
auto_generated: true
---

# YYYY-MM-DD

## TODO

### タイムライン
- ...

### 開発
- ...

### 対応・準備
- ...

### 事務
- ...
```

#### b) ファイルが存在し、`## TODO` セクションがない → 先頭に挿入

`# YYYY-MM-DD` 見出しの直後、最初の `## HH:MM` セクションの前に `## TODO` セクションを挿入する。

#### c) ファイルが存在し、`## TODO` セクションがある → 更新

既存の `## TODO` セクションを最新の内容で置き換える。他のセクション（`## HH:MM` 等）は一切変更しない。

### 7. vault へのコミット

```bash
bash scripts/commit-vault.sh
```

## Rules

- 日時は `date` コマンドで取得する。推測しない
- データソースにない情報は書かない
- ミーティングの参加者一覧は不要。タイトルと時間だけ
- プライベート予定は「登園」「育児タイム」等の簡潔な表記にする
- `## TODO` セクション以外の既存 journal エントリは絶対に変更しない
- `## TODO` セクションは再実行時に上書き更新される
