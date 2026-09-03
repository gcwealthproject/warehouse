#!/usr/bin/env bash
set -euo pipefail

pause() {
  echo
  read -r -p "Press Enter to close..."
}

timestamp="$(date +"%Y%m%d-%H%M%S")"
STATE_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_DIR="$STATE_ROOT/adam-ssm"
if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
  LOG_DIR="/tmp/adam-ssm"
  mkdir -p "$LOG_DIR"
fi
LOG_PATH="$LOG_DIR/source-manager-$timestamp.log"

say() {
  echo "$@" | tee -a "$LOG_PATH"
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

HOST="${SOURCE_MANAGER_HOST:-127.0.0.1}"
PORT_START="${SOURCE_MANAGER_PORT:-8765}"

say "ADAM SSM - Sleepless Source Manager"
say "Started: $(date -Iseconds)"
say "Working directory: $REPO_ROOT"
say "Requested URL: http://$HOST:$PORT_START"
say "Log path: $LOG_PATH"

if ! command -v python3 >/dev/null 2>&1; then
  say "Python 3 is not installed on this Linux system."
  say "Install it using your package manager, then run this launcher again."
  pause
  exit 1
fi

PYTHON_PATH="$(command -v python3)"
say "Python path: $PYTHON_PATH"
say "Python version: $(python3 --version 2>&1)"
say "Starting local server..."
say "If the browser does not open, copy the URL printed below into your browser."
echo | tee -a "$LOG_PATH"

set +e
python3 code/tools/sources/ui_local.py --host "$HOST" --port "$PORT_START" --open-browser 2>&1 | tee -a "$LOG_PATH"
exit_code=${PIPESTATUS[0]}
set -e

echo | tee -a "$LOG_PATH"
say "Exit code: $exit_code"
if [ "$exit_code" -eq 0 ]; then
  say "Final status: ADAM SSM stopped normally."
else
  say "Final status: ADAM SSM did not start or stopped with an error."
  say "Last log lines:"
  tail -n 20 "$LOG_PATH" 2>/dev/null || true
fi
say "Full log path: $LOG_PATH"
pause
exit "$exit_code"
