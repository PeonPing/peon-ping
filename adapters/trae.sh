#!/bin/bash
# peon-ping adapter for Trae IDE (trae.ai, ByteDance)
# Watches Trae's session directory for agent state changes and translates
# them into peon.sh CESP events.
#
# Trae is a VS Code-derived, AI-first IDE that exposes MCP and VS Code
# extensions but no synchronous JSON-piping shell-hook API, so peon-ping
# follows the same filesystem-watcher approach used for Amp and Antigravity:
# watch for new session files (new agent session -> SessionStart) and use an
# idle timer to detect task completion (session file stops updating -> Stop).
#
# Trae's on-disk session layout is not publicly documented and varies by
# platform/version, so the watched directory and file glob are fully
# overridable via environment variables. Point them at your install:
#   TRAE_DATA_DIR       (default: ~/.trae)
#   TRAE_SESSIONS_DIR   (default: $TRAE_DATA_DIR/sessions)
#   TRAE_SESSION_GLOB   (default: *.json)
#
# Requires: fswatch (macOS: brew install fswatch) or inotifywait (Linux: apt install inotify-tools)
# Requires: peon-ping already installed
#
# Usage:
#   bash ~/.claude/hooks/peon-ping/adapters/trae.sh        # foreground
#   bash ~/.claude/hooks/peon-ping/adapters/trae.sh &      # background

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
TRAE_DATA_DIR="${TRAE_DATA_DIR:-$HOME/.trae}"
SESSIONS_DIR="${TRAE_SESSIONS_DIR:-$TRAE_DATA_DIR/sessions}"
SESSION_GLOB="${TRAE_SESSION_GLOB:-*.json}"
IDLE_SECONDS="${TRAE_IDLE_SECONDS:-3}"        # seconds of no changes before emitting Stop
STOP_COOLDOWN="${TRAE_STOP_COOLDOWN:-10}"     # minimum seconds between Stop events per session

# --- Colors ---
BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Emit a peon.sh event ---
emit_event() {
  local event="$1"
  local sid="$2"
  local session_id="trae-${sid}"

  echo "{\"hook_event_name\":\"$event\",\"notification_type\":\"\",\"cwd\":\"$PWD\",\"session_id\":\"$session_id\",\"permission_mode\":\"\"}" \
    | bash "$PEON_DIR/peon.sh" 2>/dev/null || true
}

# --- State: track known session IDs (temp files; macOS ships Bash 3.2, no declare -A) ---
SESSION_STATE_FILE=""
SESSION_STOP_FILE=""

session_get() {
  local sid="$1"
  grep "^${sid}:" "$SESSION_STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || true
}

session_set() {
  local sid="$1" status="$2"
  grep -v "^${sid}:" "$SESSION_STATE_FILE" > "${SESSION_STATE_FILE}.tmp" 2>/dev/null || true
  mv "${SESSION_STATE_FILE}.tmp" "$SESSION_STATE_FILE"
  echo "${sid}:${status}" >> "$SESSION_STATE_FILE"
}

stop_time_get() {
  local sid="$1"
  grep "^${sid}:" "$SESSION_STOP_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || echo "0"
}

stop_time_set() {
  local sid="$1" ts="$2"
  grep -v "^${sid}:" "$SESSION_STOP_FILE" > "${SESSION_STOP_FILE}.tmp" 2>/dev/null || true
  mv "${SESSION_STOP_FILE}.tmp" "$SESSION_STOP_FILE"
  echo "${sid}:${ts}" >> "$SESSION_STOP_FILE"
}

