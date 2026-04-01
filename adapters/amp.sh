#!/bin/bash
# peon-ping adapter for Amp (ampcode.com)
# Watches ~/.local/share/amp/threads/ for agent state changes
# and translates them into peon.sh CESP events.
#
# Amp stores conversation threads as JSON files. This adapter watches
# for file creation (new session) and uses an idle timer to detect task
# completion (thread file stops updating and last message is from the
# assistant with text content — meaning the agent is done and waiting
# for user input).
#
# Requires: fswatch (macOS: brew install fswatch) or inotifywait (Linux: apt install inotify-tools)
# Requires: peon-ping already installed
#
# Usage:
#   bash ~/.claude/hooks/peon-ping/adapters/amp.sh        # foreground
#   bash ~/.claude/hooks/peon-ping/adapters/amp.sh &      # background

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
AMP_DATA_DIR="${AMP_DATA_DIR:-$HOME/.local/share/amp}"
THREADS_DIR="${AMP_THREADS_DIR:-$AMP_DATA_DIR/threads}"
IDLE_SECONDS="${AMP_IDLE_SECONDS:-1}"  # seconds of no changes before emitting Stop
STOP_COOLDOWN="${AMP_STOP_COOLDOWN:-10}"  # minimum seconds between Stop events per thread

# --- Colors ---
BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Preflight ---
if [ ! -f "$PEON_DIR/peon.sh" ]; then
  error "peon.sh not found at $PEON_DIR/peon.sh"
  error "Install peon-ping first: curl -fsSL peonping.com/install | bash"
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  error "python3 is required but not found."
  exit 1
fi

# Detect filesystem watcher
WATCHER=""
if command -v fswatch &>/dev/null; then
  WATCHER="fswatch"
elif command -v inotifywait &>/dev/null; then
  WATCHER="inotifywait"
else
  error "No filesystem watcher found."
  error "  macOS: brew install fswatch"
  error "  Linux: apt install inotify-tools"
  exit 1
fi

if [ ! -d "$THREADS_DIR" ]; then
  warn "Amp threads directory not found: $THREADS_DIR"
  warn "Waiting for Amp to create it..."
  while [ ! -d "$THREADS_DIR" ]; do
    sleep 2
  done
  info "Threads directory detected."
fi

# --- State: track known thread IDs ---
# Uses temp files (macOS ships Bash 3.2, no declare -A)
# THREAD_STATE_FILE: "THREAD_ID:status" where status is "active" or "idle"
# THREAD_STOP_FILE: "THREAD_ID:epoch" tracking last Stop emission time for cooldown
THREAD_STATE_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-amp-state.XXXXXX")
THREAD_STOP_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-amp-stops.XXXXXX")

# Record existing thread files so we don't fire SessionStart for old threads
for f in "$THREADS_DIR"/T-*.json; do
  [ -f "$f" ] || continue
  tid=$(basename "$f" .json)
  echo "${tid}:idle" >> "$THREAD_STATE_FILE"
done

thread_get() {
  local tid="$1"
  grep "^${tid}:" "$THREAD_STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || true
}

thread_set() {
  local tid="$1" status="$2"
  grep -v "^${tid}:" "$THREAD_STATE_FILE" > "${THREAD_STATE_FILE}.tmp" 2>/dev/null || true
  mv "${THREAD_STATE_FILE}.tmp" "$THREAD_STATE_FILE"
  echo "${tid}:${status}" >> "$THREAD_STATE_FILE"
}

stop_time_get() {
  local tid="$1"
  grep "^${tid}:" "$THREAD_STOP_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || echo "0"
}

stop_time_set() {
  local tid="$1" ts="$2"
  grep -v "^${tid}:" "$THREAD_STOP_FILE" > "${THREAD_STOP_FILE}.tmp" 2>/dev/null || true
  mv "${THREAD_STOP_FILE}.tmp" "$THREAD_STOP_FILE"
  echo "${tid}:${ts}" >> "$THREAD_STOP_FILE"
}

# --- Emit a peon.sh event ---
emit_event() {
  local event="$1"
  local tid="$2"
  local session_id="amp-${tid:2:8}"

  echo "{\"hook_event_name\":\"$event\",\"notification_type\":\"\",\"cwd\":\"$PWD\",\"session_id\":\"$session_id\",\"permission_mode\":\"\"}" \
    | bash "$PEON_DIR/peon.sh" 2>/dev/null || true
}

