#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../logs"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
GUI_DOMAIN="gui/$(id -u)"

ALL_JOBS=(
  "com.wakwak.memex-sync"
  "com.wakwak.memex-reflect-daily"
  "com.wakwak.memex-reflect-weekly"
  "com.wakwak.memex-reflect-monthly"
)

JOB_SHORT=(sync daily weekly monthly)
JOB_SCHEDULE=("08-23時 毎時" "平日 22:00" "金曜 22:00" "28日 22:00")

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [job]

Commands:
  install [job]     plist をインストールして登録（省略で全件）
  uninstall [job]   スケジュール解除して plist を削除（省略で全件）
  start <job>       指定ジョブを今すぐ手動実行
  stop <job>        指定ジョブを停止
  status            全ジョブの状態を一覧表示
  logs [job]        最新のログを表示（省略で全件の直近）
  tail <job>        ログを tail -f で追跡
  list              登録済みジョブ一覧

Jobs:
  sync              sync-all (08:00-23:00 毎時)
  daily             reflect daily (平日 22:00)
  weekly            reflect weekly (毎週金曜 22:00)
  monthly           reflect monthly (毎月28日 22:00)
  (省略)            全ジョブ対象
EOF
}

resolve_job() {
  case "${1:-}" in
    sync)    echo "com.wakwak.memex-sync" ;;
    daily)   echo "com.wakwak.memex-reflect-daily" ;;
    weekly)  echo "com.wakwak.memex-reflect-weekly" ;;
    monthly) echo "com.wakwak.memex-reflect-monthly" ;;
    *)       echo "" ;;
  esac
}

install_job() {
  local label="$1"
  local src="$SCRIPT_DIR/${label}.plist"
  local dst="$LAUNCH_DIR/${label}.plist"

  if [ ! -f "$src" ]; then
    echo "ERROR: $src not found"
    return 1
  fi

  mkdir -p "$LAUNCH_DIR"
  cp "$src" "$dst"
  launchctl bootout "$GUI_DOMAIN/$label" 2>/dev/null || true
  launchctl bootstrap "$GUI_DOMAIN" "$dst"
  echo "  ✓ $label"
}

uninstall_job() {
  local label="$1"
  local dst="$LAUNCH_DIR/${label}.plist"

  launchctl bootout "$GUI_DOMAIN/$label" 2>/dev/null || true
  rm -f "$dst"
  echo "  ✓ $label"
}

