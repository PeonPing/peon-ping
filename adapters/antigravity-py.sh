#!/bin/bash
# peon-ping adapter for Google Antigravity IDE (Python watcher)
# Uses a Python watchdog-based filesystem watcher to monitor
# ~/.gemini/antigravity/conversations/ for .pb file changes and
# translates them into peon.sh CESP events.
#
# This adapter is designed for background / headless / LaunchAgent use.
# Unlike the shell-only antigravity.sh adapter, it uses a Python watcher
# with a 25s idle threshold that survives tool-call pauses without
# false-triggering, and pipes events through peon.sh for full config
# support (volume, pack rotation, notifications, etc.).
#
# Requires: python3, pip-installed watchdog, peon-ping already installed
#
# Usage:
#   bash adapters/antigravity-py.sh --install     Install as background daemon (auto-starts)
#   bash adapters/antigravity-py.sh --uninstall   Stop daemon and remove pidfile
#   bash adapters/antigravity-py.sh --status      Check if daemon is running
#   bash adapters/antigravity-py.sh               Run in foreground (Ctrl+C to stop)
#
# On macOS, --install registers a LaunchAgent at
# ~/Library/LaunchAgents/com.peonping.antigravity-py-adapter.plist so the
# watcher auto-starts on login and auto-restarts on crash.
# Set ANTIGRAVITY_NO_LAUNCHD=1 to fall back to nohup+pidfile.
# On Linux, --install always uses nohup + pidfile.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
AG_DIR="${ANTIGRAVITY_DIR:-$HOME/.gemini/antigravity}"
CONVERSATIONS_DIR="${ANTIGRAVITY_CONVERSATIONS_DIR:-$AG_DIR/conversations}"

PIDFILE="$PEON_DIR/.antigravity-py-adapter.pid"
LOGFILE="$PEON_DIR/.antigravity-py-adapter.log"

LAUNCHD_LABEL="com.peonping.antigravity-py-adapter"
LAUNCHD_PLIST="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"

# Locate the Python watcher script (sibling of this shell script)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHER_PY="$SCRIPT_DIR/antigravity-watcher.py"

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
      echo "Usage: bash antigravity-py.sh [--install|--uninstall|--status]"
      echo ""
      echo "  --install       Start Antigravity watcher as a background daemon"
      echo "                  (macOS: registers a LaunchAgent that survives reboot;"
      echo "                   Linux: nohup + pidfile)"
      echo "  --uninstall     Stop the background daemon"
      echo "  --stop          Same as --uninstall"
      echo "  --status        Check if the daemon is running"
      echo "  (no args)       Run in foreground (Ctrl+C to stop)"
      echo ""
      echo "Environment:"
      echo "  ANTIGRAVITY_NO_LAUNCHD=1   Force nohup+pidfile on macOS (skip LaunchAgent)"
      echo "  ANTIGRAVITY_IDLE_SECONDS   Seconds of silence before emitting Stop (default: 25)"
      exit 0 ;;
  esac
done

# --- Handle --uninstall / --stop ---
if [ "$DAEMON_ACTION" = "uninstall" ]; then
  # macOS LaunchAgent cleanup
  if [ "${ANTIGRAVITY_NO_LAUNCHD:-0}" != "1" ] && [ -f "$LAUNCHD_PLIST" ]; then
    launchctl unload "$LAUNCHD_PLIST" 2>/dev/null || true
    rm -f "$LAUNCHD_PLIST"
    echo "peon-ping Antigravity adapter LaunchAgent removed"
  fi

  # PID file cleanup
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      rm -f "$PIDFILE"
      echo "peon-ping Antigravity adapter stopped (PID $pid)"
    else
      rm -f "$PIDFILE"
      echo "peon-ping Antigravity adapter was not running (stale PID file removed)"
    fi
  else
    echo "peon-ping Antigravity adapter is not running (no PID file)"
  fi
  exit 0
fi

# --- Handle --status ---
if [ "$DAEMON_ACTION" = "status" ]; then
  # macOS LaunchAgent check
  if [ "${ANTIGRAVITY_NO_LAUNCHD:-0}" != "1" ] && [ -f "$LAUNCHD_PLIST" ]; then
    if launchctl list "$LAUNCHD_LABEL" &>/dev/null; then
      launchd_pid=$(launchctl list "$LAUNCHD_LABEL" 2>/dev/null | grep '"PID"' | tr -dc '0-9')
      if [ -n "$launchd_pid" ] && [ "$launchd_pid" != "-" ]; then
        echo "peon-ping Antigravity adapter is running via LaunchAgent (PID $launchd_pid)"
      else
        echo "peon-ping Antigravity adapter is loaded via LaunchAgent (starting...)"
      fi
      exit 0
    else
      echo "peon-ping Antigravity adapter LaunchAgent is installed but not loaded"
      exit 1
    fi
  fi

  # PID file check
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "peon-ping Antigravity adapter is running (PID $pid)"
      exit 0
    else
      rm -f "$PIDFILE"
      echo "peon-ping Antigravity adapter is not running (stale PID file removed)"
      exit 1
    fi
  else
    echo "peon-ping Antigravity adapter is not running"
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

