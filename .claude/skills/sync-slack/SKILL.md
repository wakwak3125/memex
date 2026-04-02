---
name: sync-slack
description: Slackから自分宛メンション・参加スレッド・主要チャンネルの最新情報を収集し、Obsidian vaultのsnapshot/slack.mdに書き出す
user-invocable: true
argument-hint: (引数なし)
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - ToolSearch
  - mcp__claude_ai_Slack__slack_read_user_profile
  - mcp__claude_ai_Slack__slack_read_channel
  - mcp__claude_ai_Slack__slack_read_thread
  - mcp__claude_ai_Slack__slack_search_channels
  - mcp__claude_ai_Slack__slack_search_users
  - mcp__claude_ai_Slack__slack_search_public_and_private
---

# sync-slack

Slackから最新情報を収集し、Obsidian vaultに書き出す。

## Output

- `{vault.path}/snapshot/{YYYY-MM-DD}/slack.md`

## Configuration

リポジトリルートの `config.yaml` から設定を読み取る。

- `vault.path`: 出力先の vault パス
- `slack.watch_channels`: ウォッチ対象チャンネル一覧（空配列ならスキップ）

## Procedure

### 0. 設定の読み込み

`config.yaml` を読み、`vault.path` と `slack.watch_channels` を取得する。

### 1. ユーザー情報の取得

`slack_read_user_profile` (引数なし) で自分のプロフィールを取得し、user_id・表示名を確認する。

### 2. 自分宛メンションの検索

`slack_search_public_and_private` で直近7日間の自分宛メンションを検索する。

**重要**: `to:me` はDMにしかマッチしないため、チャンネル内メンションはステップ1で取得した `user_id` を使って `<@{user_id}>` で検索する。DMを除外するため `channel_types` を指定する。

```
query: "<@{user_id}>"
sort: "timestamp"
sort_dir: "desc"
after: {7日前のUnixタイムスタンプ}
limit: 20
include_context: true
channel_types: "public_channel,private_channel"
```

`include_context: true` にすることで、メンション前後のメッセージも取得し、どんな文脈でメンションされたかを把握する。

取得する情報:
- チャンネル名
- 送信者
- メッセージ本文 (200文字以内に切り詰め)
- 前後のコンテキストメッセージ
- タイムスタンプ
- スレッドの有無 (thread_ts)
- permalink

### 3. 自分の発言があるスレッドの検索

`slack_search_public_and_private` で直近7日間の自分の発言を検索し、スレッドコンテキストを把握する。

```
query: "from:me is:thread"
sort: "timestamp"
sort_dir: "desc"
after: {7日前のUnixタイムスタンプ}
limit: 10
include_context: false
```

### 4. ウォッチチャンネルの取得

Watch Channels が設定されている場合のみ実行する。

各チャンネルについて:
1. `slack_search_channels(query={チャンネル名})` でチャンネルIDを取得
2. `slack_read_channel(channel_id, limit={設定のlimit or 10}, response_format="concise")` で最新メッセージを取得

### 5. メンション元スレッドの詳細取得

ステップ2で見つかったメンションのうち、スレッド内のもの（thread_ts を持つもの）について `slack_read_thread` で会話の流れを取得する。これにより、メンションされた背景・依頼内容・結論を正確に把握できる。

対象: スレッド内メンション全件（ただし上限10件）

```
channel_id: {チャンネルID}
message_ts: {スレッドの親メッセージts}
limit: 20
response_format: "concise"
```

### 6. 重要スレッドの詳細取得

ステップ2〜4で見つかったスレッドのうち、直近3日以内かつ返信が多いもの（上位5件、ステップ5で未取得のもの）について `slack_read_thread` で詳細を取得する。

ウォッチチャンネル内で reply_count が多いスレッドも対象に含める。

```
channel_id: {チャンネルID}
message_ts: {スレッドの親メッセージts}
limit: 20
response_format: "concise"
```

### 7. snapshot/slack.md への書き出し

以下のフォーマットで `{VAULT_PATH}/snapshot/{YYYY-MM-DD}/slack.md`（日付は実行日） に**上書き**で書き出す。

```markdown
---
source: slack
collected_at: {現在のISO-8601日時}
ttl: 7d
auto_generated: true
---

# Slack Snapshot

## Mentions

### {チャンネル名}
- **{送信者}** ({日時}): {メッセージ本文, max 200 chars}
  - Context: {前後のメッセージから要約した背景・文脈, 1-2文}
  - [thread]({SlackリンクURL}) — {返信数} replies
  - Thread summary: {スレッド詳細が取得できた場合、会話の流れ・結論を要約}

### {チャンネル名}
- ...

## Watch Channels

### #{チャンネル名}
- **{送信者}** ({日時}): {メッセージ本文, max 200 chars}
- **{送信者}** ({日時}): {メッセージ本文, max 200 chars}
  - [thread]({SlackリンクURL}) — {返信数} replies
  - Thread: {スレッド詳細が取得できた場合、要点を1-2文で要約}
- ...

## Recognition

自分宛の感謝・評価メッセージを `#all-thank-you` 等の感謝チャンネルから抽出する。
ステップ2のメンション検索結果のうち、チャンネル名に `thank` を含むものをこのセクションに分類する。
Watch Channels に thank-you 系チャンネルがあればそこからも抽出する。

### #{チャンネル名}
- **{送信者}** ({日時}): {メッセージ本文}
  - Context: {何に対する感謝・評価か}

---

## My Active Threads

### {チャンネル名}: {スレッド要約 (親メッセージ冒頭50文字)}
- Participants: {参加者リスト}
- Last activity: {最終返信日時}
- Summary:
  - {直近の重要な返信を3件以内で要約}

## My Recent Messages

- **{チャンネル名}** ({日時}): {メッセージ本文, max 200 chars}
- ...
```

### 8. vault へのコミット

書き出し完了後、`scripts/commit-vault.sh` を実行して vault リポジトリにコミットする。

```bash
bash scripts/commit-vault.sh
```

## Rules

- 出力は**上書き**。追記しない
- 日時はISO-8601形式
- メッセージ本文は200文字以内に切り詰める
- bot メッセージは除外する
- DM の内容は**含めない**（プライバシー保護）
- 400行以内を目安にする。超える場合は古いメンションから省略する
- Slackリンクがある場合はリンクを保持し、vault側からアクセスできるようにする
