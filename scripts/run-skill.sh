#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"

COMMAND="${1:-/sync-all}"
TIMEOUT="${2:-600}"  # デフォルト10分
LABEL=$(echo "$COMMAND" | tr '/' '-' | sed 's/^-//')
LOGFILE="$LOG_DIR/${LABEL}-$(date +%Y-%m-%d).log"

echo "=== memex ${COMMAND} started at $(date) (timeout: ${TIMEOUT}s) ===" >> "$LOGFILE"

cd "$REPO_DIR"

# claude をバックグラウンドで起動し、タイムアウトを自前で管理
/Users/wakwak/.local/bin/claude \
  --print \
  --dangerously-skip-permissions \
  --verbose \
  --model claude-sonnet-4-6 \
  --output-format stream-json \
  -p "$COMMAND" 2>> "$LOGFILE" \
  | python3 -u -c "
import sys, json

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        t = obj.get('type', '')
        out = ''
        if t == 'content_block_delta':
            out = obj.get('delta', {}).get('text', '')
        elif t == 'result':
            for block in obj.get('content', []):
                if block.get('type') == 'text':
                    out += block.get('text', '')
        elif t == 'assistant':
            for block in obj.get('message', {}).get('content', []):
                if block.get('type') == 'text':
                    out += block.get('text', '')
        if out:
            print(out, end='', flush=True)
    except (json.JSONDecodeError, KeyError):
        pass
" >> "$LOGFILE" &

PID=$!

# タイムアウト監視
ELAPSED=0
while kill -0 "$PID" 2>/dev/null; do
  sleep 5
  ELAPSED=$((ELAPSED + 5))
  if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    echo "" >> "$LOGFILE"
    echo "=== TIMEOUT: memex ${COMMAND} killed after ${TIMEOUT}s at $(date) ===" >> "$LOGFILE"
    exit 124
  fi
done

wait "$PID"
EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "" >> "$LOGFILE"
  echo "=== ERROR: memex ${COMMAND} exited with code ${EXIT_CODE} at $(date) ===" >> "$LOGFILE"
else
  echo "" >> "$LOGFILE"
  echo "=== memex ${COMMAND} finished at $(date) ===" >> "$LOGFILE"
fi

# 7日以上前のログを削除
find "$LOG_DIR" -name "${LABEL}-*.log" -mtime +7 -delete 2>/dev/null || true

exit $EXIT_CODE