# --- Check if a thread is waiting for user input ---
# Returns 0 (true) if the last message is from the assistant with text content
# (i.e., the agent finished its turn and is waiting for the user)
thread_is_waiting() {
  local filepath="$1"
  python3 -c "
import json, sys
try:
    with open('$filepath') as f:
        data = json.load(f)
    msgs = data.get('messages', [])
    if not msgs:
        sys.exit(1)
    last = msgs[-1]
    if last.get('role') != 'assistant':
        sys.exit(1)
    content = last.get('content', [])
    # Assistant with text content = done, waiting for input
    # Assistant with tool_use = still working (tool results pending)
    types = [c.get('type') for c in content if isinstance(c, dict)]
    if 'tool_use' in types:
        sys.exit(1)
    if 'text' in types:
        sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
" 2>/dev/null
}

# --- Handle a thread file change ---
handle_thread_change() {
  local filepath="$1"

  # Only care about T-*.json files (not .amptmp or other files)
  local fname
  fname=$(basename "$filepath")
  case "$fname" in
    T-*.json) ;;
    *) return ;;
  esac

  # Skip .amptmp files
  case "$filepath" in
    *.amptmp) return ;;
  esac

  local tid
  tid=$(basename "$filepath" .json)
  [ -z "$tid" ] && return

  local prev
  prev=$(thread_get "$tid")

  if [ -z "$prev" ]; then
    # Brand new thread = new agent session
    thread_set "$tid" "active"
    info "New Amp session: ${tid:2:10}"
    emit_event "SessionStart" "$tid"
  else
    # Existing thread — just mark active (idle checker handles Stop)
    thread_set "$tid" "active"
  fi
}

# --- Idle detection: check for threads that stopped updating ---
check_idle_threads() {
  local now
  now=$(date +%s)
  local idle_threshold=$((now - IDLE_SECONDS))

  while IFS=: read -r tid status; do
    [ "$status" = "active" ] || continue
    local thread_file="$THREADS_DIR/${tid}.json"
    [ -f "$thread_file" ] || continue

    local mtime
    if [ "$(uname -s)" = "Darwin" ]; then
      mtime=$(stat -f %m "$thread_file" 2>/dev/null) || continue
    else
      mtime=$(stat -c %Y "$thread_file" 2>/dev/null) || continue
    fi

    if [ "$mtime" -le "$idle_threshold" ]; then
      # Check cooldown — don't fire Stop again too soon
      local last_stop
      last_stop=$(stop_time_get "$tid")
      if [ "$((now - last_stop))" -lt "$STOP_COOLDOWN" ]; then
        continue
      fi

      # Check if the agent actually finished (last message is assistant text)
      if thread_is_waiting "$thread_file"; then
        thread_set "$tid" "idle"
        stop_time_set "$tid" "$now"
        info "Agent waiting for input: ${tid:2:10}"
        emit_event "Stop" "$tid"
      else
        # Still working (tool calls pending) or inconclusive — keep watching
        :
      fi
    fi
  done < "$THREAD_STATE_FILE"
}

# --- Cleanup ---
cleanup() {
  trap - SIGINT SIGTERM
  info "Stopping Amp watcher..."
  rm -f "$THREAD_STATE_FILE" "${THREAD_STATE_FILE}.tmp" "$THREAD_STOP_FILE" "${THREAD_STOP_FILE}.tmp"
  kill 0 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

# --- Test mode: skip main loop when sourced for testing ---
if [ "${PEON_ADAPTER_TEST:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# --- Start watching ---
info "${BOLD}peon-ping Amp adapter${RESET}"
info "Watching: $THREADS_DIR"
info "Watcher: $WATCHER"
info "Idle timeout: ${IDLE_SECONDS}s"
info "Press Ctrl+C to stop."
echo ""

# Start idle checker in background (runs every second)
(
  while true; do
    sleep 1
    check_idle_threads
  done
) &
IDLE_PID=$!

if [ "$WATCHER" = "fswatch" ]; then
  while read -r changed_file; do
    handle_thread_change "$changed_file"
  done < <(fswatch --include '\.json$' --exclude '.*' "$THREADS_DIR")
elif [ "$WATCHER" = "inotifywait" ]; then
  while read -r changed_file; do
    [[ "$changed_file" == *.json ]] || continue
    handle_thread_change "$changed_file"
  done < <(inotifywait -m -e modify,create --format '%w%f' "$THREADS_DIR" 2>/dev/null)
fi