case "${1:-}" in
  install)
    echo "Installing..."
    if [ -n "${2:-}" ]; then
      job=$(resolve_job "$2")
      [ -z "$job" ] && { echo "Unknown job: $2"; exit 1; }
      install_job "$job"
    else
      for job in "${ALL_JOBS[@]}"; do
        install_job "$job"
      done
    fi
    echo "Done."
    ;;

  uninstall)
    echo "Uninstalling..."
    if [ -n "${2:-}" ]; then
      job=$(resolve_job "$2")
      [ -z "$job" ] && { echo "Unknown job: $2"; exit 1; }
      uninstall_job "$job"
    else
      for job in "${ALL_JOBS[@]}"; do
        uninstall_job "$job"
      done
    fi
    echo "Done."
    ;;

  start)
    [ -z "${2:-}" ] && { echo "Usage: memex-ctl start <job>"; exit 1; }
    job=$(resolve_job "$2")
    [ -z "$job" ] && { echo "Unknown job: $2"; exit 1; }
    launchctl kickstart "$GUI_DOMAIN/$job"
    echo "Started: $job"
    ;;

  stop)
    [ -z "${2:-}" ] && { echo "Usage: memex-ctl stop <job>"; exit 1; }
    job=$(resolve_job "$2")
    [ -z "$job" ] && { echo "Unknown job: $2"; exit 1; }
    launchctl kill SIGTERM "$GUI_DOMAIN/$job" 2>/dev/null || true
    echo "Stopped: $job"
    ;;

  status)
    echo "=== memex scheduled jobs ==="
    echo ""
    printf "  %-10s  %-14s  %-14s  %s\n" "JOB" "SCHEDULE" "STATE" "LAST RUN"
    printf "  %-10s  %-14s  %-14s  %s\n" "---" "--------" "-----" "--------"
    for i in "${!ALL_JOBS[@]}"; do
      label="${ALL_JOBS[$i]}"
      name="${JOB_SHORT[$i]}"
      sched="${JOB_SCHEDULE[$i]}"
      state=$(launchctl print "$GUI_DOMAIN/$label" 2>/dev/null | grep "state =" | head -1 | awk '{print $3}' | tr -d '\n' || echo "not loaded")
      [ -z "$state" ] && state="not loaded"

      # 最新ログの最終行から結果を取得
      prefix=$(echo "$label" | sed 's/com.wakwak.memex-//')
      latest=$(ls -t "$LOG_DIR"/${prefix}-*.log 2>/dev/null | head -1 || true)
      last_result="-"
      if [ -n "$latest" ]; then
        last_line=$(grep "^===" "$latest" 2>/dev/null | tail -1 || true)
        if echo "$last_line" | grep -q "TIMEOUT"; then
          last_result="TIMEOUT"
        elif echo "$last_line" | grep -q "ERROR"; then
          last_result="ERROR"
        elif echo "$last_line" | grep -q "finished"; then
          ts=$(echo "$last_line" | sed -n 's/.*at .* \([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\).*/\1/p')
          last_result="OK ${ts:-}"
        elif echo "$last_line" | grep -q "started"; then
          last_result="RUNNING"
        fi
      fi

      printf "  %-10s  %-14s  %-14s  %s\n" "$name" "$sched" "$state" "$last_result"
    done
    ;;

  logs)
    mkdir -p "$LOG_DIR"
    if [ -n "${2:-}" ]; then
      job=$(resolve_job "$2")
      [ -z "$job" ] && { echo "Unknown job: $2"; exit 1; }
      # job label からログプレフィックスを推定
      prefix=$(echo "$job" | sed 's/com.wakwak.memex-//')
      latest=$(ls -t "$LOG_DIR"/${prefix}-*.log 2>/dev/null | head -1 || true)
      if [ -n "$latest" ]; then
        echo "=== $latest ==="
        cat "$latest"
      else
        echo "No logs for $prefix"
      fi
    else
      # 全ジョブの最新ログをまとめて表示
      for logfile in $(ls -t "$LOG_DIR"/*.log 2>/dev/null | grep -v launchd | head -4); do
        echo "=== $(basename "$logfile") ==="
        tail -10 "$logfile"
        echo ""
      done
      [ -z "$(ls "$LOG_DIR"/*.log 2>/dev/null | grep -v launchd)" ] && echo "No logs yet"
    fi
    ;;

  tail)
    [ -z "${2:-}" ] && { echo "Usage: memex-ctl tail <job>"; exit 1; }
    job=$(resolve_job "$2")
    [ -z "$job" ] && { echo "Unknown job: $2"; exit 1; }
    prefix=$(echo "$job" | sed 's/com.wakwak.memex-//')
    latest=$(ls -t "$LOG_DIR"/${prefix}-*.log 2>/dev/null | head -1 || true)
    if [ -n "$latest" ]; then
      echo "=== tail -f $latest ==="
      tail -f "$latest"
    else
      echo "No logs for $prefix yet. Waiting..."
      # ログファイルが作られるのを待つ
      while true; do
        latest=$(ls -t "$LOG_DIR"/${prefix}-*.log 2>/dev/null | head -1 || true)
        if [ -n "$latest" ]; then
          tail -f "$latest"
          break
        fi
        sleep 1
      done
    fi
    ;;

  list)
    echo "=== Registered jobs ==="
    printf "  %-10s  %-14s  %s\n" "JOB" "SCHEDULE" "INSTALLED"
    printf "  %-10s  %-14s  %s\n" "---" "--------" "---------"
    for i in "${!ALL_JOBS[@]}"; do
      label="${ALL_JOBS[$i]}"
      name="${JOB_SHORT[$i]}"
      sched="${JOB_SCHEDULE[$i]}"
      installed="✗"
      [ -f "$LAUNCH_DIR/${label}.plist" ] && installed="✓"
      printf "  %-10s  %-14s  %s\n" "$name" "$sched" "$installed"
    done
    ;;

  *)
    usage
    exit 1
    ;;
esac
