#!/bin/bash
# peon-ping adapter for Google Antigravity IDE
# Watches ~/.gemini/antigravity/conversations/ for agent state changes
# and translates them into peon.sh CESP events.
#
# Antigravity stores agent conversations as protobuf files (.pb).
# This adapter watches for file creation (new session) and uses an
# idle timer to detect task completion (no updates for a few seconds).
#
# Requires: fswatch (macOS: brew install fswatch) or inotifywait (Linux: apt install inotify-tools)
# Requires: peon-ping already installed
#
# Usage:
#   bash ~/.claude/hooks/peon-ping/adapters/antigravity.sh        # foreground
#   bash ~/.claude/hooks/peon-ping/adapters/antigravity.sh &      # background

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
AG_DIR="${ANTIGRAVITY_DIR:-$HOME/.gemini/antigravity}"
CONVERSATIONS_DIR="${ANTIGRAVITY_CONVERSATIONS_DIR:-$AG_DIR/conversations}"
IDLE_SECONDS="${ANTIGRAVITY_IDLE_SECONDS:-5}"  # seconds of no changes before emitting Stop
STOP_COOLDOWN="${ANTIGRAVITY_STOP_COOLDOWN:-10}"  # minimum seconds between Stop events per GUID

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

if [ ! -d "$CONVERSATIONS_DIR" ]; then
  warn "Antigravity conversations directory not found: $CONVERSATIONS_DIR"
  warn "Waiting for Antigravity to create it..."
  while [ ! -d "$CONVERSATIONS_DIR" ]; do
    sleep 2
  done
  info "Conversations directory detected."
fi

# --- State: track known GUIDs ---
# Uses temp files (macOS ships Bash 3.2, no declare -A)
# GUID_STATE_FILE: "GUID:status" where status is "active" or "idle"
# GUID_STOP_FILE: "GUID:epoch" tracking last Stop emission time for cooldown
GUID_STATE_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-antigravity-state.XXXXXX")
GUID_STOP_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-antigravity-stops.XXXXXX")

# Record existing .pb files so we don't fire SessionStart for old sessions
for f in "$CONVERSATIONS_DIR"/*.pb; do
  [ -f "$f" ] || continue
  guid=$(basename "$f" .pb)
  echo "${guid}:idle" >> "$GUID_STATE_FILE"
done

guid_get() {
  local guid="$1"
  grep "^${guid}:" "$GUID_STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || true
}

guid_set() {
  local guid="$1" status="$2"
  grep -v "^${guid}:" "$GUID_STATE_FILE" > "${GUID_STATE_FILE}.tmp" 2>/dev/null || true
  mv "${GUID_STATE_FILE}.tmp" "$GUID_STATE_FILE"
  echo "${guid}:${status}" >> "$GUID_STATE_FILE"
}

# Get/set the last Stop emission time for cooldown
stop_time_get() {
  local guid="$1"
  grep "^${guid}:" "$GUID_STOP_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || echo "0"
}

stop_time_set() {
  local guid="$1" ts="$2"
  grep -v "^${guid}:" "$GUID_STOP_FILE" > "${GUID_STOP_FILE}.tmp" 2>/dev/null || true
  mv "${GUID_STOP_FILE}.tmp" "$GUID_STOP_FILE"
  echo "${guid}:${ts}" >> "$GUID_STOP_FILE"
}

# --- Emit a peon.sh event ---
emit_event() {
  local event="$1"
  local guid="$2"
  local session_id="antigravity-${guid:0:8}"

  _PE="$event" _PC="$PWD" _PS="$session_id" python3 -c "
import json, os
print(json.dumps({
    'hook_event_name': os.environ['_PE'],
    'notification_type': '',
    'cwd': os.environ['_PC'],
    'session_id': os.environ['_PS'],
    'permission_mode': '',
}))
" | bash "$PEON_DIR/peon.sh" 2>/dev/null || true
}

# --- Handle a conversation file change ---
handle_conversation_change() {
  local filepath="$1"

  # Only care about .pb files
  case "$filepath" in
    *.pb) ;;
    *) return ;;
  esac

  local guid
  guid=$(basename "$filepath" .pb)
  [ -z "$guid" ] && return

  local prev
  prev=$(guid_get "$guid")

  if [ -z "$prev" ]; then
    # Brand new conversation = new agent session
    guid_set "$guid" "active"
    info "New agent session: ${guid:0:8}"
    emit_event "SessionStart" "$guid"
  else
    # Existing session — just mark active (idle checker handles Stop)
    guid_set "$guid" "active"
  fi
}

# --- Idle detection: check for sessions that stopped updating ---
check_idle_sessions() {
  local now
  now=$(date +%s)
  local idle_threshold=$((now - IDLE_SECONDS))

  # Check each "active" GUID — if its .pb file hasn't been modified recently, emit Stop
  while IFS=: read -r guid status; do
    [ "$status" = "active" ] || continue
    local pb_file="$CONVERSATIONS_DIR/${guid}.pb"
    [ -f "$pb_file" ] || continue

    local mtime
    if [ "$(uname -s)" = "Darwin" ]; then
      mtime=$(stat -f %m "$pb_file" 2>/dev/null) || continue
    else
      mtime=$(stat -c %Y "$pb_file" 2>/dev/null) || continue
    fi

    if [ "$mtime" -le "$idle_threshold" ]; then
      # Check cooldown — don't fire Stop again too soon
      local last_stop
      last_stop=$(stop_time_get "$guid")
      if [ "$((now - last_stop))" -lt "$STOP_COOLDOWN" ]; then
        guid_set "$guid" "idle"
        continue
      fi

      guid_set "$guid" "idle"
      stop_time_set "$guid" "$now"
      info "Agent completed: ${guid:0:8}"
      emit_event "Stop" "$guid"
    fi
  done < "$GUID_STATE_FILE"
}

# --- Cleanup ---
cleanup() {
  trap - SIGINT SIGTERM
  info "Stopping Antigravity watcher..."
  rm -f "$GUID_STATE_FILE" "${GUID_STATE_FILE}.tmp" "$GUID_STOP_FILE" "${GUID_STOP_FILE}.tmp"
  # Kill background jobs (like the idle checker loop)
  kill 0 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

# --- Test mode: skip main loop when sourced for testing ---
if [ "${PEON_ADAPTER_TEST:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# --- Start watching ---
info "${BOLD}peon-ping Antigravity adapter${RESET}"
info "Watching: $CONVERSATIONS_DIR"
info "Watcher: $WATCHER"
info "Idle timeout: ${IDLE_SECONDS}s"
info "Press Ctrl+C to stop."
echo ""

# Start idle checker in background (runs every 2 seconds)
(
  while true; do
    sleep 2
    check_idle_sessions
  done
) &
IDLE_PID=$!

if [ "$WATCHER" = "fswatch" ]; then
  while read -r changed_file; do
    handle_conversation_change "$changed_file"
  done < <(fswatch --include '\.pb$' --exclude '.*' "$CONVERSATIONS_DIR")
elif [ "$WATCHER" = "inotifywait" ]; then
  while read -r changed_file; do
    [[ "$changed_file" == *.pb ]] || continue
    handle_conversation_change "$changed_file"
  done < <(inotifywait -m -e modify,create --format '%w%f' "$CONVERSATIONS_DIR" 2>/dev/null)
fi
