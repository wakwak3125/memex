#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.yaml"

# config.yaml から vault.path を取得
VAULT=$(grep 'path:' "$CONFIG" | head -1 | sed 's/.*path: *//' | sed "s|~|$HOME|")

# 変更をステージ
git -C "$VAULT" add -A

# 変更がなければ終了
if git -C "$VAULT" diff --cached --quiet; then
  echo "No changes to commit"
  exit 0
fi

# 同日の既存コミットがあるか確認
TODAY=$(date +%Y-%m-%d)
LAST_MSG=$(git -C "$VAULT" log -1 --format=%s 2>/dev/null || echo "")

# 同日コミットがあれば amend、なければ新規コミット
if echo "$LAST_MSG" | grep -q "^snapshot: $TODAY"; then
  git -C "$VAULT" commit --amend --no-edit
  echo "Amended existing commit: snapshot: $TODAY"
else
  git -C "$VAULT" commit -m "snapshot: $TODAY"
  echo "Created new commit: snapshot: $TODAY"
fi
