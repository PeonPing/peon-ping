#!/bin/bash
# peon-ping adapter for Kimi Code CLI (MoonshotAI)
# Watches ~/.kimi/sessions/ for Wire Mode events (wire.jsonl)
# and translates them into peon.sh CESP events.
#
# Kimi Code CLI writes JSON-RPC 2.0 events to wire.jsonl files inside
# ~/.kimi/sessions/<workspace_hash>/<session_uuid>/wire.jsonl for every
# session. This adapter watches for new lines and maps event types to
# peon.sh CESP events.
#
# Requires: fswatch (macOS: brew install fswatch) or inotifywait (Linux: apt install inotify-tools)
# Requires: peon-ping already installed
#
# Usage:
#   bash adapters/kimi.sh --install     Install as background daemon (auto-starts)
#   bash adapters/kimi.sh --uninstall   Stop daemon and remove pidfile
#   bash adapters/kimi.sh --status      Check if daemon is running
#   bash adapters/kimi.sh               Run in foreground (Ctrl+C to stop)

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
KIMI_DIR="${KIMI_DIR:-$HOME/.kimi}"
SESSIONS_DIR="${KIMI_SESSIONS_DIR:-$KIMI_DIR/sessions}"
STOP_COOLDOWN="${KIMI_STOP_COOLDOWN:-10}"  # minimum seconds between Stop events per session

PIDFILE="$PEON_DIR/.kimi-adapter.pid"
LOGFILE="$PEON_DIR/.kimi-adapter.log"

# --- Colors ---
BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Parse arguments ---
DAEMON_ACTION=""
for arg in "$@"; do
  case "$arg" in
    --install)    DAEMON_ACTION="install" ;;
    --uninstall)  DAEMON_ACTION="uninstall" ;;
    --stop)       DAEMON_ACTION="uninstall" ;;
    --status)     DAEMON_ACTION="status" ;;
    --help|-h)
      echo "Usage: bash kimi.sh [--install|--uninstall|--status]"
      echo ""
      echo "  --install       Start Kimi Code watcher as a background daemon"
      echo "  --uninstall     Stop the background daemon"
      echo "  --stop          Same as --uninstall"
      echo "  --status        Check if the daemon is running"
      echo "  (no args)       Run in foreground (Ctrl+C to stop)"
      exit 0 ;;
  esac
done

# --- Handle --uninstall / --stop ---
if [ "$DAEMON_ACTION" = "uninstall" ]; then
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      rm -f "$PIDFILE"
      echo "peon-ping Kimi adapter stopped (PID $pid)"
    else
      rm -f "$PIDFILE"
      echo "peon-ping Kimi adapter was not running (stale PID file removed)"
    fi
  else
    echo "peon-ping Kimi adapter is not running (no PID file)"
  fi
  exit 0
fi

# --- Handle --status ---
if [ "$DAEMON_ACTION" = "status" ]; then
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "peon-ping Kimi adapter is running (PID $pid)"
      exit 0
    else
      rm -f "$PIDFILE"
      echo "peon-ping Kimi adapter is not running (stale PID file removed)"
      exit 1
    fi
  else
    echo "peon-ping Kimi adapter is not running"
    exit 1
  fi
fi

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

# --- Handle --install (daemon mode) ---
if [ "$DAEMON_ACTION" = "install" ]; then
  # Check if already running
  if [ -f "$PIDFILE" ]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "peon-ping Kimi adapter already running (PID $old_pid)"
      exit 0
    fi
    rm -f "$PIDFILE"
  fi

  # Fork to background
  nohup bash "$0" > "$LOGFILE" 2>&1 &
  echo "$!" > "$PIDFILE"
  echo "peon-ping Kimi adapter started (PID $!)"
  echo "  Watching: $SESSIONS_DIR"
  echo "  Log: $LOGFILE"
  echo "  Stop: bash $0 --uninstall"
  exit 0
