#!/bin/bash
# peon-ping audio relay server (enhanced for remote category-based playback)
# Runs on your LOCAL machine to play sounds requested over SSH tunnels.
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
# Endpoints:
#   GET /health                         Health check (returns "OK")
#   GET /play?file=<path>               Play a specific sound file (legacy)
#   GET /play?category=<category>       Play a random sound from category (new)
#   POST /notify                        Send desktop notification
#
# The relay receives HTTP requests from the remote/container and plays audio
# using the host's native audio backend (afplay on macOS, PipeWire/PulseAudio/etc on Linux).
set -uo pipefail

# --- Configuration (env vars or CLI flags) ---
RELAY_PORT="${PEON_RELAY_PORT:-19998}"
PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
# CESP shared path fallback (used by peon-ping-setup and standalone adapters)
if [ ! -d "$PEON_DIR/packs" ] && [ -d "$HOME/.openpeon/packs" ]; then
  PEON_DIR="$HOME/.openpeon"
fi
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
      echo ""
      echo "Endpoints:"
      echo "  GET /health                 Health check"
      echo "  GET /play?file=<path>       Play specific sound file"
      echo "  GET /play?category=<cat>    Play random sound from category"
      echo "  POST /notify                Send desktop notification"
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
  Linux)
    # Check for Docker/devcontainer BEFORE checking for WSL
    # (devcontainers on WSL2 have both indicators)
    if [ -f /.dockerenv ]; then
      HOST_PLATFORM="linux"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
      HOST_PLATFORM="wsl"
    else
      HOST_PLATFORM="linux"
    fi ;;
  MINGW*|MSYS*|CYGWIN*) HOST_PLATFORM="windows" ;;
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

echo "peon-ping relay v2.0 (category-aware)"
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
import random
import shutil
import subprocess
import sys
import tempfile
import urllib.parse

PEON_DIR = os.path.realpath(sys.argv[1])
HOST_PLATFORM = sys.argv[2]
BIND_ADDR = sys.argv[3]
PORT = int(sys.argv[4])

CONFIG_FILE = os.path.join(PEON_DIR, "config.json")
STATE_FILE = os.path.join(PEON_DIR, ".state.json")

# Build list of allowed path prefixes (PEON_DIR + any symlink targets within it)
ALLOWED_PREFIXES = [PEON_DIR + os.sep]
for entry in os.listdir(PEON_DIR):
    entry_path = os.path.join(PEON_DIR, entry)
    if os.path.islink(entry_path):
        real_target = os.path.realpath(entry_path)
        if os.path.isdir(real_target):
            ALLOWED_PREFIXES.append(real_target + os.sep)


def is_path_allowed(full_path):
    """Check if a path is within allowed directories."""
    for prefix in ALLOWED_PREFIXES:
        if full_path.startswith(prefix) or full_path == prefix.rstrip(os.sep):
            return True
    return False


def load_config():
    """Load peon-ping config.json."""
    try:
        with open(CONFIG_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def load_state():
    """Load .state.json for tracking last-played sounds."""
    try:
        with open(STATE_FILE) as f:
            return json.load(f)
    except Exception:
        return {}


def save_state(state):
    """Save .state.json atomically."""
    try:
        d = os.path.dirname(STATE_FILE) or "."
        os.makedirs(d, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=d, suffix=".tmp")
        try:
            with os.fdopen(fd, "w") as f:
                json.dump(state, f)
            os.replace(tmp, STATE_FILE)
        except Exception:
            try: os.unlink(tmp)
            except OSError: pass
    except Exception:
        pass


def pick_sound_for_category(category):
    """
    Pick a random sound file for the given category.
    Avoids repeating the last-played sound for that category.
    Returns (file_path, volume) or (None, None) if not found.
    """
    config = load_config()
    active_pack = config.get("active_pack", "peon")
    volume = config.get("volume", 0.5)

    pack_dir = os.path.join(PEON_DIR, "packs", active_pack)
    if not os.path.isdir(pack_dir):
        return None, None

    # Load manifest
    manifest = None
    for mname in ("openpeon.json", "manifest.json"):
        mpath = os.path.join(pack_dir, mname)
        if os.path.exists(mpath):
            try:
                with open(mpath) as f:
                    manifest = json.load(f)
                break
            except Exception:
                pass
    if not manifest:
        return None, None

    # Get sounds for category
    cat_data = manifest.get("categories", {}).get(category, {})
    sounds = cat_data.get("sounds", [])
    if not sounds:
        return None, None

    # Load state to avoid repeats
    state = load_state()
    last_played = state.get("last_played", {})
    last_file = last_played.get(category, "")

    # Filter out last-played if there's more than one sound
    candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s.get("file") != last_file]
    pick = random.choice(candidates)

    # Update state
    last_played[category] = pick.get("file", "")
    state["last_played"] = last_played
    save_state(state)

    # Resolve file path
    file_ref = pick.get("file", "")
    if "/" in file_ref:
        candidate = os.path.realpath(os.path.join(pack_dir, file_ref))
    else:
        candidate = os.path.realpath(os.path.join(pack_dir, "sounds", file_ref))

    pack_root = os.path.realpath(pack_dir) + os.sep
    if not candidate.startswith(pack_root):
        return None, None
    if not os.path.isfile(candidate):
        return None, None
    _AUDIO_EXT = {'.wav', '.mp3', '.ogg', '.flac', '.aac', '.m4a', '.opus'}
    if os.path.splitext(candidate)[1].lower() not in _AUDIO_EXT:
        return None, None

    return candidate, volume