if [ ! -f "$WATCHER_PY" ]; then
  error "antigravity-watcher.py not found at $WATCHER_PY"
  error "Expected alongside this script in adapters/"
  exit 1
fi

# Check that watchdog is importable
if ! python3 -c "import watchdog" 2>/dev/null; then
  error "Python 'watchdog' module not found."
  error "Install it: pip3 install watchdog"
  exit 1
fi

# --- Handle --install (daemon mode) ---
if [ "$DAEMON_ACTION" = "install" ]; then
  # macOS: LaunchAgent
  if [[ "$(uname -s)" == "Darwin" ]] && [ "${ANTIGRAVITY_NO_LAUNCHD:-0}" != "1" ]; then
    if launchctl list "$LAUNCHD_LABEL" &>/dev/null; then
      echo "peon-ping Antigravity adapter already running via LaunchAgent"
      exit 0
    fi

    # Migrate from pre-LaunchAgent install
    if [ -f "$PIDFILE" ]; then
      old_pid=$(cat "$PIDFILE" 2>/dev/null)
      if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
      fi
      rm -f "$PIDFILE"
    fi

    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
    CURRENT_PATH="$PATH"
    CURRENT_PEON_DIR="$PEON_DIR"

    mkdir -p "$(dirname "$LAUNCHD_PLIST")"
    cat > "$LAUNCHD_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LAUNCHD_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_PATH}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${CURRENT_PATH}</string>
        <key>CLAUDE_PEON_DIR</key>
        <string>${CURRENT_PEON_DIR}</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOGFILE}</string>
    <key>StandardErrorPath</key>
    <string>${LOGFILE}</string>
</dict>
</plist>
PLIST

    launchctl load "$LAUNCHD_PLIST"
    echo "peon-ping Antigravity adapter installed as LaunchAgent"
    echo "  Watching: $CONVERSATIONS_DIR"
    echo "  Log: $LOGFILE"
    echo "  Plist: $LAUNCHD_PLIST"
    echo "  Auto-starts on login, auto-restarts on crash"
    echo "  Stop: bash $0 --uninstall"
    exit 0
  fi

  # Linux / ANTIGRAVITY_NO_LAUNCHD: nohup
  if [ -f "$PIDFILE" ]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "peon-ping Antigravity adapter already running (PID $old_pid)"
      exit 0
    fi
    rm -f "$PIDFILE"
  fi

  nohup bash "$0" > "$LOGFILE" 2>&1 &
  echo "$!" > "$PIDFILE"
  echo "peon-ping Antigravity adapter started (PID $!)"
  echo "  Watching: $CONVERSATIONS_DIR"
  echo "  Log: $LOGFILE"
  echo "  Stop: bash $0 --uninstall"
  exit 0
fi

# --- Emit a peon.sh event ---
pipe_to_peon() {
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
    'source': 'antigravity',
}))
" | bash "$PEON_DIR/peon.sh" 2>/dev/null || true
}

# --- Test mode: skip main loop when sourced for testing ---
if [ "${PEON_ADAPTER_TEST:-0}" = "1" ]; then
  return 0 2>/dev/null || exit 0
fi

# --- Wait for conversations dir ---
if [ ! -d "$CONVERSATIONS_DIR" ]; then
  warn "Antigravity conversations directory not found: $CONVERSATIONS_DIR"
  warn "Waiting for Antigravity to create it..."
  while [ ! -d "$CONVERSATIONS_DIR" ]; do
    sleep 2
  done
  info "Conversations directory detected."
fi

# --- Start watching ---
info "${BOLD}peon-ping Antigravity adapter (Python watcher)${RESET}"
info "Watching: $CONVERSATIONS_DIR"
info "Watcher: python3 + watchdog"
info "Press Ctrl+C to stop."
echo ""

# Start the Python watcher and read JSON events from its stdout.
# Each line is a JSON object with {event, session_id, cwd}.
# We pipe each one through peon.sh for sound playback.
python3 "$WATCHER_PY" --cwd "$PWD" 2>"$LOGFILE" | while IFS= read -r line; do
  [ -z "$line" ] && continue

  # Parse event fields from JSON
  event=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['event'])" 2>/dev/null) || continue
  session_id=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['session_id'])" 2>/dev/null) || continue
  event_cwd=$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['cwd'])" 2>/dev/null) || continue

  case "$event" in
    SessionStart)
      info "New agent session: $session_id"
      pipe_to_peon "SessionStart" "$session_id" "$event_cwd"
      ;;
    UserPromptSubmit)
      info "Agent activated: $session_id"
      pipe_to_peon "UserPromptSubmit" "$session_id" "$event_cwd"
      ;;
    Stop)
      info "Agent completed: $session_id"
      pipe_to_peon "Stop" "$session_id" "$event_cwd"
      ;;
    *)
      warn "Unknown event: $event"
      ;;
  esac
done
