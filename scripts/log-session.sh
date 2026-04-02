#!/usr/bin/env bash
set -euo pipefail

# Stop hook から呼ばれ、セッションの生ログを ~/.claude/session-logs/ に蓄積する。
# vault への書き出しは /sync-all 時に Claude がサマライズして行う。

LOG_DIR="$HOME/.claude/session-logs"
mkdir -p "$LOG_DIR"

# stdin から hook payload を読む
INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

if [[ -z "$TRANSCRIPT_PATH" || ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

TODAY=$(date +%Y-%m-%d)
NOW=$(date +%H:%M:%S)
LOG_FILE="$LOG_DIR/$TODAY.jsonl"

# プロジェクト名を取得
PROJECT=$(jq -s -r '
  [.[] | select(.type? == "user" and .cwd? != null) | .cwd] | last // "unknown"
' "$TRANSCRIPT_PATH" 2>/dev/null || echo "unknown")

# ユーザーの直接入力を抽出
USER_PROMPTS=$(jq -s -r '
  def clean_tags:
    gsub("<command-name>(?<s>[^<]*)</command-name>"; "\(.s)")
    | gsub("<command-args>(?<a>[^<]*)</command-args>"; " \(.a)")
    | gsub("<command-message>[^<]*</command-message>"; "")
    | gsub("<system-reminder>[^<]*</system-reminder>"; "")
    | gsub("<local-command-caveat>[^<]*</local-command-caveat>"; "")
    | gsub("<local-command-stdout>[^<]*</local-command-stdout>"; "")
    | gsub("<[^>]+>"; "")
    | gsub("\\s+"; " ")
    | ltrimstr(" ") | rtrimstr(" ");

  [
    .[] | select(.type? == "user")
    | select(.message?.content | type == "string")
    | .message.content | clean_tags
    | select(length > 0)
  ] | unique
' "$TRANSCRIPT_PATH" 2>/dev/null || echo '[]')

# ツール使用を集計
TOOLS=$(jq -s -r '
  [.[] | select(.type? == "assistant") | .message?.content[]? | select(.type? == "tool_use") | .name]
  | group_by(.) | map({name: .[0], count: length})
' "$TRANSCRIPT_PATH" 2>/dev/null || echo '[]')

# 入力がなければスキップ
if [[ "$USER_PROMPTS" == "[]" ]]; then
  exit 0
fi

# 1行の JSON として追記（同一セッションは上書き）
ENTRY=$(jq -n -c \
  --arg sid "$SESSION_ID" \
  --arg ts "$NOW" \
  --arg project "$PROJECT" \
  --argjson prompts "$USER_PROMPTS" \
  --argjson tools "$TOOLS" \
  '{session_id: $sid, timestamp: $ts, project: $project, prompts: $prompts, tools: $tools}')

# 同一セッションの既存エントリを除去して最新で上書き
if [[ -f "$LOG_FILE" ]]; then
  TEMP_FILE=$(mktemp)
  grep -v "\"session_id\":\"$SESSION_ID\"" "$LOG_FILE" > "$TEMP_FILE" 2>/dev/null || true
  mv "$TEMP_FILE" "$LOG_FILE"
fi

echo "$ENTRY" >> "$LOG_FILE"
