#!/bin/bash
# peon-ping audio relay server
# Runs on your LOCAL machine to play sounds requested by peon-ping over SSH or from devcontainers.
#
# Usage:
#   peon relay                          Start relay on default port (19998)
#   peon relay --port=12345             Start relay on custom port
#   peon relay --bind=0.0.0.0           Listen on all interfaces (for remote SSH)
#   peon relay --daemon                 Start relay in background
#   peon relay --stop                   Stop background relay
#   peon relay --status                 Check if relay is running
#   peon relay --peon-dir=/path/to/dir  Use custom peon-ping directory
#
# The relay receives HTTP requests from the remote/container and plays audio
# using the host's native audio backend (afplay on macOS, PipeWire/PulseAudio/etc on Linux).
set -uo pipefail

# --- Configuration (env vars or CLI flags) ---
RELAY_PORT="${PEON_RELAY_PORT:-19998}"
PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
BIND_ADDR="${PEON_RELAY_BIND:-127.0.0.1}"
DAEMON_MODE=false
DAEMON_ACTION=""

for arg in "$@"; do
  case "$arg" in
    --port=*)     RELAY_PORT="${arg#--port=}" ;;
    --peon-dir=*) PEON_DIR="${arg#--peon-dir=}" ;;
    --bind=*)     BIND_ADDR="${arg#--bind=}" ;;
    --daemon)     DAEMON_MODE=true ;;
    --stop)       DAEMON_ACTION="stop" ;;
    --status)     DAEMON_ACTION="status" ;;
    --help|-h)
      echo "Usage: peon relay [--port=PORT] [--bind=ADDR] [--peon-dir=DIR]"
      echo ""
      echo "Starts the peon-ping audio relay server on this machine."
      echo "Remote SSH sessions and devcontainers send audio requests to this relay."
      echo ""
      echo "Options:"
      echo "  --port=PORT       Port to listen on (default: 19998)"
      echo "  --bind=ADDR       Address to bind to (default: 127.0.0.1)"
      echo "  --peon-dir=DIR    peon-ping install directory"
      echo "  --daemon          Run in background (writes PID to .relay.pid)"
      echo "  --stop            Stop a background relay"
      echo "  --status          Check if a background relay is running"
      echo ""
      echo "Environment variables:"
      echo "  PEON_RELAY_PORT   Same as --port"
      echo "  PEON_RELAY_BIND   Same as --bind"
      echo "  CLAUDE_PEON_DIR   Same as --peon-dir"
      echo ""
      echo "SSH setup:"
      echo "  1. On your LOCAL machine: peon relay --daemon"
      echo "  2. Connect with: ssh -R 19998:localhost:19998 <host>"
      echo "  3. peon-ping on the remote will auto-detect SSH and use the relay"
      exit 0
      ;;
  esac
done

PIDFILE="$PEON_DIR/.relay.pid"
LOGFILE="$PEON_DIR/.relay.log"

# --- Handle --stop ---
if [ "$DAEMON_ACTION" = "stop" ]; then
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      rm -f "$PIDFILE"
      echo "peon-ping relay stopped (PID $pid)"
    else
      rm -f "$PIDFILE"
      echo "peon-ping relay was not running (stale PID file removed)"
    fi
  else
    echo "peon-ping relay is not running (no PID file)"
  fi
  exit 0
fi

# --- Handle --status ---
if [ "$DAEMON_ACTION" = "status" ]; then
  if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      echo "peon-ping relay is running (PID $pid, port $RELAY_PORT)"
      exit 0
    else
      rm -f "$PIDFILE"
      echo "peon-ping relay is not running (stale PID file removed)"
      exit 1
    fi
  else
    echo "peon-ping relay is not running"
    exit 1
  fi
fi

# --- Validate peon-ping installation ---
if [ ! -d "$PEON_DIR/packs" ]; then
  echo "Error: peon-ping packs not found at $PEON_DIR/packs" >&2
  echo "Install peon-ping first: curl -fsSL peonping.com/install | bash" >&2
  exit 1
fi

# --- Detect host platform ---
case "$(uname -s)" in
  Darwin) HOST_PLATFORM="mac" ;;
  Linux)  HOST_PLATFORM="linux" ;;
  *)      HOST_PLATFORM="unknown" ;;
esac

export RELAY_PORT PEON_DIR BIND_ADDR HOST_PLATFORM

