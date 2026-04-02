---
name: sync-sessions
description: Claude セッションの生ログをサマライズして snapshot/claude-log.md に書き出す
user-invocable: false
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# sync-sessions

`~/.claude/session-logs/` に蓄積された Claude セッションの生ログ（JSONL）を読み、
その日の作業内容をサマライズして `snapshot/YYYY-MM-DD/claude-log.md` に書き出す。

## Configuration

リポジトリルートの `config.yaml` から `vault.path` を読み取る。

## Input

生ログの場所: `~/.claude/session-logs/YYYY-MM-DD.jsonl`

各行は以下の JSON 構造:

```json
{
  "session_id": "abc-123",
  "timestamp": "16:38:00",
  "project": "/Users/wakwak/src/github.com/wakwak3125/memex",
  "prompts": ["claudeに指示したこと", "/journal ふりかえり"],
  "tools": [{"name": "Edit", "count": 3}, {"name": "Bash", "count": 5}]
}
```

## Procedure

### 1. 設定の読み込み

`config.yaml` を読み、`vault.path` を取得する。
`date` コマンドで当日の日付を取得する。

### 2. 生ログの読み込み

`~/.claude/session-logs/YYYY-MM-DD.jsonl` を読む。ファイルが存在しなければ何もせず終了。

### 3. サマライズ

生ログからセッション群を読み、以下の観点で**人間が読んで把握しやすい形**にまとめる:

- **プロジェクト別**にグループ化する
- 各セッションで「何をしたか」を 1-2 行で要約する
  - ユーザーの prompts とツール使用から意図を推測する
  - `/journal` `/sync-all` 等のスキル呼び出しはそのまま記載
  - 細かいツール名の羅列は不要。「コード修正」「調査」「設定変更」等の抽象度で書く
- 時系列順に並べる

### 4. ファイルへの書き出し

出力先: `{vault.path}/snapshot/YYYY-MM-DD/claude-log.md`

```markdown
---
source: claude-session
collected_at: YYYY-MM-DDThh:mm
ttl: 30d
auto_generated: true
---

# Claude Session Log (YYYY-MM-DD)

## {project-name}

- **HH:MM** やったことの要約
- **HH:MM** やったことの要約

## {another-project}

- **HH:MM** やったことの要約
```

### 5. 処理済みログの退避

書き出し完了後、処理済みの生ログを `~/.claude/session-logs/archive/` に移動する。

```bash
mkdir -p ~/.claude/session-logs/archive/
mv ~/.claude/session-logs/YYYY-MM-DD.jsonl ~/.claude/session-logs/archive/
```