fi

# --- Wait for sessions dir (foreground only from here) ---
if [ ! -d "$SESSIONS_DIR" ]; then
  warn "Kimi sessions directory not found: $SESSIONS_DIR"
  warn "Waiting for Kimi Code to create it..."
  while [ ! -d "$SESSIONS_DIR" ]; do
    sleep 2
  done
  info "Sessions directory detected."
fi

# --- State: track known session UUIDs ---
# Uses temp files (macOS ships Bash 3.2, no declare -A)
# SESSION_STATE_FILE: "UUID:status" where status is "new" or "active"
# SESSION_STOP_FILE: "UUID:epoch" tracking last Stop emission time for cooldown
# SESSION_OFFSET_FILE: "UUID:bytes" tracking last-read byte offset per wire.jsonl
SESSION_STATE_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-kimi-state.XXXXXX")
SESSION_STOP_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-kimi-stops.XXXXXX")
SESSION_OFFSET_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-kimi-offsets.XXXXXX")
# Tracks "uuid:epoch" of the last new session creation (for /clear detection)
SESSION_NEW_FILE=$(mktemp "${TMPDIR:-/tmp}/peon-kimi-new.XXXXXX")
CLEAR_GRACE_SECONDS="${KIMI_CLEAR_GRACE:-5}"  # suppress Stop for old session within this window