# --- Daemon mode: fork to background ---
if [ "$DAEMON_MODE" = "true" ]; then
  # Check if already running
  if [ -f "$PIDFILE" ]; then
    old_pid=$(cat "$PIDFILE" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      echo "peon-ping relay already running (PID $old_pid)"
      exit 0
    fi
    rm -f "$PIDFILE"
  fi

  # Fork to background
  nohup bash "$0" --port="$RELAY_PORT" --bind="$BIND_ADDR" --peon-dir="$PEON_DIR" > "$LOGFILE" 2>&1 &
  echo "$!" > "$PIDFILE"
  echo "peon-ping relay started in background (PID $!)"
  echo "  Listening: ${BIND_ADDR}:${RELAY_PORT}"
  echo "  Log: $LOGFILE"
  echo "  Stop: peon relay --stop"
  exit 0
fi

echo "peon-ping relay v1.0"
echo "  Listening: ${BIND_ADDR}:${RELAY_PORT}"
echo "  Peon dir:  ${PEON_DIR}"
echo "  Platform:  ${HOST_PLATFORM}"
echo "  Press Ctrl+C to stop"
echo ""

# --- HTTP relay server (embedded Python) ---
exec python3 - "$PEON_DIR" "$HOST_PLATFORM" "$BIND_ADDR" "$RELAY_PORT" <<'PYEOF'
import http.server
import json
import os
import posixpath
import shutil
import subprocess
import sys
import urllib.parse

PEON_DIR = os.path.realpath(sys.argv[1])
HOST_PLATFORM = sys.argv[2]
BIND_ADDR = sys.argv[3]
PORT = int(sys.argv[4])


def play_sound_on_host(path, volume):
    """Play an audio file using the host's native audio backend."""
    vol = str(max(0.0, min(1.0, float(volume))))

    if HOST_PLATFORM == "mac":
        subprocess.Popen(
            ["afplay", "-v", vol, path],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    elif HOST_PLATFORM == "linux":
        # Try players in priority order (same as peon.sh)
        players = [
            (["pw-play", "--volume", vol, path], "pw-play"),
            (["paplay", f"--volume={max(0, min(65536, int(float(vol) * 65536)))}", path], "paplay"),
            (["ffplay", "-nodisp", "-autoexit", "-volume", str(max(0, min(100, int(float(vol) * 100)))), path], "ffplay"),
            (["mpv", "--no-video", f"--volume={max(0, min(100, int(float(vol) * 100)))}", path], "mpv"),
            (["play", "-v", vol, path], "play"),
            (["aplay", "-q", path], "aplay"),
        ]
        for cmd_args, name in players:
            if shutil.which(name):
                env = os.environ.copy()
                if name == "pw-play":
                    env["LC_ALL"] = "C"
                subprocess.Popen(
                    cmd_args,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    env=env,
                )
                return
        print(f"  WARNING: no audio backend found on host", file=sys.stderr)


def send_notification_on_host(title, message, color="red"):
    """Send a desktop notification using the host's native notification system."""
    if HOST_PLATFORM == "mac":
        # Pass title/message as arguments to avoid AppleScript injection
        subprocess.Popen(
            ["osascript", "-e",
             'on run argv\n'
             '  display notification (item 1 of argv) with title (item 2 of argv)\n'
             'end run',
             "--", message, title],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    elif HOST_PLATFORM == "linux":
        if shutil.which("notify-send"):
            urgency = "critical" if color == "red" else "normal"
            subprocess.Popen(
                ["notify-send", f"--urgency={urgency}", title, message],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )


class RelayHandler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Only log errors, not every request
        if args and str(args[0]).startswith(("4", "5")):
            super().log_message(fmt, *args)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        if parsed.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"OK")
            return

        if parsed.path != "/play":
            self.send_error(404)
            return

        params = urllib.parse.parse_qs(parsed.query)
        file_rel = params.get("file", [""])[0]
        if not file_rel:
            self.send_error(400, "Missing file parameter")
            return

        # --- Path traversal protection ---
        file_rel = urllib.parse.unquote(file_rel)
        file_rel = posixpath.normpath(file_rel)
        if file_rel.startswith("/") or ".." in file_rel.split("/"):
            self.send_error(403, "Forbidden")
            return
        full_path = os.path.realpath(os.path.join(PEON_DIR, file_rel))
        if not full_path.startswith(PEON_DIR + os.sep) and full_path != PEON_DIR:
            self.send_error(403, "Forbidden")
            return
        if not os.path.isfile(full_path):
            self.send_error(404, "File not found")
            return

        vol = self.headers.get("X-Volume", "0.5")
        try:
            vol = str(max(0.0, min(1.0, float(vol))))
        except ValueError:
            vol = "0.5"

        play_sound_on_host(full_path, vol)

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"OK")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/notify":
            self.send_error(404)
            return

        length = int(self.headers.get("Content-Length", 0))
        if length > 0:
            try:
                body = json.loads(self.rfile.read(length))
            except (json.JSONDecodeError, ValueError):
                self.send_error(400, "Invalid JSON")
                return
        else:
            body = {}

        title = str(body.get("title", "peon-ping"))[:256]
        message = str(body.get("message", ""))[:512]
        color = str(body.get("color", "red"))

        send_notification_on_host(title, message, color)

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"OK")


server = http.server.HTTPServer((BIND_ADDR, PORT), RelayHandler)
try:
    server.serve_forever()
except KeyboardInterrupt:
    print("\npeon-ping relay stopped.")
    server.server_close()
PYEOF
