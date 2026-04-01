---
name: sync-linear
description: LinearからIssue・スプリント情報を収集し、Obsidian vaultのsnapshot/linear.mdに書き出す
user-invocable: true
argument-hint: (引数なし)
allowed-tools:
  - Read
  - Write
  - Bash
  - Grep
  - Glob
  - ToolSearch
  - mcp__claude_ai_Linear__get_authenticated_user
  - mcp__claude_ai_Linear__list_issues
  - mcp__claude_ai_Linear__list_teams
  - mcp__claude_ai_Linear__list_cycles
  - mcp__claude_ai_Linear__list_comments
  - mcp__claude_ai_Linear__list_projects
  - mcp__claude_ai_Linear__get_issue
  - mcp__claude_ai_Linear__get_issue_status
---

# sync-linear

LinearからIssue・スプリント情報を収集し、Obsidian vaultに書き出す。

## Output

- `{vault.path}/snapshot/{YYYY-MM-DD}/linear.md`

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Procedure

### 0. 設定の読み込み

`config.yaml` を読み、`vault.path` を取得する。

### 1. ユーザー情報の取得

`get_authenticated_user` で自分のユーザー情報を取得する。

### 2. チーム・スプリント情報の取得

1. `list_teams` でチーム一覧を取得
2. 各チームに対して `list_cycles(teamId, type="current")` で現在のスプリントを取得

### 3. 自分アサインのIssue一覧取得

`list_issues(assignee="me", limit=50, orderBy="updatedAt")` で自分アサインのIssueを取得する。

取得する情報:
- Issue ID (identifier)
- Title
- Status
- Priority (Urgent/High/Normal/Low/None)
- Project name
- Updated at

### 4. 直近コメントの取得

ステータスが完了（Done/Canceled）以外のIssueに対して、`list_comments(issueId, limit=3)` で直近コメントを取得する。

全Issueではなく、アクティブなもの（In Progress, Todo, In Review等）に絞る。

### 5. プロジェクト情報の取得

`list_projects` でプロジェクト一覧を取得し、進捗状態を記録する。

### 6. snapshot/linear.md への書き出し

以下のフォーマットで `{VAULT_PATH}/snapshot/{YYYY-MM-DD}/linear.md`（日付は実行日） に**上書き**で書き出す。

```markdown
---
source: linear
collected_at: {現在のISO-8601日時}
ttl: 7d
auto_generated: true
---

# Linear Snapshot

## My Issues

### In Progress
- **{ID}** {Title} (Priority: {priority})
  - Project: {project}
  - Updated: {date}

### Todo
- **{ID}** {Title} (Priority: {priority})
  - Project: {project}

### In Review
- ...

### Backlog
- ...

## Current Sprint

### {Team Name}: {Sprint Name}
- Period: {start} 〜 {end}

## Recent Comments

### {ID}: {Title}
- {author} ({date}): {comment body, max 200 chars}

## Projects

### {Project Name}
- Status: {status}
- Progress: {progress}%
```

### vault へのコミット

書き出し完了後、`scripts/commit-vault.sh` を実行して vault リポジトリにコミットする。

```bash
bash scripts/commit-vault.sh
```

## Rules

- 出力は**上書き**。追記しない
- 日時はISO-8601形式
- コメント本文は200文字以内に切り詰める
- 完了・キャンセル済みのIssueはMy Issuesに含めない（直近1週間以内に完了したものは除く）
- 200行以内を目安にする。超える場合はBacklogのIssueを省略する