def play_sound_on_host(path, volume):
    """Play an audio file using the host's native audio backend."""
    vol = str(max(0.0, min(1.0, float(volume))))

    if HOST_PLATFORM == "mac":
        config = load_config()
        use_sfx = config.get("use_sound_effects_device", True)
        peon_play = os.path.join(PEON_DIR, "scripts", "peon-play")
        if use_sfx and os.path.isfile(peon_play) and os.access(peon_play, os.X_OK):
            cmd = [peon_play, "-v", vol, path]
        else:
            cmd = ["afplay", "-v", vol, path]
        subprocess.Popen(
            cmd,
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
    elif HOST_PLATFORM in ("wsl", "windows"):
        # Use PowerShell MediaPlayer on Windows/WSL
        # Convert WSL path to Windows path if needed
        win_path = path
        if HOST_PLATFORM == "wsl" and shutil.which("wslpath"):
            try:
                win_path = subprocess.check_output(
                    ["wslpath", "-w", path],
                    text=True, stderr=subprocess.DEVNULL
                ).strip()
            except subprocess.CalledProcessError:
                pass

        # Use win-play.ps1 if available, otherwise inline PowerShell
        win_play_script = os.path.join(os.path.dirname(PEON_DIR), "scripts", "win-play.ps1")
        if os.path.isfile(win_play_script):
            subprocess.Popen(
                ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                 "-File", win_play_script, win_path, vol],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        else:
            # Fallback: inline PowerShell
            safe_path = win_path.replace("'", "''")
            safe_vol = str(max(0.0, min(1.0, float(vol))))
            subprocess.Popen(
                ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                 f"Add-Type -AssemblyName PresentationCore; "
                 f"$mp = New-Object System.Windows.Media.MediaPlayer; "
                 f"$mp.Volume = {safe_vol}; "
                 f"$mp.Open([uri]'{safe_path}'); "
                 f"$mp.Play(); "
                 f"Start-Sleep -Seconds 5"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )


def send_notification_on_host(title, message, color="red"):
    """Send a desktop notification using the host's native notification system.

    Delegates to scripts/notify.sh which handles overlay/standard styles, icons,
    click-to-focus, WSL toast/forms, and Linux notify-send.
    Falls back to inline osascript/notify-send if notify.sh is missing.
    """
    notify_script = os.path.join(PEON_DIR, "scripts", "notify.sh")
    if os.path.isfile(notify_script):
        config = load_config()
        notif_style = config.get("notification_style", "overlay")
        icon_path = os.path.join(PEON_DIR, "docs", "peon-icon.png")
        env = os.environ.copy()
        env["PEON_PLATFORM"] = HOST_PLATFORM
        env["PEON_NOTIF_STYLE"] = notif_style
        env["PEON_DIR"] = PEON_DIR
        env["PEON_SYNC"] = os.environ.get("PEON_TEST", "0")
        subprocess.Popen(
            ["bash", notify_script, message, title, color, icon_path],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            env=env,
        )
        return
    # Fallback: inline notification if notify.sh not found
    if HOST_PLATFORM == "mac":
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

        # --- New: category-based sound selection ---
        category = params.get("category", [""])[0]
        if category:
            sound_file, volume = pick_sound_for_category(category)
            if not sound_file:
                self.send_error(404, f"No sounds for category: {category}")
                return
            play_sound_on_host(sound_file, volume)
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"OK: {os.path.basename(sound_file)}".encode())
            return

        # --- Legacy: file-based playback ---
        file_rel = params.get("file", [""])[0]
        if not file_rel:
            self.send_error(400, "Missing file or category parameter")
            return

        # --- Path traversal protection ---
        file_rel = urllib.parse.unquote(file_rel)
        file_rel = posixpath.normpath(file_rel)
        if file_rel.startswith("/") or ".." in file_rel.split("/"):
            self.send_error(403, "Forbidden")
            return
        full_path = os.path.realpath(os.path.join(PEON_DIR, file_rel))
        if not is_path_allowed(full_path):
            self.send_error(403, "Forbidden")
            return
        if not os.path.isfile(full_path):
            self.send_error(404, "File not found")
            return
        _AUDIO_EXT = {'.wav', '.mp3', '.ogg', '.flac', '.aac', '.m4a', '.opus'}
        if os.path.splitext(full_path)[1].lower() not in _AUDIO_EXT:
            self.send_error(403, "Forbidden: not an audio file")
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