# Record existing session UUIDs so we don't fire SessionStart for old sessions
for d in "$SESSIONS_DIR"/*/*; do
  [ -d "$d" ] || continue
  uuid=$(basename "$d")
  echo "${uuid}:active" >> "$SESSION_STATE_FILE"
  # Set offset to end of file so we don't replay old events
  wire_file="$d/wire.jsonl"
  if [ -f "$wire_file" ]; then
    local_size=$(wc -c < "$wire_file" | tr -d ' ')
    echo "${uuid}:${local_size}" >> "$SESSION_OFFSET_FILE"
  fi
done

session_get() {
  local uuid="$1"
  grep "^${uuid}:" "$SESSION_STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || true
}

session_set() {
  local uuid="$1" status="$2"
  grep -v "^${uuid}:" "$SESSION_STATE_FILE" > "${SESSION_STATE_FILE}.tmp" 2>/dev/null || true
  mv "${SESSION_STATE_FILE}.tmp" "$SESSION_STATE_FILE"
  echo "${uuid}:${status}" >> "$SESSION_STATE_FILE"
}

stop_time_get() {
  local uuid="$1"
  grep "^${uuid}:" "$SESSION_STOP_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || echo "0"
}

stop_time_set() {
  local uuid="$1" ts="$2"
  grep -v "^${uuid}:" "$SESSION_STOP_FILE" > "${SESSION_STOP_FILE}.tmp" 2>/dev/null || true
  mv "${SESSION_STOP_FILE}.tmp" "$SESSION_STOP_FILE"
  echo "${uuid}:${ts}" >> "$SESSION_STOP_FILE"
}

offset_get() {
  local uuid="$1"
  grep "^${uuid}:" "$SESSION_OFFSET_FILE" 2>/dev/null | tail -1 | cut -d: -f2 || echo "0"
}

offset_set() {
  local uuid="$1" offset="$2"
  grep -v "^${uuid}:" "$SESSION_OFFSET_FILE" > "${SESSION_OFFSET_FILE}.tmp" 2>/dev/null || true
  mv "${SESSION_OFFSET_FILE}.tmp" "$SESSION_OFFSET_FILE"
  echo "${uuid}:${offset}" >> "$SESSION_OFFSET_FILE"
}

# --- Resolve CWD from workspace hash ---
# Kimi stores sessions under ~/.kimi/sessions/<workspace_hash>/<session_uuid>/
# The workspace hash maps to a real path via ~/.kimi/kimi.json work_dirs array
resolve_cwd() {
  local workspace_hash="$1"
  local kimi_config="${KIMI_DIR}/kimi.json"
  if [ -f "$kimi_config" ]; then
    _KH="$workspace_hash" python3 -c "
import json, os, hashlib
try:
    with open('$kimi_config') as f:
        data = json.load(f)
    wh = os.environ['_KH']
    for wd in data.get('work_dirs', []):
        p = wd.get('path', '')
        if hashlib.md5(p.encode()).hexdigest() == wh:
            print(p)
            break
    else:
        print(os.getcwd())
except Exception:
    print(os.getcwd())
" 2>/dev/null
  else
    echo "$PWD"
  fi
}

# --- Process a single wire.jsonl line ---
# Parses the JSON line and returns CESP event JSON (or empty if skipped)
process_wire_line() {
  local line="$1"
  local uuid="$2"
  local cwd="$3"

  _PL="$line" _PU="$uuid" _PC="$cwd" python3 -c "
import json, os, sys
try:
    line = os.environ['_PL']
    data = json.loads(line)
    msg = data.get('message', {})
    event_type = msg.get('type', '')
    uuid = os.environ['_PU']
    cwd = os.environ['_PC']

    # Map wire events to peon.sh event names
    remap = {
        'TurnEnd': 'Stop',
        'CompactionBegin': 'PreCompact',
    }

    mapped = remap.get(event_type)

    # TurnBegin needs special handling (first vs subsequent)
    if event_type == 'TurnBegin':
        mapped = 'TurnBegin'

    # SubagentEvent with nested TurnBegin
    if event_type == 'SubagentEvent':
        payload = msg.get('payload', {})
        nested = payload.get('message', {})
        if nested.get('type') == 'TurnBegin':
            mapped = 'SubagentStart'

    if mapped is None:
        sys.exit(0)

    print(json.dumps({
        'event': mapped,
        'session_id': 'kimi-' + uuid[:8],
        'cwd': cwd,
    }))
except Exception:
    sys.exit(0)
" 2>/dev/null
}

# --- Emit a peon.sh event ---
emit_event() {
  local event="$1"
  local session_id="$2"
  local cwd="$3"

  _PE="$event" _PC="$cwd" _PS="$session_id" python3 -c "
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

# --- Handle a wire.jsonl file change ---
handle_wire_change() {
  local filepath="$1"

  # Only care about wire.jsonl files
  local fname
  fname=$(basename "$filepath")
  [ "$fname" = "wire.jsonl" ] || return

  # Extract workspace_hash and session_uuid from path:
  # .../sessions/<workspace_hash>/<session_uuid>/wire.jsonl
  local session_dir
  session_dir=$(dirname "$filepath")
  local uuid
  uuid=$(basename "$session_dir")
  [ -z "$uuid" ] && return
  local workspace_dir
  workspace_dir=$(dirname "$session_dir")
  local workspace_hash
  workspace_hash=$(basename "$workspace_dir")

  # Resolve CWD from workspace hash
  local cwd
  cwd=$(resolve_cwd "$workspace_hash")

  # Read new lines from the wire.jsonl file
  local prev_offset
  prev_offset=$(offset_get "$uuid")
  local file_size
  file_size=$(wc -c < "$filepath" | tr -d ' ')

  # Nothing new to read
  [ "$file_size" -le "$prev_offset" ] && return

  # Read new bytes and update offset
  local new_lines
  new_lines=$(tail -c +"$((prev_offset + 1))" "$filepath" 2>/dev/null) || return
  offset_set "$uuid" "$file_size"

  # Process each new line
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    local parsed
    parsed=$(process_wire_line "$line" "$uuid" "$cwd")
    [ -z "$parsed" ] && continue

    local event session_id event_cwd
    event=$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['event'])" 2>/dev/null) || continue
    session_id=$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['session_id'])" 2>/dev/null) || continue
    event_cwd=$(echo "$parsed" | python3 -c "import json,sys; print(json.load(sys.stdin)['cwd'])" 2>/dev/null) || continue

    local prev
    prev=$(session_get "$uuid")

    case "$event" in
      TurnBegin)
        if [ -z "$prev" ]; then
          # Brand new session — record timestamp for /clear detection
          session_set "$uuid" "active"
          local now_new
          now_new=$(date +%s)
          echo "${uuid}:${now_new}" > "$SESSION_NEW_FILE"
          info "New Kimi session: ${uuid:0:8}"
          emit_event "SessionStart" "$session_id" "$event_cwd"
        else
          # Subsequent turn — emit UserPromptSubmit for spam detection
          session_set "$uuid" "active"
          emit_event "UserPromptSubmit" "$session_id" "$event_cwd"
        fi
        ;;
      Stop)
        # Check cooldown
        local now
        now=$(date +%s)
        local last_stop
        last_stop=$(stop_time_get "$uuid")
        if [ "$((now - last_stop))" -lt "$STOP_COOLDOWN" ]; then
          continue
        fi

        # Suppress Stop for old session when /clear just created a new one.
        # When the user runs /clear, Kimi ends the old session (TurnEnd) and
        # immediately creates a new one (TurnBegin). The old session's TurnEnd
        # is not a real completion — suppress it.
        local _new_line
        _new_line=$(tail -1 "$SESSION_NEW_FILE" 2>/dev/null) || true
        if [ -n "$_new_line" ]; then
          local _new_uuid _new_ts
          _new_uuid="${_new_line%%:*}"
          _new_ts="${_new_line#*:}"
          if [ "$_new_uuid" != "$uuid" ] && [ "$((now - _new_ts))" -lt "$CLEAR_GRACE_SECONDS" ]; then
            info "Suppressed Stop for ${uuid:0:8} (/clear detected)"
            continue
          fi
        fi

        stop_time_set "$uuid" "$now"
        session_set "$uuid" "active"
        info "Agent finished turn: ${uuid:0:8}"
        emit_event "Stop" "$session_id" "$event_cwd"
        ;;
      PreCompact)
        info "Context compaction: ${uuid:0:8}"
        emit_event "PreCompact" "$session_id" "$event_cwd"
        ;;
      SubagentStart)
        info "Sub-agent started: ${uuid:0:8}"
        emit_event "SubagentStart" "$session_id" "$event_cwd"
        ;;
    esac
  done <<< "$new_lines"
}

# --- Cleanup ---
cleanup() {
  trap - SIGINT SIGTERM
  info "Stopping Kimi watcher..."
  rm -f "$SESSION_STATE_FILE" "${SESSION_STATE_FILE}.tmp" \
        "$SESSION_STOP_FILE" "${SESSION_STOP_FILE}.tmp" \
        "$SESSION_OFFSET_FILE" "${SESSION_OFFSET_FILE}.tmp" \
        "$SESSION_NEW_FILE"
  kill 0 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

# --- Test mode: skip main loop when sourced for testing ---
if [ "${PEON_ADAPTER_TEST:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# --- Start watching ---
info "${BOLD}peon-ping Kimi Code adapter${RESET}"
info "Watching: $SESSIONS_DIR"
info "Watcher: $WATCHER"
info "Press Ctrl+C to stop."
echo ""

if [ "$WATCHER" = "fswatch" ]; then
  while read -r changed_file; do
    handle_wire_change "$changed_file"
  done < <(fswatch --include 'wire\.jsonl$' --exclude '.*' -r "$SESSIONS_DIR")
elif [ "$WATCHER" = "inotifywait" ]; then
  while read -r changed_file; do
    [[ "$changed_file" == *wire.jsonl ]] || continue
    handle_wire_change "$changed_file"
  done < <(inotifywait -m -r -e modify,create --format '%w%f' "$SESSIONS_DIR" 2>/dev/null)
fi