# --- Handle a session file change ---
handle_session_change() {
  local filepath="$1"

  # Only care about files matching the session glob
  local fname
  fname=$(basename "$filepath")
  # shellcheck disable=SC2254
  case "$fname" in
    $SESSION_GLOB) ;;
    *) return ;;
  esac

  local sid
  sid=$(basename "$filepath")
  sid="${sid%.*}"
  [ -z "$sid" ] && return

  local prev
  prev=$(session_get "$sid")

  if [ -z "$prev" ]; then
    # Brand new session = new agent session
    session_set "$sid" "active"
    info "New Trae session: ${sid}"
    emit_event "SessionStart" "$sid"
  else
    # Existing session — mark active (idle checker handles Stop)
    session_set "$sid" "active"
  fi
}

# --- Idle detection: emit Stop for sessions that stopped updating ---
check_idle_sessions() {
  local now
  now=$(date +%s)
  local idle_threshold=$((now - IDLE_SECONDS))

  while IFS=: read -r sid status; do
    [ "$status" = "active" ] || continue
    local sfile
    sfile=$(ls -1 "$SESSIONS_DIR/${sid}".* 2>/dev/null | head -1 || true)
    [ -n "$sfile" ] && [ -f "$sfile" ] || continue

    local mtime
    if [ "$(uname -s)" = "Darwin" ]; then
      mtime=$(stat -f %m "$sfile" 2>/dev/null) || continue
    else
      mtime=$(stat -c %Y "$sfile" 2>/dev/null) || continue
    fi

    if [ "$mtime" -le "$idle_threshold" ]; then
      local last_stop
      last_stop=$(stop_time_get "$sid")
      if [ "$((now - last_stop))" -lt "$STOP_COOLDOWN" ]; then
        continue
      fi
      session_set "$sid" "idle"
      stop_time_set "$sid" "$now"
      info "Agent completed: ${sid}"
      emit_event "Stop" "$sid"
    fi
  done < "$SESSION_STATE_FILE"
}

# --- Cleanup ---
cleanup() {
  trap - SIGINT SIGTERM
  info "Stopping Trae watcher..."
  rm -f "$SESSION_STATE_FILE" "${SESSION_STATE_FILE}.tmp" "$SESSION_STOP_FILE" "${SESSION_STOP_FILE}.tmp" 2>/dev/null || true
  kill 0 2>/dev/null || true
  exit 0
}

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

if [ ! -d "$SESSIONS_DIR" ]; then
  warn "Trae sessions directory not found: $SESSIONS_DIR"
  warn "Set TRAE_SESSIONS_DIR to your Trae session storage path."
  warn "Waiting for Trae to create it..."
  while [ ! -d "$SESSIONS_DIR" ]; do
    sleep 2
  done
  info "Sessions directory detected."
fi

SESSION_STATE_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-trae-state.XXXXXX")
SESSION_STOP_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-trae-stops.XXXXXX")
trap cleanup SIGINT SIGTERM

# Record existing session files so we don't fire SessionStart for old sessions
for f in "$SESSIONS_DIR"/$SESSION_GLOB; do
  [ -f "$f" ] || continue
  sid=$(basename "$f"); sid="${sid%.*}"
  echo "${sid}:idle" >> "$SESSION_STATE_FILE"
done

# --- Test mode: state files + functions are ready; skip the watch loop ---
if [ "${PEON_ADAPTER_TEST:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# --- Start watching ---
info "${BOLD}peon-ping Trae adapter${RESET}"
info "Watching: $SESSIONS_DIR ($SESSION_GLOB)"
info "Watcher: $WATCHER"
info "Idle timeout: ${IDLE_SECONDS}s"
info "Press Ctrl+C to stop."
echo ""

# Idle checker in background
(
  while true; do
    sleep 1
    check_idle_sessions
  done
) &

if [ "$WATCHER" = "fswatch" ]; then
  while read -r changed_file; do
    handle_session_change "$changed_file"
  done < <(fswatch "$SESSIONS_DIR")
elif [ "$WATCHER" = "inotifywait" ]; then
  while read -r changed_file; do
    handle_session_change "$changed_file"
  done < <(inotifywait -m -e modify,create --format '%w%f' "$SESSIONS_DIR" 2>/dev/null)
fi
