#!/bin/bash
# peon-ping: Warcraft III Peon voice lines for Claude Code hooks
# Replaces notify.sh — handles sounds, tab titles, and notifications
set -uo pipefail

# --- Platform detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin)
      if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
        echo "ssh"
      else
        echo "mac"
      fi ;;
    Linux)
      # Check for devcontainer/Docker BEFORE checking for WSL
      # (devcontainers on WSL2 have both indicators)
      if [ "${REMOTE_CONTAINERS:-}" = "true" ] || [ "${CODESPACES:-}" = "true" ] || [ -f /.dockerenv ]; then
        echo "devcontainer"
      elif grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      elif [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
        echo "ssh"
      else
        echo "linux"
      fi ;;
    MSYS_NT*|MINGW*) echo "msys2" ;;
    *) echo "unknown" ;;
  esac
}
PLATFORM=${PLATFORM:-$(detect_platform)}

PEON_DIR="${CLAUDE_PEON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# Save original install directory for finding bundled scripts (Nix, Homebrew)
_INSTALL_DIR="$PEON_DIR"
# Homebrew/Nix/adapter installs: script lives in read-only store but packs/config are elsewhere.
# Priority: Claude hooks dir first (matches where the hook actually runs from),
# then CESP shared path as fallback (fixes #250: CLI must write config to the
# same location the hook reads from).
if [ ! -d "$PEON_DIR/packs" ]; then
  _hooks_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping"
  if [ -d "$_hooks_dir/packs" ]; then
    PEON_DIR="$_hooks_dir"
  elif [ -d "$HOME/.openpeon/packs" ]; then
    PEON_DIR="$HOME/.openpeon"
  else
    # Neither exists — use ~/.openpeon as default user data dir (Nix, fresh install)
    PEON_DIR="$HOME/.openpeon"
  fi
  unset _hooks_dir
fi
# Local project config overrides global config
_local_config="${PWD}/.claude/hooks/peon-ping/config.json"
if [ -f "$_local_config" ]; then
  CONFIG="$_local_config"
else
  CONFIG="$PEON_DIR/config.json"
fi
unset _local_config
# Global config is always the install-level file; used by CLI commands that
# manage user-wide settings (trainer, rotation, volume) so they persist
# regardless of which project directory the user is in.
GLOBAL_CONFIG="$PEON_DIR/config.json"
STATE="$PEON_DIR/.state.json"

# MSYS2/MinGW: Windows Python can't read /c/... paths — convert to C:/... via cygpath
if [ "$PLATFORM" = "msys2" ]; then
  CONFIG_PY="$(cygpath -m "$CONFIG")"
  GLOBAL_CONFIG_PY="$(cygpath -m "$GLOBAL_CONFIG")"
  STATE_PY="$(cygpath -m "$STATE")"
  PEON_DIR_PY="$(cygpath -m "$PEON_DIR")"
else
  CONFIG_PY="$CONFIG"
  GLOBAL_CONFIG_PY="$GLOBAL_CONFIG"
  STATE_PY="$STATE"
  PEON_DIR_PY="$PEON_DIR"
fi

# --- Resolve a bundled script from scripts/ (handles local + Homebrew/Cellar installs) ---
# Prints the resolved path on success, prints nothing on failure.
# Skips the BASH_SOURCE fallback in test mode to preserve "missing script" test cases.
find_bundled_script() {
  local name="$1" path
  # Standard local install: $PEON_DIR is the install root
  path="$PEON_DIR/scripts/$name"
  [ -f "$path" ] && { printf '%s\n' "$path"; return 0; }
  # Homebrew/adapter install: peon.sh lives in the Cellar, scripts/ is a sibling
  if [ "${PEON_TEST:-0}" != "1" ]; then
    path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/$name"
    [ -f "$path" ] && { printf '%s\n' "$path"; return 0; }
  fi
  return 1
}

resolve_pack_download() {
  local pack_dl
  pack_dl="$(find_bundled_script "pack-download.sh")" && { printf '%s\n' "$pack_dl"; return 0; }
  echo "Error: pack-download.sh not found. Run 'peon update' or reinstall peon-ping to fix." >&2
  return 1
}

# --- Linux audio backend detection ---
detect_linux_player() {
  local override="${1:-}"
  # Helper to check if a player is available (respects test-mode disable markers)
  player_available() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null || return 1
    # In test mode, check for disable marker
    [ "${PEON_TEST:-0}" = "1" ] && [ -f "${CLAUDE_PEON_DIR}/.disabled_${cmd}" ] && return 1
    return 0
  }

  # If user configured a preferred player, try it first
  if [ -n "$override" ] && player_available "$override"; then
    echo "$override"
    return 0
  fi

  if player_available pw-play; then
    echo "pw-play"
  elif player_available paplay; then
    echo "paplay"
  elif player_available ffplay; then
    echo "ffplay"
  elif player_available mpv; then
    echo "mpv"
  elif player_available play; then
    echo "play"
  elif player_available aplay; then
    echo "aplay"
  else
    # Warn only once per process to avoid spam
    if [ -z "${WARNED_NO_LINUX_AUDIO_BACKEND:-}" ]; then
      echo "WARNING: No audio backend found. Please install one of: pw-play, paplay, ffplay, mpv, play (SoX), or aplay" >&2
      WARNED_NO_LINUX_AUDIO_BACKEND=1
    fi
    return 1
  fi
}

# --- Linux audio playback with backend-specific volume handling ---
play_linux_sound() {
  local file="$1" vol="$2" player="$3"

  # Skip playback if no backend available
  [ -z "$player" ] && return 0

  # Background mode: use nohup & for async playback (default)
  # Synchronous mode: no nohup/& for tests (when PEON_TEST=1)
  local use_bg=true
  [ "${PEON_TEST:-0}" = "1" ] && use_bg=false

  case "$player" in
    pw-play)
      # pw-play (PipeWire) expects volume as float 0.0-1.0 (unlike paplay 0-65536, ffplay/mpv 0-100)
      if [ "$use_bg" = true ]; then
        nohup env LC_ALL=C pw-play --volume "$vol" "$file" >/dev/null 2>&1 &
      else
        LC_ALL=C pw-play --volume "$vol" "$file" >/dev/null 2>&1
      fi
      ;;
    paplay)
      local pa_vol
      pa_vol=$(python3 -c "print(max(0, min(65536, int($vol * 65536))))")
      if [ "$use_bg" = true ]; then
        nohup paplay --volume="$pa_vol" "$file" >/dev/null 2>&1 &
      else
        paplay --volume="$pa_vol" "$file" >/dev/null 2>&1
      fi
      ;;
    ffplay)
      local ff_vol
      ff_vol=$(python3 -c "print(max(0, min(100, int($vol * 100))))")
      if [ "$use_bg" = true ]; then
        nohup ffplay -nodisp -autoexit -volume "$ff_vol" "$file" >/dev/null 2>&1 &
      else
        ffplay -nodisp -autoexit -volume "$ff_vol" "$file" >/dev/null 2>&1
      fi
      ;;
    mpv)
      local mpv_vol
      mpv_vol=$(python3 -c "print(max(0, min(100, int($vol * 100))))")
      if [ "$use_bg" = true ]; then
        nohup mpv --no-video --volume="$mpv_vol" "$file" >/dev/null 2>&1 &
      else
        mpv --no-video --volume="$mpv_vol" "$file" >/dev/null 2>&1
      fi
      ;;
    play)
      if [ "$use_bg" = true ]; then
        nohup play -v "$vol" "$file" >/dev/null 2>&1 &
      else
        play -v "$vol" "$file" >/dev/null 2>&1
      fi
      ;;
    aplay)
      if [ "$use_bg" = true ]; then
        nohup aplay -q "$file" >/dev/null 2>&1 &
      else
        aplay -q "$file" >/dev/null 2>&1
      fi
      ;;
  esac
}

# --- Kill any previously playing peon-ping sound ---
kill_previous_sound() {
  local pidfile="$PEON_DIR/.sound.pid"
  if [ -f "$pidfile" ]; then
    local old_pid
    old_pid=$(cat "$pidfile" 2>/dev/null)
    if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
      kill "$old_pid" 2>/dev/null
    fi
    rm -f "$pidfile"
  fi
}

save_sound_pid() {
  echo "$1" > "$PEON_DIR/.sound.pid"
}

# --- Platform-aware audio playback ---
play_sound() {
  local file="$1" vol="$2"
  kill_previous_sound
  case "$PLATFORM" in
    mac)
      local player="afplay"
      if [ "${USE_SOUND_EFFECTS_DEVICE:-true}" != "false" ]; then
        local _peon_play
        _peon_play="$(find_bundled_script "peon-play")" && [ -x "$_peon_play" ] && player="$_peon_play"
      fi
      if [ "${PEON_TEST:-0}" = "1" ]; then
        "$player" -v "$vol" "$file" >/dev/null 2>&1
      else
        nohup "$player" -v "$vol" "$file" >/dev/null 2>&1 &
        save_sound_pid $!
      fi
      ;;
    wsl)
      local tmpdir tmpfile
      tmpdir=$(powershell.exe -NoProfile -NonInteractive -Command '[System.IO.Path]::GetTempPath()' 2>/dev/null | tr -d '\r')
      tmpfile="$(wslpath -u "${tmpdir}peon-ping-sound.wav")"
      if command -v ffmpeg &>/dev/null; then
        ffmpeg -y -i "$file" -filter:a "volume=$vol" "$tmpfile" 2>/dev/null
      elif [[ "$file" == *.wav ]]; then
        cp "$file" "$tmpfile"
      else
        return 0
      fi
      setsid powershell.exe -NoProfile -NonInteractive -Command "
        (New-Object Media.SoundPlayer '${tmpdir}peon-ping-sound.wav').PlaySync()
      " &>/dev/null &
      save_sound_pid $!
      ;;
    devcontainer|ssh)
      local relay_host_default="host.docker.internal"
      [ "$PLATFORM" = "ssh" ] && relay_host_default="localhost"
      local relay_host="${PEON_RELAY_HOST:-$relay_host_default}"
      local relay_port="${PEON_RELAY_PORT:-19998}"
      local rel_path="${file#$PEON_DIR/}"
      local encoded_path
      encoded_path=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$rel_path" 2>/dev/null || echo "$rel_path")
      if [ "${PEON_TEST:-0}" = "1" ]; then
        curl -sf -H "X-Volume: $vol" \
          "http://${relay_host}:${relay_port}/play?file=${encoded_path}" 2>/dev/null
      else
        nohup curl -sf -H "X-Volume: $vol" \
          "http://${relay_host}:${relay_port}/play?file=${encoded_path}" >/dev/null 2>&1 &
        save_sound_pid $!
      fi
      ;;
    linux)
      local player
      player=$(detect_linux_player "${LINUX_AUDIO_PLAYER:-}") || player=""
      if [ -n "$player" ]; then
        play_linux_sound "$file" "$vol" "$player"
        save_sound_pid $!
      fi
      ;;
    msys2)
      # Try native MSYS2 players first (ffplay, mpv, play), fall back to PowerShell
      local msys_player
      msys_player=$(detect_linux_player "${LINUX_AUDIO_PLAYER:-}") || msys_player=""
      if [ -n "$msys_player" ]; then
        play_linux_sound "$file" "$vol" "$msys_player"
        save_sound_pid $!
      else
        # PowerShell fallback via win-play.ps1
        local wpath win_play_script
        wpath=$(cygpath -w "$file")
        win_play_script="$(find_bundled_script "win-play.ps1")" 2>/dev/null || true
        if [ -n "$win_play_script" ]; then
          local wscript
          wscript=$(cygpath -w "$win_play_script")
          if [ "${PEON_TEST:-0}" = "1" ]; then
            powershell.exe -NoProfile -NonInteractive -File "$wscript" -path "$wpath" -vol "$vol" >/dev/null 2>&1
          else
            nohup powershell.exe -NoProfile -NonInteractive -File "$wscript" -path "$wpath" -vol "$vol" >/dev/null 2>&1 &
            save_sound_pid $!
          fi
        fi
      fi
      ;;
  esac
}

# --- Terminal bundle ID detection (macOS click-to-focus) ---
# Returns the macOS bundle identifier for the current terminal emulator,
# or empty string if unknown. Used with terminal-notifier -activate and
# mac-overlay.js click handler to focus the right terminal on notification click.
_mac_terminal_bundle_id() {
  case "${TERM_PROGRAM:-}" in
    ghostty)        echo "com.mitchellh.ghostty" ;;
    iTerm.app)      echo "com.googlecode.iterm2" ;;
    WarpTerminal)   echo "dev.warp.Warp-Stable" ;;
    Apple_Terminal) echo "com.apple.Terminal" ;;
    zed)            echo "dev.zed.Zed" ;;
    vscode)
      # IDE embedded terminal (Cursor, VS Code, Windsurf all set TERM_PROGRAM=vscode).
      # Async hooks are orphaned from the process tree, so _mac_ide_pid() won't find
      # the IDE. Instead, check which IDE is actually running and return its bundle ID.
      local _bid
      for _candidate in Cursor "Code" Windsurf; do
        _bid=$(osascript -e "tell application \"System Events\" to get bundle identifier of first process whose name is \"$_candidate\"" 2>/dev/null) && [ -n "$_bid" ] && { echo "$_bid"; return; }
      done
      echo "" ;;
    *)              echo "" ;;
  esac
}

# --- IDE ancestor PID detection (macOS click-to-focus for GUI IDEs) ---
# Walks up the process tree from the current PID looking for a known IDE.
# Returns the IDE PID, or 0 if none found. Skips "Helper" child processes.
_mac_ide_pid() {
  local _check=$$
  local _ide_pid=0
  local _i _comm
  for _i in 1 2 3 4 5 6 7 8 9 10; do
    _check=$(ps -p "$_check" -o ppid= 2>/dev/null | tr -d ' ')
    [ -z "$_check" ] || [ "$_check" = "1" ] || [ "$_check" = "0" ] && break
    _comm=$(ps -p "$_check" -o comm= 2>/dev/null)
    echo "$_comm" | grep -qi "helper" && continue
    if echo "$_comm" | grep -qi "cursor\|windsurf\|zed\| code"; then
      _ide_pid=$_check
      break
    fi
  done
  echo "$_ide_pid"
}

# --- Derive bundle ID from a running process PID (macOS) ---
# Uses lsappinfo (macOS built-in) to look up the bundle identifier of a
# running application by its PID. Returns empty string on failure.
_mac_bundle_id_from_pid() {
  local pid="$1"
  [ -z "$pid" ] || [ "$pid" = "0" ] && return
  lsappinfo info -only bundleid -app pid:"$pid" 2>/dev/null \
    | sed -n 's/.*="\([^"]*\)".*/\1/p'
}

# --- Platform-aware notification ---
# Args: msg, title, color (red/blue/yellow)
send_notification() {
  local msg="$1" title="$2" color="${3:-red}"
  local icon_path="${4:-$PEON_DIR/docs/peon-icon.png}"

  # Synchronous mode for tests (avoid race with backgrounded processes)
  local use_bg=true
  [ "${PEON_TEST:-0}" = "1" ] && use_bg=false

  case "$PLATFORM" in
    mac|wsl|linux|msys2)
      # Delegate to shared notify.sh script
      local notify_script
      notify_script="$(find_bundled_script "notify.sh")" 2>/dev/null || true
      [ -z "$notify_script" ] && return 0

      # Set env vars for notify.sh
      export PEON_PLATFORM="$PLATFORM"
      export PEON_NOTIF_STYLE="${NOTIF_STYLE:-overlay}"
      export PEON_DIR
      export PEON_SYNC="0"
      [ "${PEON_TEST:-0}" = "1" ] && export PEON_SYNC="1"
      if [ "$PLATFORM" = "mac" ]; then
        export PEON_BUNDLE_ID="$(_mac_terminal_bundle_id)"
        export PEON_IDE_PID="$(_mac_ide_pid)"
        # Fallback: if no terminal bundle ID but we found an IDE ancestor,
        # derive the bundle ID from the IDE PID (for embedded terminals like Cursor)
        if [ -z "$PEON_BUNDLE_ID" ] && [ "${PEON_IDE_PID:-0}" != "0" ]; then
          PEON_BUNDLE_ID="$(_mac_bundle_id_from_pid "$PEON_IDE_PID")"
        fi
        # Find session TTY for iTerm2 tab/window focus
        local session_tty=""
        if [ -n "${TMUX:-}" ]; then
          session_tty=$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)
        else
          local walk_pid="$PPID"
          while [ "$walk_pid" -gt 1 ] 2>/dev/null; do
            local walk_tty
            walk_tty=$(ps -p "$walk_pid" -o tty= 2>/dev/null | sed 's/^ *//' || true)
            if [ -n "$walk_tty" ] && [ "$walk_tty" != "??" ]; then
              session_tty="/dev/$walk_tty"
              break
            fi
            walk_pid=$(ps -p "$walk_pid" -o ppid= 2>/dev/null | sed 's/^ *//' || true)
          done
        fi
        export PEON_SESSION_TTY="$session_tty"
      fi
      export PEON_MSG_SUBTITLE="${MSG_SUBTITLE:-}"
      bash "$notify_script" "$msg" "$title" "$color" "$icon_path"
      ;;
    devcontainer|ssh)
      local relay_host_default="host.docker.internal"
      [ "$PLATFORM" = "ssh" ] && relay_host_default="localhost"
      local relay_host="${PEON_RELAY_HOST:-$relay_host_default}"
      local relay_port="${PEON_RELAY_PORT:-19998}"
      local json_title json_msg
      json_title=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$title" 2>/dev/null || echo "\"$title\"")
      json_msg=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$msg" 2>/dev/null || echo "\"$msg\"")
      if [ "$use_bg" = true ]; then
        nohup curl -sf -X POST \
          -H "Content-Type: application/json" \
          -d "{\"title\":${json_title},\"message\":${json_msg},\"color\":\"$color\"}" \
          "http://${relay_host}:${relay_port}/notify" >/dev/null 2>&1 &
      else
        curl -sf -X POST \
          -H "Content-Type: application/json" \
          -d "{\"title\":${json_title},\"message\":${json_msg},\"color\":\"$color\"}" \
          "http://${relay_host}:${relay_port}/notify" >/dev/null 2>&1
      fi
      ;;
  esac
}

# --- Platform-aware terminal focus check ---
terminal_is_focused() {
  case "$PLATFORM" in
    mac)
      local frontmost
      frontmost=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
      case "$frontmost" in
        iTerm2)
          # iTerm2 is frontmost, but check if OUR tab/pane is active
          local my_tty="${PEON_SESSION_TTY:-}"
          if [ -z "$my_tty" ]; then
            return 0  # No TTY info, assume focused
          fi
          local active_tty
          active_tty=$(osascript -e 'tell application "iTerm2" to tty of current session of current tab of current window' 2>/dev/null || true)
          if [ "$active_tty" = "$my_tty" ]; then
            return 0  # Our session is active
          fi
          return 1  # Different tab/pane is active — notify
          ;;
        Terminal|Warp|Alacritty|kitty|WezTerm|Ghostty) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    wsl|msys2)
      # Checking Windows focus from WSL/MSYS2 adds too much latency; always notify
      return 1
      ;;
    devcontainer|ssh)
      # Cannot detect host window focus from a container/remote; always notify
      return 1
      ;;
    linux)
      # Only use xdotool on X11; fallback to always notify on Wayland or if xdotool is missing
      if [ "${XDG_SESSION_TYPE:-}" = "x11" ] && command -v xdotool &>/dev/null; then
        local win_name
        win_name=$(xdotool getactivewindow getwindowname 2>/dev/null || echo "")
        if [[ "$win_name" =~ (terminal|konsole|alacritty|kitty|wezterm|foot|tilix|gnome-terminal|xterm|xfce4-terminal|sakura|terminator|st|urxvt|ghostty) ]]; then
          return 0
        fi
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

# --- Mobile push notification ---
# Sends push notifications to phone via ntfy.sh, Pushover, or Telegram.
# Config: config.json → mobile_notify: { service, topic/user_key/chat_id, ... }
send_mobile_notification() {
  local msg="$1" title="$2" color="${3:-red}"
  local config="$CONFIG_PY"

  # Read mobile config via Python (fast, single invocation)
  local mobile_vars
  mobile_vars=$(python3 -c "
import json, sys, shlex
q = shlex.quote
try:
    cfg = json.load(open('$config'))
    mn = cfg.get('mobile_notify', {})
except Exception:
    mn = {}
if not mn or not mn.get('enabled', True):
    print('MOBILE_SERVICE=')
    sys.exit(0)
service = mn.get('service', '')
print('MOBILE_SERVICE=' + q(service))
print('MOBILE_TOPIC=' + q(mn.get('topic', '')))
print('MOBILE_SERVER=' + q(mn.get('server', 'https://ntfy.sh')))
print('MOBILE_TOKEN=' + q(mn.get('token', '')))
print('MOBILE_USER_KEY=' + q(mn.get('user_key', '')))
print('MOBILE_APP_TOKEN=' + q(mn.get('app_token', '')))
print('MOBILE_CHAT_ID=' + q(mn.get('chat_id', '')))
print('MOBILE_BOT_TOKEN=' + q(mn.get('bot_token', '')))
" 2>/dev/null) || return 0

  eval "$mobile_vars"

  [ -z "$MOBILE_SERVICE" ] && return 0

  # Map color to priority
  local priority="default"
  case "$color" in
    red) priority="high" ;;
    yellow) priority="default" ;;
    blue) priority="low" ;;
  esac

  # Synchronous mode for tests (avoid race with backgrounded curl)
  local use_bg=true
  [ "${PEON_TEST:-0}" = "1" ] && use_bg=false

  case "$MOBILE_SERVICE" in
    ntfy)
      [ -z "$MOBILE_TOPIC" ] && return 0
      local ntfy_url="${MOBILE_SERVER}/${MOBILE_TOPIC}"
      local auth_header=""
      [ -n "$MOBILE_TOKEN" ] && auth_header="-H \"Authorization: Bearer ${MOBILE_TOKEN}\""
      if [ "$use_bg" = true ]; then
        nohup curl -sf \
          -H "Title: $title" \
          -H "Priority: $priority" \
          -H "Tags: video_game" \
          $auth_header \
          -d "$msg" \
          "$ntfy_url" >/dev/null 2>&1 &
      else
        curl -sf \
          -H "Title: $title" \
          -H "Priority: $priority" \
          -H "Tags: video_game" \
          $auth_header \
          -d "$msg" \
          "$ntfy_url" >/dev/null 2>&1
      fi
      ;;
    pushover)
      [ -z "$MOBILE_USER_KEY" ] || [ -z "$MOBILE_APP_TOKEN" ] && return 0
      local po_priority=0
      case "$priority" in
        high) po_priority=1 ;;
        low) po_priority=-1 ;;
      esac
      if [ "$use_bg" = true ]; then
        nohup curl -sf \
          -d "token=${MOBILE_APP_TOKEN}" \
          -d "user=${MOBILE_USER_KEY}" \
          -d "title=${title}" \
          -d "message=${msg}" \
          -d "priority=${po_priority}" \
          "https://api.pushover.net/1/messages.json" >/dev/null 2>&1 &
      else
        curl -sf \
          -d "token=${MOBILE_APP_TOKEN}" \
          -d "user=${MOBILE_USER_KEY}" \
          -d "title=${title}" \
          -d "message=${msg}" \
          -d "priority=${po_priority}" \
          "https://api.pushover.net/1/messages.json" >/dev/null 2>&1
      fi
      ;;
    telegram)
      [ -z "$MOBILE_BOT_TOKEN" ] || [ -z "$MOBILE_CHAT_ID" ] && return 0
      local tg_text="${title}%0A${msg}"
      if [ "$use_bg" = true ]; then
        nohup curl -sf "https://api.telegram.org/bot$MOBILE_BOT_TOKEN/sendMessage" \
          -d "chat_id=$MOBILE_CHAT_ID" \
          -d "text=${tg_text}" >/dev/null 2>&1 &
      else
        curl -sf "https://api.telegram.org/bot$MOBILE_BOT_TOKEN/sendMessage" \
          -d "chat_id=$MOBILE_CHAT_ID" \
          -d "text=${tg_text}" >/dev/null 2>&1
      fi
      ;;
  esac
}

# --- CLI subcommands (must come before INPUT=$(cat) which blocks on stdin) ---
PAUSED_FILE="$PEON_DIR/.paused"

# --- Sync shared config to OpenCode adapter config ---
# The OpenCode adapter is a standalone TypeScript plugin with its own config.json.
# After any CLI command that writes config or paused state, we sync shared keys
# so changes take effect in OpenCode without manual editing.
_ADAPTER_CONFIG_DIRS=()
_xdg="${XDG_CONFIG_HOME:-$HOME/.config}"
[ -d "$_xdg/opencode/peon-ping" ] && _ADAPTER_CONFIG_DIRS+=("$_xdg/opencode/peon-ping")
unset _xdg

sync_adapter_configs() {
  [ ${#_ADAPTER_CONFIG_DIRS[@]} -eq 0 ] && return 0
  for _dir in "${_ADAPTER_CONFIG_DIRS[@]}"; do
    _target="$_dir/config.json"
    python3 -c "
import json, sys, os

src_path = '$CONFIG'
dst_path = '$_target'

# Keys shared between peon.sh and standalone adapters
SHARED_KEYS = ('default_pack', 'active_pack', 'volume', 'enabled', 'desktop_notifications', 'pack_rotation', 'mobile_notify')

try:
    src = json.load(open(src_path))
except Exception:
    sys.exit(0)

try:
    dst = json.load(open(dst_path))
except Exception:
    dst = {}

changed = False
for key in SHARED_KEYS:
    if key in src and src[key] != dst.get(key):
        dst[key] = src[key]
        changed = True

if changed:
    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    json.dump(dst, open(dst_path, 'w'), indent=2)
" 2>/dev/null || true
  done
}

sync_adapter_paused() {
  [ ${#_ADAPTER_CONFIG_DIRS[@]} -eq 0 ] && return 0
  for _dir in "${_ADAPTER_CONFIG_DIRS[@]}"; do
    if [ -f "$PAUSED_FILE" ]; then
      touch "$_dir/.paused"
    else
      rm -f "$_dir/.paused"
    fi
  done
}

case "${1:-}" in
  pause)   touch "$PAUSED_FILE"; sync_adapter_paused; echo "peon-ping: sounds paused (run 'peon toggle' to unpause)"; exit 0 ;;
  resume)  rm -f "$PAUSED_FILE"; sync_adapter_paused; echo "peon-ping: sounds resumed"; exit 0 ;;
  toggle)
    if [ -f "$PAUSED_FILE" ]; then rm -f "$PAUSED_FILE"; echo "peon-ping: sounds resumed"
    else touch "$PAUSED_FILE"; echo "peon-ping: sounds paused (run 'peon toggle' to unpause)"; fi
    sync_adapter_paused; exit 0 ;;
  status)
    [ -f "$PAUSED_FILE" ] && echo "peon-ping: paused" || echo "peon-ping: active"
    python3 -c "
import json, os

config_path = '$CONFIG_PY'
peon_dir = '$PEON_DIR_PY'

# --- Config ---
try:
    c = json.load(open(config_path))
except Exception:
    c = {}

dn = c.get('desktop_notifications', True)
print('peon-ping: desktop notifications ' + ('on' if dn else 'off'))
ns = c.get('notification_style', 'overlay')
print('peon-ping: notification style ' + ns)

mn = c.get('mobile_notify', {})
if mn and mn.get('service'):
    enabled = mn.get('enabled', True)
    svc = mn.get('service', '?')
    print(f'peon-ping: mobile notifications ' + ('on' if enabled else 'off') + f' ({svc})')
else:
    print('peon-ping: mobile notifications not configured')

# --- Active pack ---
active = c.get('default_pack', c.get('active_pack', 'peon'))
packs_dir = os.path.join(peon_dir, 'packs')
display_name = active
pack_count = 0
if os.path.isdir(packs_dir):
    for d in os.listdir(packs_dir):
        dpath = os.path.join(packs_dir, d)
        if not os.path.isdir(dpath):
            continue
        has_manifest = (
            os.path.exists(os.path.join(dpath, 'openpeon.json')) or
            os.path.exists(os.path.join(dpath, 'manifest.json'))
        )
        if has_manifest:
            pack_count += 1
            if d == active:
                for mname in ('openpeon.json', 'manifest.json'):
                    mpath = os.path.join(dpath, mname)
                    if os.path.exists(mpath):
                        try:
                            display_name = json.load(open(mpath)).get('display_name', active)
                        except Exception:
                            pass
                        break
print(f'peon-ping: default pack: {active} ({display_name})')
print(f'peon-ping: {pack_count} pack(s) installed')
rules = c.get('path_rules', [])
if rules:
    print(f'peon-ping: path rules: {len(rules)} configured')

# --- IDE detection ---
home = os.path.expanduser('~')
claude_dir = os.environ.get('CLAUDE_CONFIG_DIR', os.path.join(home, '.claude'))
xdg_config = os.environ.get('XDG_CONFIG_HOME', os.path.join(home, '.config'))
opencode_dir = os.path.join(xdg_config, 'opencode')

ides = []

# Claude Code: check if hooks are registered
claude_hooks_dir = os.path.join(claude_dir, 'hooks', 'peon-ping')
if os.path.isdir(claude_dir):
    if os.path.exists(os.path.join(claude_hooks_dir, 'peon.sh')):
        ides.append(('Claude Code', claude_dir, 'installed'))
    else:
        ides.append(('Claude Code', claude_dir, 'detected (not set up)'))

# OpenCode: check if plugin is installed
opencode_plugin = os.path.join(opencode_dir, 'plugins', 'peon-ping.ts')
if os.path.isdir(opencode_dir):
    if os.path.exists(opencode_plugin):
        ides.append(('OpenCode', opencode_dir, 'installed'))
    else:
        ides.append(('OpenCode', opencode_dir, 'detected (not set up)'))

# Gemini CLI: check if hooks are registered in settings.json
gemini_dir = os.environ.get('GEMINI_CONFIG_DIR', os.path.join(home, '.gemini'))
gemini_settings = os.path.join(gemini_dir, 'settings.json')
if os.path.isfile(gemini_settings):
    try:
        with open(gemini_settings) as f:
            settings = json.load(f)
            hooks = settings.get('hooks', {})
            if any('gemini.sh' in str(h) for h in hooks.values()):
                ides.append(('Gemini CLI', gemini_dir, 'installed'))
            else:
                ides.append(('Gemini CLI', gemini_dir, 'detected (not set up)'))
    except Exception:
        ides.append(('Gemini CLI', gemini_dir, 'detected'))

if ides:
    print('peon-ping: IDEs')
    for name, path, status in ides:
        marker = '[x]' if status == 'installed' else '[ ]'
        print(f'  {marker} {name:12s} {path} ({status})')
else:
    print('peon-ping: no supported IDEs detected')
"
    exit 0 ;;
  notifications)
    case "${2:-}" in
      on)
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['desktop_notifications'] = True
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: desktop notifications on')
"
        sync_adapter_configs; exit 0 ;;
      off)
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['desktop_notifications'] = False
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: desktop notifications off')
"
        sync_adapter_configs; exit 0 ;;
      overlay)
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['notification_style'] = 'overlay'
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: notification style set to overlay')
"
        sync_adapter_configs; exit 0 ;;
      standard)
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['notification_style'] = 'standard'
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: notification style set to standard')
"
        sync_adapter_configs; exit 0 ;;
      test)
        # Read config to check if notifications are enabled and get style
        eval "$(python3 -c "
import json, shlex
q = shlex.quote
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
dn = cfg.get('desktop_notifications', True)
ns = cfg.get('notification_style', 'overlay')
print('_NOTIF_ENABLED=' + ('true' if dn else 'false'))
print('NOTIF_STYLE=' + q(ns))
")"
        if [ "$_NOTIF_ENABLED" != "true" ]; then
          echo "peon-ping: desktop notifications are off (run 'peon notifications on' to enable)" >&2
          exit 1
        fi
        echo "peon-ping: sending test notification (style: $NOTIF_STYLE)"
        PEON_TEST=1 send_notification "This is a test notification" "peon-ping" "blue"
        exit 0 ;;
      *)
        echo "Usage: peon notifications <on|off|overlay|standard|test>" >&2; exit 1 ;;
    esac ;;
  volume)
    VOL_ARG="${2:-}"
    if [ -z "$VOL_ARG" ]; then
      python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    print('peon-ping: volume ' + str(cfg.get('volume', 0.5)))
except Exception:
    print('peon-ping: volume 0.5')
"
      exit 0
    fi
    python3 -c "
import json, sys
config_path = '$CONFIG_PY'
try:
    vol = float('$VOL_ARG')
except ValueError:
    print('peon-ping: invalid volume \"$VOL_ARG\" — use a number between 0.0 and 1.0', file=sys.stderr)
    sys.exit(1)
if not (0.0 <= vol <= 1.0):
    print('peon-ping: volume must be between 0.0 and 1.0', file=sys.stderr)
    sys.exit(1)
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['volume'] = round(vol, 2)
json.dump(cfg, open(config_path, 'w'), indent=2)
print(f'peon-ping: volume set to {vol}')
"
    _rc=$?; [ $_rc -eq 0 ] && sync_adapter_configs; exit $_rc ;;
  rotation)
    ROT_ARG="${2:-}"
    if [ -z "$ROT_ARG" ]; then
      python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    mode = cfg.get('pack_rotation_mode', 'random')
    rotation = cfg.get('pack_rotation', [])
    print('peon-ping: rotation mode: ' + mode)
    if rotation:
        print('peon-ping: rotation packs: ' + ', '.join(rotation))
    else:
        print('peon-ping: rotation packs: (none — using default_pack)')
except Exception:
    print('peon-ping: rotation mode: random')
"
      exit 0
    fi
    case "$ROT_ARG" in
      random|round-robin|session_override|agentskill)
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
# Normalize agentskill alias to session_override
mode = '$ROT_ARG'
if mode == 'agentskill':
    mode = 'session_override'
cfg['pack_rotation_mode'] = mode
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: rotation mode set to ' + mode)
"
        _rc=$?; [ $_rc -eq 0 ] && sync_adapter_configs; exit $_rc ;;
      *)
        echo "Usage: peon rotation <random|round-robin|session_override>" >&2
        echo "" >&2
        echo "Modes:" >&2
        echo "  random           Pick a random pack each session (default)" >&2
        echo "  round-robin      Cycle through packs in order each session" >&2
        echo "  session_override Use /peon-ping-use to assign pack per session" >&2
        exit 1 ;;
    esac ;;
  packs)
    case "${2:-}" in
      list)
        if [ "${3:-}" = "--registry" ]; then
          PACK_DL="$(resolve_pack_download)" || exit 1
          bash "$PACK_DL" --list-registry --dir="$PEON_DIR"
          exit 0
        fi
        python3 -c "
import json, os, glob
config_path = '$CONFIG_PY'
try:
    _cfg_list = json.load(open(config_path))
    active = _cfg_list.get('default_pack', _cfg_list.get('active_pack', 'peon'))
except Exception:
    active = 'peon'
packs_dir = '$PEON_DIR_PY/packs'
for d in sorted(os.listdir(packs_dir)):
    for mname in ('openpeon.json', 'manifest.json'):
        mpath = os.path.join(packs_dir, d, mname)
        if os.path.exists(mpath):
            info = json.load(open(mpath))
            name = info.get('name', d)
            display = info.get('display_name', name)
            marker = ' *' if name == active else ''
            print(f'  {name:24s} {display}{marker}')
            break
"
        exit 0 ;;
      use)
        # Parse --install flag and pack name from args 3/4
        USE_INSTALL=0
        PACK_ARG=""
        for arg in "${3:-}" "${4:-}"; do
          case "$arg" in
            --install) USE_INSTALL=1 ;;
            "") ;;
            *) PACK_ARG="$arg" ;;
          esac
        done
        if [ -z "$PACK_ARG" ]; then
          echo "Usage: peon packs use <name> [--install]" >&2; exit 1
        fi

        # Check if pack exists locally
        PACK_EXISTS=0
        PACKS_DIR="$PEON_DIR/packs"
        if [ -d "$PACKS_DIR/$PACK_ARG" ] && { [ -f "$PACKS_DIR/$PACK_ARG/openpeon.json" ] || [ -f "$PACKS_DIR/$PACK_ARG/manifest.json" ]; }; then
          PACK_EXISTS=1
        fi

        # If pack missing (or --install always fetches), download it
        if [ "$USE_INSTALL" -eq 1 ]; then
          PACK_DL="$(resolve_pack_download)" || exit 1
          bash "$PACK_DL" --dir="$PEON_DIR" --packs="$PACK_ARG" || exit 1
        fi

        PACK_ARG="$PACK_ARG" python3 -c "
import json, os, glob, sys
config_path = '$CONFIG_PY'
pack_arg = os.environ.get('PACK_ARG', '')
packs_dir = '$PEON_DIR_PY/packs'
names = sorted([
    d for d in os.listdir(packs_dir)
    if os.path.isdir(os.path.join(packs_dir, d)) and (
        os.path.exists(os.path.join(packs_dir, d, 'openpeon.json')) or
        os.path.exists(os.path.join(packs_dir, d, 'manifest.json'))
    )
])
if pack_arg not in names:
    print(f'Error: pack \"{pack_arg}\" not found.', file=sys.stderr)
    print(f'Available packs: {\", \".join(names)}', file=sys.stderr)
    sys.exit(1)
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['default_pack'] = pack_arg
cfg.pop('active_pack', None)
try:
    json.dump(cfg, open(config_path, 'w'), indent=2)
except PermissionError:
    # Config is likely managed by Nix (symlink to store)
    if os.path.islink(config_path):
        print(f'Error: Cannot write to {config_path} — it is managed by Nix/Home Manager.', file=sys.stderr)
        print('To switch packs, update your Nix configuration:', file=sys.stderr)
        print('', file=sys.stderr)
        print('  programs.peon-ping.settings.default_pack = "' + pack_arg + '";', file=sys.stderr)
        print('', file=sys.stderr)
        print('Then rebuild your Nix configuration (e.g. darwin-rebuild switch --flake <path-to-your-flake>)', file=sys.stderr)
        sys.exit(1)
    else:
        print(f'Error: Cannot write to {config_path} — permission denied.', file=sys.stderr)
        sys.exit(1)
display = pack_arg
for mname in ('openpeon.json', 'manifest.json'):
    mpath = os.path.join(packs_dir, pack_arg, mname)
    if os.path.exists(mpath):
        display = json.load(open(mpath)).get('display_name', pack_arg)
        break
print(f'peon-ping: switched to {pack_arg} ({display})')
" || exit 1
        sync_adapter_configs; exit 0 ;;
      next)
        python3 -c "
import json, os, glob
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
active = cfg.get('default_pack', cfg.get('active_pack', 'peon'))
packs_dir = '$PEON_DIR_PY/packs'
names = sorted([
    d for d in os.listdir(packs_dir)
    if os.path.isdir(os.path.join(packs_dir, d)) and (
        os.path.exists(os.path.join(packs_dir, d, 'openpeon.json')) or
        os.path.exists(os.path.join(packs_dir, d, 'manifest.json'))
    )
])
if not names:
    print('Error: no packs found', flush=True)
    raise SystemExit(1)
try:
    idx = names.index(active)
    next_pack = names[(idx + 1) % len(names)]
except ValueError:
    next_pack = names[0]
cfg['default_pack'] = next_pack
cfg.pop('active_pack', None)
json.dump(cfg, open(config_path, 'w'), indent=2)
# Read display name
for mname in ('openpeon.json', 'manifest.json'):
    mpath = os.path.join(packs_dir, next_pack, mname)
    if os.path.exists(mpath):
        display = json.load(open(mpath)).get('display_name', next_pack)
        break
print(f'peon-ping: switched to {next_pack} ({display})')
"
        sync_adapter_configs; exit 0 ;;
      remove)
        REMOVE_ARG="${3:-}"
        if [ "$REMOVE_ARG" = "--all" ]; then
          PACKS_TO_REMOVE=$(python3 -c "
import json, os, sys

config_path = '$CONFIG_PY'
peon_dir = '$PEON_DIR_PY'
packs_dir = os.path.join(peon_dir, 'packs')

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
active = cfg.get('default_pack', cfg.get('active_pack', 'peon'))

installed = sorted([
    d for d in os.listdir(packs_dir)
    if os.path.isdir(os.path.join(packs_dir, d)) and (
        os.path.exists(os.path.join(packs_dir, d, 'openpeon.json')) or
        os.path.exists(os.path.join(packs_dir, d, 'manifest.json'))
    )
])

removable = [p for p in installed if p != active]
if not removable:
    print(f'No packs to remove — only the default pack (\"{active}\") is installed.', file=sys.stderr)
    sys.exit(1)

print(','.join(removable))
" 2>&1) || { echo "$PACKS_TO_REMOVE" >&2; exit 1; }
        elif [ -n "$REMOVE_ARG" ]; then
          PACKS_TO_REMOVE=$(REMOVE_ARG="$REMOVE_ARG" python3 -c "
import json, os, sys

config_path = '$CONFIG_PY'
peon_dir = '$PEON_DIR_PY'
packs_dir = os.path.join(peon_dir, 'packs')
remove_arg = os.environ.get('REMOVE_ARG', '')

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
active = cfg.get('default_pack', cfg.get('active_pack', 'peon'))

installed = sorted([
    d for d in os.listdir(packs_dir)
    if os.path.isdir(os.path.join(packs_dir, d)) and (
        os.path.exists(os.path.join(packs_dir, d, 'openpeon.json')) or
        os.path.exists(os.path.join(packs_dir, d, 'manifest.json'))
    )
])

requested = [p.strip() for p in remove_arg.split(',') if p.strip()]
errors = []
valid = []
for p in requested:
    if p not in installed:
        errors.append(f'Pack \"{p}\" not found.')
    elif p == active:
        errors.append(f'Cannot remove \"{p}\" — it is the default pack. Switch first with: peon packs use <other>')
    else:
        valid.append(p)

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    sys.exit(1)

remaining = len(installed) - len(valid)
if remaining < 1:
    print('Cannot remove all packs — at least 1 must remain.', file=sys.stderr)
    sys.exit(1)

print(','.join(valid))
" 2>&1) || { echo "$PACKS_TO_REMOVE" >&2; exit 1; }
        else
          echo "Usage: peon packs remove <pack1,pack2,...>" >&2
          echo "       peon packs remove --all" >&2
          echo "Run 'peon packs list' to see installed packs." >&2
          exit 1
        fi

        # If we got here with packs to remove, confirm and delete
        if [ -z "$PACKS_TO_REMOVE" ]; then
          exit 0
        fi

        # Count packs
        PACK_COUNT=$(echo "$PACKS_TO_REMOVE" | tr ',' '\n' | wc -l | tr -d ' ')
        read -r -p "Remove ${PACK_COUNT} pack(s)? [y/N] " CONFIRM
        case "$CONFIRM" in
          [yY]|[yY][eE][sS]) ;;
          *) echo "Cancelled."; exit 0 ;;
        esac

        # Delete pack directories and clean config
        python3 -c "
import json, os, shutil

config_path = '$CONFIG_PY'
peon_dir = '$PEON_DIR_PY'
packs_dir = os.path.join(peon_dir, 'packs')
to_remove = '$PACKS_TO_REMOVE'.split(',')

for pack in to_remove:
    pack_path = os.path.join(packs_dir, pack)
    if os.path.isdir(pack_path):
        shutil.rmtree(pack_path)
        print(f'Removed {pack}')

# Clean pack_rotation in config
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
rotation = cfg.get('pack_rotation', [])
if rotation:
    cfg['pack_rotation'] = [p for p in rotation if p not in to_remove]
    json.dump(cfg, open(config_path, 'w'), indent=2)
"
        sync_adapter_configs; exit 0 ;;
      install)
        INSTALL_ARG="${3:-}"
        PACK_DL="$(resolve_pack_download)" || exit 1
        if [ "$INSTALL_ARG" = "--all" ]; then
          bash "$PACK_DL" --dir="$PEON_DIR" --all
        elif [ -n "$INSTALL_ARG" ]; then
          bash "$PACK_DL" --dir="$PEON_DIR" --packs="$INSTALL_ARG"
        else
          echo "Usage: peon packs install <pack1,pack2,...>" >&2
          echo "       peon packs install --all" >&2
          echo "" >&2
          echo "Run 'peon packs list --registry' to see available packs." >&2
          exit 1
        fi
        exit 0 ;;
      install-local)
        LOCAL_SRC="${3:-}"
        LOCAL_FORCE=0
        # Parse --force flag from any position
        for _arg in "${@:3}"; do
          case "$_arg" in
            --force) LOCAL_FORCE=1 ;;
            *) [ -z "$LOCAL_SRC" ] || [ "$LOCAL_SRC" = "--force" ] && LOCAL_SRC="$_arg" ;;
          esac
        done
        [ "$LOCAL_SRC" = "--force" ] && LOCAL_SRC="${4:-}"
        if [ -z "$LOCAL_SRC" ]; then
          echo "Usage: peon packs install-local <path> [--force]" >&2
          echo "  Install a pack from a local directory (must contain openpeon.json)" >&2
          exit 1
        fi
        # Resolve to absolute path
        LOCAL_SRC="$(cd "$LOCAL_SRC" 2>/dev/null && pwd)" || { echo "Error: directory not found: ${3}" >&2; exit 1; }
        # Validate and copy via Python
        LOCAL_SRC="$LOCAL_SRC" LOCAL_FORCE="$LOCAL_FORCE" python3 -c "
import json, os, shutil, sys

src = os.environ['LOCAL_SRC']
force = os.environ.get('LOCAL_FORCE', '0') == '1'
packs_dir = os.path.join('$PEON_DIR_PY', 'packs')

manifest_name = 'openpeon.json' if os.path.exists(os.path.join(src, 'openpeon.json')) else 'manifest.json'
if os.path.exists(os.path.join(src, manifest_name)):
    manifest = json.load(open(os.path.join(src, manifest_name)))
else:
    print('Error: no openpeon.json or manifest.json found in ' + src, file=sys.stderr)
    sys.exit(1)
pack_name = manifest.get('name', os.path.basename(src))
dest = os.path.join(packs_dir, pack_name)
if os.path.exists(dest) and not force:
    print(f'Pack \"{pack_name}\" already exists. Use --force to overwrite.', file=sys.stderr)
    sys.exit(1)
if force and os.path.exists(dest):
    shutil.rmtree(dest)
warnings = []
for category in manifest.get('categories', {}).values():
    for sound in category.get('sounds', []):
        sf = sound.get('file')
        if sf and not os.path.exists(os.path.join(src, sf)):
            warnings.append(sf)
if warnings:
    print(f'Warning: {len(warnings)} missing sound file(s):', file=sys.stderr)
    for w in warnings:
        print(f'  {w}', file=sys.stderr)
shutil.copytree(src, dest)
print(f'Installed {pack_name}')
print(f'Use peon packs use {pack_name} to activate it')
" || exit 1
        sync_adapter_configs; exit 0 ;;
      rotation)
        ROT_SUB="${3:-}"
        ROT_ARG="${4:-}"
        case "$ROT_SUB" in
          add)
            if [ -z "$ROT_ARG" ]; then
              echo "Usage: peon packs rotation add <pack1,pack2,...>" >&2; exit 1
            fi
            ROT_ARG="$ROT_ARG" python3 -c "
import json, os, sys

config_path = '$GLOBAL_CONFIG_PY'
peon_dir = '$PEON_DIR_PY'
packs_dir = os.path.join(peon_dir, 'packs')
add_arg = os.environ.get('ROT_ARG', '')

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

installed = sorted([
    d for d in os.listdir(packs_dir)
    if os.path.isdir(os.path.join(packs_dir, d)) and (
        os.path.exists(os.path.join(packs_dir, d, 'openpeon.json')) or
        os.path.exists(os.path.join(packs_dir, d, 'manifest.json'))
    )
])

requested = [p.strip() for p in add_arg.split(',') if p.strip()]
rotation = cfg.get('pack_rotation', [])
added = []
errors = []
for p in requested:
    if p not in installed:
        errors.append(f'Pack \"{p}\" not found.')
    elif p in rotation:
        errors.append(f'Pack \"{p}\" already in rotation.')
    else:
        rotation.append(p)
        added.append(p)

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    if not added:
        sys.exit(1)

cfg['pack_rotation'] = rotation
json.dump(cfg, open(config_path, 'w'), indent=2)
for p in added:
    print(f'Added {p} to rotation')
print('Rotation: ' + ', '.join(rotation))
" || exit 1
            sync_adapter_configs; exit 0 ;;
          remove)
            if [ -z "$ROT_ARG" ]; then
              echo "Usage: peon packs rotation remove <pack1,pack2,...>" >&2; exit 1
            fi
            ROT_ARG="$ROT_ARG" python3 -c "
import json, os, sys

config_path = '$GLOBAL_CONFIG_PY'
remove_arg = os.environ.get('ROT_ARG', '')

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

rotation = cfg.get('pack_rotation', [])
requested = [p.strip() for p in remove_arg.split(',') if p.strip()]
removed = []
errors = []
for p in requested:
    if p not in rotation:
        errors.append(f'Pack \"{p}\" not in rotation.')
    else:
        rotation.remove(p)
        removed.append(p)

if errors:
    for e in errors:
        print(e, file=sys.stderr)
    if not removed:
        sys.exit(1)

cfg['pack_rotation'] = rotation
json.dump(cfg, open(config_path, 'w'), indent=2)
for p in removed:
    print(f'Removed {p} from rotation')
print('Rotation: ' + ', '.join(rotation))
" || exit 1
            sync_adapter_configs; exit 0 ;;
          list|"")
            python3 -c "
import json
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
rotation = cfg.get('pack_rotation', [])
mode = cfg.get('pack_rotation_mode', 'random')
print(f'Rotation mode: {mode}')
if rotation:
    for p in rotation:
        print(f'  {p}')
else:
    print('  (empty)')
"
            exit 0 ;;
          *)
            echo "Usage: peon packs rotation <list|add|remove>" >&2; exit 1 ;;
        esac ;;
      *)
        echo "Usage: peon packs <list|use|next|install|install-local|remove|rotation>" >&2; exit 1 ;;
    esac ;;
  mobile)
    case "${2:-}" in
      ntfy)
        TOPIC="${3:-}"
        if [ -z "$TOPIC" ]; then
          echo "Usage: peon mobile ntfy <topic> [--server=URL] [--token=TOKEN]" >&2
          echo "" >&2
          echo "Setup:" >&2
          echo "  1. Install ntfy app on your phone (ntfy.sh)" >&2
          echo "  2. Subscribe to your topic in the app" >&2
          echo "  3. Run: peon mobile ntfy my-unique-topic" >&2
          exit 1
        fi
        NTFY_SERVER="https://ntfy.sh"
        NTFY_TOKEN=""
        for arg in "${@:4}"; do
          case "$arg" in
            --server=*) NTFY_SERVER="${arg#--server=}" ;;
            --token=*)  NTFY_TOKEN="${arg#--token=}" ;;
          esac
        done
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['mobile_notify'] = {
    'enabled': True,
    'service': 'ntfy',
    'topic': '$TOPIC',
    'server': '$NTFY_SERVER',
    'token': '$NTFY_TOKEN'
}
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: mobile notifications enabled via ntfy"
        echo "  Topic:  $TOPIC"
        echo "  Server: $NTFY_SERVER"
        echo ""
        echo "Install the ntfy app and subscribe to '$TOPIC'"
        # Send test notification
        curl -sf -H "Title: peon-ping" -H "Tags: video_game" \
          -d "Mobile notifications connected!" \
          "${NTFY_SERVER}/${TOPIC}" >/dev/null 2>&1 && echo "Test notification sent!" || echo "Warning: could not reach ntfy server"
        sync_adapter_configs; exit 0 ;;
      pushover)
        USER_KEY="${3:-}"
        APP_TOKEN="${4:-}"
        if [ -z "$USER_KEY" ] || [ -z "$APP_TOKEN" ]; then
          echo "Usage: peon mobile pushover <user_key> <app_token>" >&2
          exit 1
        fi
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['mobile_notify'] = {
    'enabled': True,
    'service': 'pushover',
    'user_key': '$USER_KEY',
    'app_token': '$APP_TOKEN'
}
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: mobile notifications enabled via Pushover"
        sync_adapter_configs; exit 0 ;;
      telegram)
        BOT_TOKEN="${3:-}"
        CHAT_ID="${4:-}"
        if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
          echo "Usage: peon mobile telegram <bot_token> <chat_id>" >&2
          exit 1
        fi
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['mobile_notify'] = {
    'enabled': True,
    'service': 'telegram',
    'bot_token': '$BOT_TOKEN',
    'chat_id': '$CHAT_ID'
}
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: mobile notifications enabled via Telegram"
        sync_adapter_configs; exit 0 ;;
      off)
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
mn = cfg.get('mobile_notify', {})
mn['enabled'] = False
cfg['mobile_notify'] = mn
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: mobile notifications disabled"
        sync_adapter_configs; exit 0 ;;
      on)
        python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
mn = cfg.get('mobile_notify', {})
if not mn.get('service'):
    print('peon-ping: no mobile service configured. Run: peon mobile ntfy <topic>')
    raise SystemExit(1)
mn['enabled'] = True
cfg['mobile_notify'] = mn
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: mobile notifications enabled')
"
        _rc=$?; [ $_rc -eq 0 ] && sync_adapter_configs; exit $_rc ;;
      status)
        python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    mn = cfg.get('mobile_notify', {})
except Exception:
    mn = {}
if not mn or not mn.get('service'):
    print('peon-ping: mobile notifications not configured')
    print('  Run: peon mobile ntfy <topic>')
else:
    enabled = mn.get('enabled', True)
    service = mn.get('service', '?')
    status = 'on' if enabled else 'off'
    print(f'peon-ping: mobile notifications {status} ({service})')
    if service == 'ntfy':
        print(f'  Topic:  {mn.get(\"topic\", \"?\")}')
        print(f'  Server: {mn.get(\"server\", \"https://ntfy.sh\")}')
    elif service == 'pushover':
        print(f'  User:   {mn.get(\"user_key\", \"?\")[:8]}...')
    elif service == 'telegram':
        print(f'  Chat:   {mn.get(\"chat_id\", \"?\")}')
"
        exit 0 ;;
      test)
        python3 -c "
import json, sys
try:
    cfg = json.load(open('$CONFIG_PY'))
    mn = cfg.get('mobile_notify', {})
except Exception:
    mn = {}
if not mn or not mn.get('service') or not mn.get('enabled', True):
    print('peon-ping: mobile notifications not configured or disabled')
    sys.exit(1)
print('service=' + mn.get('service', ''))
" > /dev/null 2>&1 || { echo "peon-ping: mobile not configured" >&2; exit 1; }
        send_mobile_notification "Test notification from peon-ping" "peon-ping" "blue"
        wait
        echo "peon-ping: test notification sent"
        exit 0 ;;
      *)
        echo "Usage: peon mobile <ntfy|pushover|telegram|on|off|status|test>" >&2
        echo "" >&2
        echo "Quick start (free, no account needed):" >&2
        echo "  1. Install ntfy app on your phone (ntfy.sh)" >&2
        echo "  2. Subscribe to a unique topic in the app" >&2
        echo "  3. Run: peon mobile ntfy <your-topic>" >&2
        echo "" >&2
        echo "Commands:" >&2
        echo "  ntfy <topic>                Set up ntfy.sh notifications" >&2
        echo "  pushover <user> <app>       Set up Pushover notifications" >&2
        echo "  telegram <bot_token> <chat>  Set up Telegram notifications" >&2
        echo "  on                          Enable mobile notifications" >&2
        echo "  off                         Disable mobile notifications" >&2
        echo "  status                      Show current mobile config" >&2
        echo "  test                        Send a test notification" >&2
        exit 1 ;;
    esac ;;
  relay)
    # Find relay.sh - use original install dir (Nix, Homebrew), then PEON_DIR (legacy)
    RELAY_SCRIPT=""
    # _INSTALL_DIR is set at startup and preserved even when PEON_DIR changes to ~/.openpeon
    [ -f "${_INSTALL_DIR}/relay.sh" ] && RELAY_SCRIPT="${_INSTALL_DIR}/relay.sh"
    # Fallback: PEON_DIR (legacy install where relay.sh is in user dir)
    [ -z "$RELAY_SCRIPT" ] && [ -f "$PEON_DIR/relay.sh" ] && RELAY_SCRIPT="$PEON_DIR/relay.sh"
    if [ -z "$RELAY_SCRIPT" ] || [ ! -f "$RELAY_SCRIPT" ]; then
      echo "Error: relay.sh not found" >&2
      echo "Re-run the installer to get the relay script." >&2
      exit 1
    fi
    shift
    exec bash "$RELAY_SCRIPT" "$@"
    ;;
  preview)
    PREVIEW_CAT="${2:-session.start}"
    # --list: show all categories and sound counts in the active pack
    if [ "$PREVIEW_CAT" = "--list" ]; then
      python3 -c "
import json, os, sys

peon_dir = '$PEON_DIR_PY'
config_path = '$CONFIG_PY'

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
active_pack = cfg.get('default_pack', cfg.get('active_pack', 'peon'))

pack_dir = os.path.join(peon_dir, 'packs', active_pack)
if not os.path.isdir(pack_dir):
    print('peon-ping: pack \"' + active_pack + '\" not found.', file=sys.stderr)
    sys.exit(1)
manifest = None
for mname in ('openpeon.json', 'manifest.json'):
    mpath = os.path.join(pack_dir, mname)
    if os.path.exists(mpath):
        manifest = json.load(open(mpath))
        break
if not manifest:
    print('peon-ping: no manifest found for pack \"' + active_pack + '\".', file=sys.stderr)
    sys.exit(1)

display_name = manifest.get('display_name', active_pack)
categories = manifest.get('categories', {})
print('peon-ping: categories in ' + display_name)
print()
for cat in sorted(categories):
    sounds = categories[cat].get('sounds', [])
    count = len(sounds)
    unit = 'sound' if count == 1 else 'sounds'
    print(f'  {cat:24s} {count} {unit}')
"
      exit $? ;
    fi
    # Use Python to load config, find manifest, and list sounds for the category
    PREVIEW_OUTPUT=$(python3 -c "
import json, os, sys

peon_dir = '$PEON_DIR_PY'
config_path = '$CONFIG_PY'

# Load config
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
volume = cfg.get('volume', 0.5)
use_sound_effects_device = cfg.get('use_sound_effects_device', True)
active_pack = cfg.get('default_pack', cfg.get('active_pack', 'peon'))

# Load manifest
pack_dir = os.path.join(peon_dir, 'packs', active_pack)
if not os.path.isdir(pack_dir):
    print('ERROR:Pack \"' + active_pack + '\" not found.', file=sys.stderr)
    sys.exit(1)
manifest = None
for mname in ('openpeon.json', 'manifest.json'):
    mpath = os.path.join(pack_dir, mname)
    if os.path.exists(mpath):
        manifest = json.load(open(mpath))
        break
if not manifest:
    print('ERROR:No manifest found for pack \"' + active_pack + '\".', file=sys.stderr)
    sys.exit(1)

category = '$PREVIEW_CAT'
categories = manifest.get('categories', {})
cat_data = categories.get(category)
if not cat_data or not cat_data.get('sounds'):
    avail = ', '.join(sorted(c for c in categories if categories[c].get('sounds')))
    print('ERROR:Category \"' + category + '\" not found in pack \"' + active_pack + '\".', file=sys.stderr)
    print('Available categories: ' + avail, file=sys.stderr)
    sys.exit(1)

display_name = manifest.get('display_name', active_pack)
print('PACK_DISPLAY=' + repr(display_name))
print('VOLUME=' + str(volume))
print('USE_SOUND_EFFECTS_DEVICE=' + str(use_sound_effects_device).lower())

sounds = cat_data['sounds']
for i, s in enumerate(sounds):
    file_ref = s.get('file', '')
    label = s.get('label', file_ref)
    if '/' in file_ref:
        fpath = os.path.realpath(os.path.join(pack_dir, file_ref))
    else:
        fpath = os.path.realpath(os.path.join(pack_dir, 'sounds', file_ref))
    pack_root = os.path.realpath(pack_dir) + os.sep
    if not fpath.startswith(pack_root):
        continue
    print('SOUND:' + fpath + '|' + label)
" 2>"$PEON_DIR/.preview_err")
    PREVIEW_RC=$?
    if [ $PREVIEW_RC -ne 0 ]; then
      cat "$PEON_DIR/.preview_err" | sed 's/^ERROR:/peon-ping: /' >&2
      rm -f "$PEON_DIR/.preview_err"
      exit 1
    fi
    rm -f "$PEON_DIR/.preview_err"

    # Parse output
    PREVIEW_VOL=$(echo "$PREVIEW_OUTPUT" | grep '^VOLUME=' | head -1 | cut -d= -f2)
    PREVIEW_VOL="${PREVIEW_VOL:-0.5}"
    USE_SOUND_EFFECTS_DEVICE=$(echo "$PREVIEW_OUTPUT" | grep '^USE_SOUND_EFFECTS_DEVICE=' | head -1 | cut -d= -f2)
    USE_SOUND_EFFECTS_DEVICE="${USE_SOUND_EFFECTS_DEVICE:-true}"
    PACK_DISPLAY=$(echo "$PREVIEW_OUTPUT" | grep '^PACK_DISPLAY=' | head -1 | sed "s/^PACK_DISPLAY=//;s/^'//;s/'$//")

    echo "peon-ping: previewing [$PREVIEW_CAT] from $PACK_DISPLAY"
    echo ""

    echo "$PREVIEW_OUTPUT" | grep '^SOUND:' | while IFS='|' read -r filepath label; do
      filepath="${filepath#SOUND:}"
      if [ -f "$filepath" ]; then
        echo "  ▶ $label"
        play_sound "$filepath" "$PREVIEW_VOL"
        wait
        sleep 0.3
      fi
    done
    exit 0 ;;
  update)
    echo "Updating peon-ping..."
    # Migrate config keys (active_pack → default_pack, agentskill → session_override)
    python3 -c "
import json, os
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
changed = False
if 'active_pack' in cfg and 'default_pack' not in cfg:
    cfg['default_pack'] = cfg.pop('active_pack')
    changed = True
elif 'active_pack' in cfg:
    cfg.pop('active_pack')
    changed = True
if cfg.get('pack_rotation_mode') == 'agentskill':
    cfg['pack_rotation_mode'] = 'session_override'
    changed = True
if changed:
    json.dump(cfg, open(config_path, 'w'), indent=2)
    print('peon-ping: config migrated (active_pack \u2192 default_pack, agentskill \u2192 session_override)')
" 2>/dev/null || true
    INSTALL_SCRIPT="$PEON_DIR/install.sh"
    if [ -f "$INSTALL_SCRIPT" ]; then
      bash "$INSTALL_SCRIPT"
    else
      curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash
    fi
    exit $? ;;
  help|--help|-h)
    cat <<'HELPEOF'
Usage: peon <command>

Commands:
  pause                Mute sounds
  resume               Unmute sounds
  toggle               Toggle mute on/off
  status               Check if paused or active
  volume [0.0-1.0]     Get or set volume level
  rotation [mode]      Get or set pack rotation mode (random|round-robin|session_override)
  notifications on        Enable desktop notifications
  notifications off       Disable desktop notifications
  notifications overlay   Use large overlay banners (default)
  notifications standard  Use standard system notifications
  notifications test      Send a test notification
  preview [category]   Play all sounds from a category (default: session.start)
  preview --list       List all categories and sound counts in the active pack
                       Categories: session.start, task.acknowledge, task.complete,
                       task.error, input.required, resource.limit, user.spam
  update               Update peon-ping and refresh all sound packs
  help                 Show this help

Pack management:
  packs list              List installed sound packs
  packs list --registry   List all available packs from registry
  packs install <p1,p2>   Download and install new packs
  packs install --all     Download all packs from registry
  packs install-local <path> Install a pack from a local directory
  packs use <name>        Switch to a specific pack
  packs use --install <n> Switch to pack, installing from registry if needed
  packs next              Cycle to the next pack
  packs remove <p1,p2>    Remove specific packs
  packs remove --all      Remove all packs except the active one
  packs rotation list     Show current rotation list and mode
  packs rotation add <p>  Add pack(s) to rotation (comma-separated)
  packs rotation remove <p> Remove pack(s) from rotation

Mobile notifications:
  mobile ntfy <topic>      Set up ntfy.sh push notifications
  mobile pushover          Set up Pushover push notifications
  mobile telegram          Set up Telegram bot notifications
  mobile on                Re-enable mobile notifications (after off)
  mobile off               Disable mobile notifications
  mobile status            Show mobile config
  mobile test              Send a test notification

Trainer (exercise reminders):
  trainer on           Enable trainer mode
  trainer off          Disable trainer mode
  trainer status       Show today's progress
  trainer log <n> <ex> Log completed reps (e.g. log 25 pushups)
  trainer goal <n>     Set daily goal for all exercises
  trainer goal <ex> <n> Set daily goal for one exercise
  trainer help         Show trainer help

Relay (SSH/devcontainer/Codespaces):
  relay [--port=N]        Start audio relay on your local machine
  relay --bind=<addr>     Bind relay to a specific address (default: 127.0.0.1)
  relay --daemon          Start relay in background
  relay --stop            Stop background relay
  relay --status          Check if relay is running
HELPEOF
    exit 0 ;;
  trainer)
    shift
    case "${1:-help}" in
      on)
        python3 -c "
import json
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
trainer = cfg.get('trainer', {})
trainer['enabled'] = True
if 'exercises' not in trainer:
    trainer['exercises'] = {'pushups': 300, 'squats': 300}
if 'reminder_interval_minutes' not in trainer:
    trainer['reminder_interval_minutes'] = 20
if 'reminder_min_gap_minutes' not in trainer:
    trainer['reminder_min_gap_minutes'] = 5
cfg['trainer'] = trainer
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: trainer enabled"
        exit 0 ;;
      off)
        python3 -c "
import json
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
trainer = cfg.get('trainer', {})
trainer['enabled'] = False
cfg['trainer'] = trainer
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: trainer disabled"
        exit 0 ;;
      status)
        python3 -c "
import json, datetime, sys

config_path = '$CONFIG_PY'
state_path = '$STATE_PY'

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

trainer_cfg = cfg.get('trainer', {})
if not trainer_cfg.get('enabled', False):
    print('peon-ping: trainer not enabled')
    print('Run \"peon trainer on\" to enable.')
    sys.exit(0)

exercises = trainer_cfg.get('exercises', {'pushups': 300, 'squats': 300})

try:
    state = json.load(open(state_path))
except Exception:
    state = {}

trainer_state = state.get('trainer', {})
today = datetime.date.today().isoformat()

# Auto-reset if date changed
if trainer_state.get('date', '') != today:
    trainer_state = {'date': today, 'reps': {k: 0 for k in exercises}, 'last_reminder_ts': 0}
    state['trainer'] = trainer_state
    json.dump(state, open(state_path, 'w'), indent=2)

reps = trainer_state.get('reps', {})

print('peon-ping: trainer status (' + today + ')')
print('')

bar_width = 16
for ex, goal in exercises.items():
    done = reps.get(ex, 0)
    pct = min(done / goal, 1.0) if goal > 0 else 0
    filled = int(pct * bar_width)
    empty = bar_width - filled
    bar = '\u2588' * filled + '\u2591' * empty
    pct_str = str(int(pct * 100))
    print(f'{ex}:  {bar}  {done}/{goal}  ({pct_str}%)')
"
        exit 0 ;;
      log)
        shift
        COUNT="${1:-}"
        EXERCISE="${2:-}"
        if [ -z "$COUNT" ] || [ -z "$EXERCISE" ]; then
          echo "Usage: peon trainer log <count> <exercise>" >&2
          echo "Example: peon trainer log 25 pushups" >&2
          exit 1
        fi
        # Validate numeric
        case "$COUNT" in
          ''|*[!0-9]*) echo "peon-ping: count must be a number" >&2; exit 1 ;;
        esac
        python3 -c "
import json, datetime, sys

config_path = '$CONFIG_PY'
state_path = '$STATE_PY'
count = int('$COUNT')
exercise = '$EXERCISE'

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

trainer_cfg = cfg.get('trainer', {})
exercises = trainer_cfg.get('exercises', {'pushups': 300, 'squats': 300})

if exercise not in exercises:
    print('peon-ping: unknown exercise \"' + exercise + '\"', file=sys.stderr)
    if exercises:
        print('Known exercises: ' + ', '.join(exercises.keys()), file=sys.stderr)
    print('Add it first: peon trainer goal ' + exercise + ' <daily-goal>', file=sys.stderr)
    sys.exit(1)

goal = exercises[exercise]

try:
    state = json.load(open(state_path))
except Exception:
    state = {}

trainer_state = state.get('trainer', {})
today = datetime.date.today().isoformat()

# Auto-reset if date changed
if trainer_state.get('date', '') != today:
    trainer_state = {'date': today, 'reps': {k: 0 for k in exercises}, 'last_reminder_ts': 0}

reps = trainer_state.get('reps', {})
reps[exercise] = reps.get(exercise, 0) + count
trainer_state['reps'] = reps
trainer_state['date'] = today
state['trainer'] = trainer_state
json.dump(state, open(state_path, 'w'), indent=2)

done = reps[exercise]
pct = min(done / goal, 1.0) if goal > 0 else 0
bar_width = 16
filled = int(pct * bar_width)
empty = bar_width - filled
bar = '\u2588' * filled + '\u2591' * empty
print(f'peon-ping: logged {count} {exercise} ({done}/{goal})')
print(f'  {bar}  {int(pct*100)}%')
"
        exit $? ;;
      goal)
        shift
        ARG1="${1:-}"
        ARG2="${2:-}"
        if [ -z "$ARG1" ]; then
          echo "Usage: peon trainer goal <number>           Set all exercises" >&2
          echo "       peon trainer goal <exercise> <number> Set one exercise" >&2
          exit 1
        fi
        python3 -c "
import json, sys

config_path = '$GLOBAL_CONFIG_PY'
arg1 = '$ARG1'
arg2 = '$ARG2'

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

trainer = cfg.get('trainer', {})
exercises = trainer.get('exercises', {'pushups': 300, 'squats': 300})

if arg2:
    # goal <exercise> <number>
    exercise = arg1
    try:
        num = int(arg2)
    except ValueError:
        print('peon-ping: goal must be a number', file=sys.stderr)
        sys.exit(1)
    is_new = exercise not in exercises
    exercises[exercise] = num
    if is_new:
        print(f'peon-ping: new exercise added — {exercise} goal set to {num}')
    else:
        print(f'peon-ping: {exercise} goal set to {num}')
else:
    # goal <number>
    try:
        num = int(arg1)
    except ValueError:
        print('peon-ping: goal must be a number', file=sys.stderr)
        sys.exit(1)
    for k in exercises:
        exercises[k] = num
    print(f'peon-ping: all exercise goals set to {num}')

trainer['exercises'] = exercises
cfg['trainer'] = trainer
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        exit $? ;;
      help|*)
        cat <<'TRAINER_HELP'
Usage: peon trainer <command>

Commands:
  on                   Enable trainer mode
  off                  Disable trainer mode
  status               Show today's progress
  log <count> <exercise>  Log completed reps (e.g. log 25 pushups)
  goal <number>        Set daily goal for all exercises
  goal <exercise> <n>  Set daily goal for one exercise
  help                 Show this help

Exercises: pushups, squats
TRAINER_HELP
        exit 0 ;;
    esac ;;
  --*)
    echo "Unknown option: $1" >&2
    echo "Run 'peon help' for usage." >&2; exit 1 ;;
  ?*)
    echo "Unknown command: $1" >&2
    echo "Run 'peon help' for usage." >&2; exit 1 ;;
esac

# If no CLI arg was given and stdin is a terminal (not a pipe from Claude Code),
# the user likely ran `peon` bare — show help instead of blocking on cat.
if [ -t 0 ]; then
  echo "Usage: peon <command>"
  echo ""
  echo "Run 'peon help' for full command list."
  exit 0
fi

INPUT=$(cat)

# Debug log (uncomment to troubleshoot)
# echo "$(date): peon hook — $INPUT" >> /tmp/peon-ping-debug.log

PAUSED=false
[ -f "$PEON_DIR/.paused" ] && PAUSED=true

# --- Single Python call: config, event parsing, agent detection, category routing, sound picking ---
# Consolidates 5 separate python3 invocations into one for ~120-200ms faster hook response.
# Outputs shell variables consumed by the bash play/notify/title logic below.
eval "$(python3 -c "
import sys, json, os, re, random, time, shlex
q = shlex.quote

config_path = '$CONFIG_PY'
state_file = '$STATE_PY'
peon_dir = '$PEON_DIR_PY'
paused = '$PAUSED' == 'true'
agent_modes = {'delegate'}
state_dirty = False

# --- Load config ---
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

if str(cfg.get('enabled', True)).lower() == 'false':
    print('PEON_EXIT=true')
    sys.exit(0)

volume = cfg.get('volume', 0.5)
desktop_notif = cfg.get('desktop_notifications', True)
use_sound_effects_device = cfg.get('use_sound_effects_device', True)
linux_audio_player = cfg.get('linux_audio_player', '')
tab_color_cfg = cfg.get('tab_color', {})
tab_color_enabled = str(tab_color_cfg.get('enabled', True)).lower() != 'false'
active_pack = cfg.get('default_pack', cfg.get('active_pack', 'peon'))
pack_rotation = cfg.get('pack_rotation', [])
annoyed_threshold = int(cfg.get('annoyed_threshold', 3))
annoyed_window = float(cfg.get('annoyed_window_seconds', 10))
silent_window = float(cfg.get('silent_window_seconds', 0))
suppress_subagent_complete = str(cfg.get('suppress_subagent_complete', False)).lower() == 'true'
cats = cfg.get('categories', {})
cat_enabled = {}
default_off = {'task.acknowledge'}
for c in ['session.start','task.acknowledge','task.complete','task.error','input.required','resource.limit','user.spam']:
    default = False if c in default_off else True
    cat_enabled[c] = str(cats.get(c, default)).lower() == 'true'

# --- Parse event JSON from stdin ---
event_data = json.load(sys.stdin)
raw_event = event_data.get('hook_event_name', '')

# Cursor IDE sends lowercase camelCase event names via its Third-party skills
# (Claude Code compatibility) mode. Map them to the PascalCase names used below.
# Claude Code's own PascalCase names pass through unchanged via dict.get fallback.
_cursor_event_map = {
    'sessionStart': 'SessionStart',
    'sessionEnd': 'SessionEnd',
    'beforeSubmitPrompt': 'UserPromptSubmit',
    'stop': 'Stop',
    'preToolUse': 'UserPromptSubmit',
    'postToolUse': 'Stop',
    'subagentStop': 'Stop',
    'subagentStart': 'SubagentStart',
    'preCompact': 'PreCompact',
}
event = _cursor_event_map.get(raw_event, raw_event)

ntype = event_data.get('notification_type', '')
# Cursor sends workspace_roots[] instead of cwd
_roots = event_data.get('workspace_roots', [])
cwd = event_data.get('cwd', '') or (_roots[0] if _roots else '')
session_id = event_data.get('session_id', '') or event_data.get('conversation_id', '')
perm_mode = event_data.get('permission_mode', '')
session_source = event_data.get('source', '')

# --- Load state ---
try:
    state = json.load(open(state_file))
except Exception:
    state = {}

# --- Agent detection ---
agent_sessions = set(state.get('agent_sessions', []))
if perm_mode and perm_mode in agent_modes:
    agent_sessions.add(session_id)
    state['agent_sessions'] = list(agent_sessions)
    state_dirty = True
    print('PEON_EXIT=true')
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    json.dump(state, open(state_file, 'w'))
    sys.exit(0)
elif session_id in agent_sessions:
    print('PEON_EXIT=true')
    sys.exit(0)

# --- Session cleanup: expire old sessions ---
now = time.time()
cutoff = now - cfg.get('session_ttl_days', 7) * 86400
session_packs = state.get('session_packs', {})
session_packs_clean = {}
for sid, pack_data in session_packs.items():
    if isinstance(pack_data, dict):
        # New format with timestamp
        if pack_data.get('last_used', 0) > cutoff:
            pack_data['last_used'] = now if sid == session_id else pack_data['last_used']
            session_packs_clean[sid] = pack_data
    elif sid == session_id:
        # Old format, upgrade active session
        session_packs_clean[sid] = dict(pack=pack_data, last_used=now)
    elif isinstance(pack_data, str):
        # Old format for inactive sessions - keep only if we can't determine age
        # This is a migration path; on next use, it will be upgraded
        session_packs_clean[sid] = pack_data
session_packs = session_packs_clean
if session_packs != state.get('session_packs', {}):
    state['session_packs'] = session_packs
    state_dirty = True

# --- Pack rotation: pin a pack per session ---
rotation_mode = cfg.get('pack_rotation_mode', 'random')

# --- Path rules: first glob match wins (layer 3 in override hierarchy) ---
# Beats rotation and default_pack; loses to session_override and local config.
import fnmatch
_path_rule_pack = None
for _rule in cfg.get('path_rules', []):
    _pat = _rule.get('pattern', '')
    _candidate = _rule.get('pack', '')
    if cwd and _pat and _candidate and fnmatch.fnmatch(cwd, _pat):
        if os.path.isdir(os.path.join(peon_dir, 'packs', _candidate)):
            _path_rule_pack = _candidate
            break

_default_pack = cfg.get('default_pack', cfg.get('active_pack', 'peon'))

if rotation_mode in ('session_override', 'agentskill'):
    # Explicit per-session assignments (from /peon-ping-use skill)
    session_packs = state.get('session_packs', {})
    if session_id in session_packs and session_packs[session_id]:
        pack_data = session_packs[session_id]
        # Handle both old string format and new dict format
        if isinstance(pack_data, dict):
            candidate = pack_data.get('pack', '')
        else:
            candidate = pack_data
        # Validate pack exists, fallback to path_rule or default_pack if missing
        candidate_dir = os.path.join(peon_dir, 'packs', candidate)
        if candidate and os.path.isdir(candidate_dir):
            active_pack = candidate
            # Update timestamp for this session
            session_packs[session_id] = dict(pack=candidate, last_used=time.time())
            state['session_packs'] = session_packs
            state_dirty = True
        else:
            # Pack was deleted or invalid, fall through hierarchy
            active_pack = _path_rule_pack or _default_pack
            # Clean up invalid entry
            del session_packs[session_id]
            state['session_packs'] = session_packs
            state_dirty = True
    else:
        # No assignment: check session_packs 'default' key (for Cursor users without conversation_id)
        default_data = session_packs.get('default')
        if default_data:
            candidate = default_data.get('pack', default_data) if isinstance(default_data, dict) else default_data
            candidate_dir = os.path.join(peon_dir, 'packs', candidate)
            if candidate and os.path.isdir(candidate_dir):
                active_pack = candidate
            else:
                active_pack = _path_rule_pack or _default_pack
        else:
            active_pack = _path_rule_pack or _default_pack
elif pack_rotation and rotation_mode in ('random', 'round-robin'):
    if _path_rule_pack:
        # Path rule beats rotation
        active_pack = _path_rule_pack
    else:
        # Automatic rotation — detect context resets (new session_id within seconds
        # of the last event, no Stop in between) and reuse the previous pack.
        session_packs = state.get('session_packs', {})
        _sp_entry = session_packs.get(session_id)
        _sp_pack = _sp_entry.get('pack', '') if isinstance(_sp_entry, dict) else (_sp_entry or '')
        if session_id in session_packs and _sp_pack in pack_rotation:
            active_pack = _sp_pack
        else:
            inherited = False
            if event == 'SessionStart':
                last_active = state.get('last_active', {})
                la_sid = last_active.get('session_id', '')
                la_ts = last_active.get('timestamp', 0)
                la_evt = last_active.get('event', '')
                la_pack = last_active.get('pack', '')
                # Resume: keep whatever pack was last used for this session
                if session_source == 'resume' and la_pack in pack_rotation:
                    active_pack = la_pack
                    inherited = True
                # Subagent inheritance: parent just spawned a subagent, use parent's pack
                elif state.get('pending_subagent_pack') and (time.time() - state['pending_subagent_pack'].get('ts', 0) < 30):
                    parent_pack = state['pending_subagent_pack'].get('pack', '')
                    if parent_pack in pack_rotation:
                        active_pack = parent_pack
                        inherited = True
                    # Mark this session as a subagent so Stop can suppress its completion sound
                    subagent_sessions = state.get('subagent_sessions', {})
                    subagent_sessions[session_id] = time.time()
                    # Prune entries older than 5 minutes to avoid unbounded growth
                    now_ts = time.time()
                    subagent_sessions = dict((sid, ts) for sid, ts in subagent_sessions.items() if now_ts - ts < 300)
                    state['subagent_sessions'] = subagent_sessions
                    state_dirty = True
                # Context reset: recent activity from another session, no Stop/SessionEnd
                elif (la_sid and la_sid != session_id and la_pack in pack_rotation
                        and la_evt not in ('Stop', 'SessionEnd')
                        and time.time() - la_ts < 15):
                    active_pack = la_pack
                    inherited = True
            if not inherited:
                if rotation_mode == 'round-robin':
                    rotation_index = state.get('rotation_index', 0) % len(pack_rotation)
                    active_pack = pack_rotation[rotation_index]
                    state['rotation_index'] = rotation_index + 1
                else:
                    active_pack = random.choice(pack_rotation)
            session_packs[session_id] = active_pack
            state['session_packs'] = session_packs
            state_dirty = True
else:
    # Default: path_rule if matched, otherwise default_pack
    active_pack = _path_rule_pack or _default_pack

# --- Track last active session for context-reset detection ---
state['last_active'] = dict(session_id=session_id, pack=active_pack,
                            timestamp=time.time(), event=event, cwd=cwd)
state_dirty = True

# --- Project name (git repo name, fallback to directory name) ---
project = ''
if cwd:
    try:
        import subprocess
        _git_remote = subprocess.check_output(
            ['git', 'remote', 'get-url', 'origin'],
            cwd=cwd, stderr=subprocess.DEVNULL, timeout=2
        ).decode().strip()
        # Extract repo name from URL (handles ssh and https)
        project = _git_remote.rstrip('/').rsplit('/', 1)[-1].removesuffix('.git')
    except Exception:
        pass
    if not project:
        project = cwd.rsplit('/', 1)[-1]
if not project:
    project = 'claude'
project = re.sub(r'[^a-zA-Z0-9 ._-]', '', project)

# --- Event routing ---
category = ''
status = ''
marker = ''
notify = ''
notify_color = ''
msg = ''
msg_subtitle = ''

if event == 'SessionStart':
    source = event_data.get('source', '')
    if source == 'compact':
        # Compaction is mid-conversation — greeting makes no sense
        print('PEON_EXIT=true')
        sys.exit(0)
    category = 'session.start'
    status = 'ready'
elif event == 'UserPromptSubmit':
    status = 'working'
    if cat_enabled.get('user.spam', True):
        all_ts = state.get('prompt_timestamps', {})
        if isinstance(all_ts, list):
            all_ts = {}
        now = time.time()
        ts = [t for t in all_ts.get(session_id, []) if now - t < annoyed_window]
        ts.append(now)
        all_ts[session_id] = ts
        state['prompt_timestamps'] = all_ts
        state_dirty = True
        if len(ts) >= annoyed_threshold:
            category = 'user.spam'
    if not category and cat_enabled.get('task.acknowledge', False):
        category = 'task.acknowledge'
        status = 'working'
    if silent_window > 0:
        prompt_starts = state.get('prompt_start_times', {})
        prompt_starts[session_id] = time.time()
        state['prompt_start_times'] = prompt_starts
        state_dirty = True
elif event == 'Stop':
    category = 'task.complete'
    # Suppress completion sound/notification for known sub-agent sessions
    if suppress_subagent_complete and session_id in state.get('subagent_sessions', {}):
        os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
        json.dump(state, open(state_file, 'w'))
        print('PEON_EXIT=true')
        sys.exit(0)
    silent = False
    if silent_window > 0:
        prompt_starts = state.get('prompt_start_times', {})
        # start_time=0 when no prior prompt; 0 is falsy so short-circuits to not-silent
        start_time = prompt_starts.pop(session_id, 0)
        if start_time and (time.time() - start_time) < silent_window:
            silent = True
        state['prompt_start_times'] = prompt_starts
        state_dirty = True
    status = 'done'
    if not silent:
        marker = '\u25cf '
        notify = '1'
        notify_color = 'blue'
        msg = project
        msg_subtitle = ''
    else:
        category = ''
elif event == 'Notification':
    if ntype == 'permission_prompt':
        # Sound is handled by the PermissionRequest event; only set tab title here
        status = 'needs approval'
        marker = '\u25cf '
    elif ntype == 'idle_prompt':
        status = 'done'
        marker = '\u25cf '
        notify = '1'
        notify_color = 'yellow'
        msg = project
    elif ntype == 'elicitation_dialog':
        category = 'input.required'
        status = 'question'
        marker = '\u25cf '
        notify = '1'
        notify_color = 'blue'
        msg = project
        msg_subtitle = 'Question pending'
    else:
        print('PEON_EXIT=true')
        sys.exit(0)
elif event == 'PermissionRequest':
    category = 'input.required'
    status = 'needs approval'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'red'
    msg = project
    _tool = event_data.get('tool_name', '')
    msg_subtitle = _tool
elif event == 'PostToolUseFailure':
    # Bash failures arrive here with error field (e.g. Exit code 1)
    tool_name = event_data.get('tool_name', '')
    error_msg = event_data.get('error', '')
    if tool_name == 'Bash' and error_msg:
        category = 'task.error'
        status = 'error'
    else:
        print('PEON_EXIT=true')
        sys.exit(0)
elif event == 'SubagentStart':
    # Record parent's pack so spawned subagent sessions inherit it, then stay silent
    state['pending_subagent_pack'] = dict(ts=time.time(), pack=active_pack)
    state_dirty = True
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    json.dump(state, open(state_file, 'w'))
    print('PEON_EXIT=true')
    sys.exit(0)
elif event == 'PreCompact':
    # Context window filling up — compaction about to start
    category = 'resource.limit'
    status = 'working'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'red'
    msg = project + '  \u2014  Context compacting'
elif event == 'SessionEnd':
    # Clean up state for this session
    for key in ('session_packs', 'prompt_timestamps', 'session_start_times', 'prompt_start_times', 'subagent_sessions'):
        d = state.get(key, {})
        if session_id in d:
            del d[session_id]
            state[key] = d
    agent_sessions.discard(session_id)
    state['agent_sessions'] = list(agent_sessions)
    state_dirty = True
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    json.dump(state, open(state_file, 'w'))
    print('PEON_EXIT=true')
    sys.exit(0)
else:
    # Unknown event — exit cleanly
    print('PEON_EXIT=true')
    sys.exit(0)

# --- Debounce rapid Stop events (e.g. background task completions) ---
if event == 'Stop':
    now = time.time()
    last_stop = state.get('last_stop_time', 0)
    if now - last_stop < 5:
        category = ''
        notify = ''
    state['last_stop_time'] = now
    state_dirty = True

# --- Suppress sounds during session replay (claude -c) ---
# When continuing a session, Claude fires SessionStart then immediately replays
# old events. Suppress all sounds within 3s of SessionStart for the same session.
now = time.time()
if event == 'SessionStart':
    session_starts = state.get('session_start_times', {})
    session_starts[session_id] = now
    state['session_start_times'] = session_starts
    state_dirty = True
elif category:
    session_starts = state.get('session_start_times', {})
    start_time = session_starts.get(session_id, 0)
    if start_time and (now - start_time) < 3:
        category = ''
        notify = ''

# --- Check if category is enabled ---
if category and not cat_enabled.get(category, True):
    category = ''

# --- Pick sound (skip if no category or paused) ---
sound_file = ''
icon_path = ''
if category and not paused:
    pack_dir = os.path.join(peon_dir, 'packs', active_pack)
    try:
        manifest = None
        for mname in ('openpeon.json', 'manifest.json'):
            mpath = os.path.join(pack_dir, mname)
            if os.path.exists(mpath):
                manifest = json.load(open(mpath))
                break
        if not manifest:
            manifest = {}
        sounds = manifest.get('categories', {}).get(category, {}).get('sounds', [])
        if sounds:
            last_played = state.get('last_played', {})
            last_file = last_played.get(category, '')
            candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s['file'] != last_file]
            pick = random.choice(candidates)
            last_played[category] = pick['file']
            state['last_played'] = last_played
            state_dirty = True
            file_ref = str(pick.get('file', ''))
            if '/' in file_ref:
                candidate = os.path.realpath(os.path.join(pack_dir, file_ref))
            else:
                candidate = os.path.realpath(os.path.join(pack_dir, 'sounds', file_ref))
            pack_root = os.path.realpath(pack_dir) + os.sep
            if candidate.startswith(pack_root):
                sound_file = candidate
            # Icon resolution chain (CESP §5.5)
            icon_candidate = ''
            if pick.get('icon'):
                icon_candidate = str(pick['icon'])
            elif manifest.get('categories', {}).get(category, {}).get('icon'):
                icon_candidate = str(manifest['categories'][category]['icon'])
            elif manifest.get('icon'):
                icon_candidate = str(manifest['icon'])
            elif os.path.isfile(os.path.join(pack_dir, 'icon.png')):
                icon_candidate = 'icon.png'
            if icon_candidate:
                icon_resolved = os.path.realpath(os.path.join(pack_dir, icon_candidate))
                if icon_resolved.startswith(pack_root) and os.path.isfile(icon_resolved):
                    icon_path = icon_resolved
    except Exception:
        pass

# --- Trainer reminder check ---
trainer_sound = ''
trainer_msg = ''
trainer_cfg = cfg.get('trainer', {})
if trainer_cfg.get('enabled', False):
    from datetime import date as _date
    today = _date.today().isoformat()
    trainer_state = state.get('trainer', {})
    _default_ex = dict(pushups=300, squats=300)
    if trainer_state.get('date') != today:
        exercises = trainer_cfg.get('exercises', _default_ex)
        trainer_state = dict(date=today, reps=dict.fromkeys(exercises, 0), last_reminder_ts=0)
    exercises = trainer_cfg.get('exercises', _default_ex)
    reps = trainer_state.get('reps', {})
    all_done = all(reps.get(ex, 0) >= goal for ex, goal in exercises.items())
    if not all_done:
        now_ts = time.time()
        last_ts = trainer_state.get('last_reminder_ts', 0)
        interval = trainer_cfg.get('reminder_interval_minutes', 20) * 60
        min_gap = trainer_cfg.get('reminder_min_gap_minutes', 5) * 60
        elapsed = now_ts - last_ts
        is_session_start = (event == 'SessionStart')
        if is_session_start or (elapsed >= interval and elapsed >= min_gap):
            trainer_manifest_path = os.path.join(peon_dir, 'trainer', 'manifest.json')
            try:
                tm = json.load(open(trainer_manifest_path))
                if is_session_start:
                    tcat = 'trainer.session_start'
                else:
                    import datetime
                    hour = datetime.datetime.now().hour
                    total_reps = sum(reps.get(ex, 0) for ex in exercises)
                    total_goal = sum(exercises.values())
                    pct = total_reps / total_goal if total_goal > 0 else 1.0
                    if hour >= 12 and pct < 0.25:
                        tcat = 'trainer.slacking'
                    else:
                        tcat = 'trainer.remind'
                sounds = tm.get(tcat, [])
                if sounds:
                    pick = random.choice(sounds)
                    sfile = os.path.join(peon_dir, 'trainer', pick['file'])
                    if os.path.isfile(sfile):
                        trainer_sound = sfile
                        parts = []
                        for ex, goal in exercises.items():
                            done = reps.get(ex, 0)
                            parts.append(f'{ex}: {done}/{goal}')
                        trainer_msg = ' | '.join(parts)
            except Exception:
                pass
            trainer_state['last_reminder_ts'] = int(now_ts)
            state_dirty = True
    state['trainer'] = trainer_state
    state_dirty = True

# --- Write state once ---
if state_dirty:
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    json.dump(state, open(state_file, 'w'))

# --- iTerm2 tab color mapping ---
# Configurable via config.json: tab_color.enabled (default true),
# tab_color.colors.(ready|working|done|needs_approval) as [r,g,b] arrays.
tab_color_rgb = ''
if tab_color_enabled:
    default_colors = {
        'ready':          [65, 115, 80],   # muted green
        'working':        [130, 105, 50],  # muted amber
        'done':           [65, 100, 140],  # muted blue
        'needs_approval': [150, 70, 70],   # muted red
    }
    custom = tab_color_cfg.get('colors', {})
    color_profiles = tab_color_cfg.get('color_profiles', {})
    if project in color_profiles and isinstance(color_profiles[project], dict):
        custom = dict(custom, **color_profiles[project])
    colors = dict((k, custom.get(k, v)) for k, v in default_colors.items())
    status_key = status.replace(' ', '_') if status else ''
    if status_key in colors:
        rgb = colors[status_key]
        tab_color_rgb = f'{rgb[0]} {rgb[1]} {rgb[2]}'

# --- Output shell variables ---
print('PEON_EXIT=false')
print('EVENT=' + q(event))
print('VOLUME=' + q(str(volume)))
print('PROJECT=' + q(project))
print('STATUS=' + q(status))
print('MARKER=' + q(marker))
print('NOTIFY=' + q(notify))
print('NOTIFY_COLOR=' + q(notify_color))
print('MSG=' + q(msg))
print('MSG_SUBTITLE=' + q(msg_subtitle))
print('DESKTOP_NOTIF=' + ('true' if desktop_notif else 'false'))
print('NOTIF_STYLE=' + q(cfg.get('notification_style', 'overlay')))
print('USE_SOUND_EFFECTS_DEVICE=' + q(str(use_sound_effects_device).lower()))
print('LINUX_AUDIO_PLAYER=' + q(linux_audio_player))
mn = cfg.get('mobile_notify', {})
mobile_on = bool(mn and mn.get('service') and mn.get('enabled', True))
print('MOBILE_NOTIF=' + ('true' if mobile_on else 'false'))
print('SOUND_FILE=' + q(sound_file))
print('ICON_PATH=' + q(icon_path))
print('TRAINER_SOUND=' + q(trainer_sound))
print('TRAINER_MSG=' + q(trainer_msg))
print('TAB_COLOR_RGB=' + q(tab_color_rgb))
" <<< "$INPUT" 2>/dev/null)"

# If Python signalled early exit (disabled, agent, unknown event), bail out
[ "${PEON_EXIT:-true}" = "true" ] && exit 0

# --- Check for updates (SessionStart only, once per day, non-blocking) ---
if [ "$EVENT" = "SessionStart" ]; then
  (
    CHECK_FILE="$PEON_DIR/.last_update_check"
    NOW=$(date +%s)
    LAST_CHECK=0
    [ -f "$CHECK_FILE" ] && LAST_CHECK=$(cat "$CHECK_FILE" 2>/dev/null || echo 0)
    ELAPSED=$((NOW - LAST_CHECK))
    # Only check once per day (86400 seconds)
    if [ "$ELAPSED" -gt 86400 ]; then
      echo "$NOW" > "$CHECK_FILE"
      LOCAL_VERSION=""
      [ -f "$PEON_DIR/VERSION" ] && LOCAL_VERSION=$(cat "$PEON_DIR/VERSION" | tr -d '[:space:]')
      REMOTE_VERSION=$(curl -fsSL --connect-timeout 3 --max-time 5 \
        "https://raw.githubusercontent.com/PeonPing/peon-ping/main/VERSION" 2>/dev/null | tr -d '[:space:]')
      if [ -n "$REMOTE_VERSION" ] && [ -n "$LOCAL_VERSION" ] && [ "$REMOTE_VERSION" != "$LOCAL_VERSION" ]; then
        # Write update notice to a file so we can display it
        echo "$REMOTE_VERSION" > "$PEON_DIR/.update_available"
      else
        rm -f "$PEON_DIR/.update_available"
      fi
    fi
  ) &>/dev/null &
fi

# --- Show update notice (if available, on SessionStart only) ---
if [ "$EVENT" = "SessionStart" ] && [ -f "$PEON_DIR/.update_available" ]; then
  NEW_VER=$(cat "$PEON_DIR/.update_available" 2>/dev/null | tr -d '[:space:]')
  CUR_VER=""
  [ -f "$PEON_DIR/VERSION" ] && CUR_VER=$(cat "$PEON_DIR/VERSION" | tr -d '[:space:]')
  if [ -n "$NEW_VER" ]; then
    echo "peon-ping update available: ${CUR_VER:-?} → $NEW_VER — run: curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash" >&2
  fi
fi

# --- Show pause status on SessionStart ---
if [ "$EVENT" = "SessionStart" ] && [ "$PAUSED" = "true" ]; then
  echo "peon-ping: sounds paused — run 'peon resume' or '/peon-ping-toggle' to unpause" >&2
fi

# --- Relay guidance on SessionStart (devcontainer/SSH) ---
# Backgrounded in production to avoid blocking the greeting sound while curl times out.
_relay_guidance() {
  if [ "$PLATFORM" = "devcontainer" ]; then
    RELAY_HOST="${PEON_RELAY_HOST:-host.docker.internal}"
    RELAY_PORT="${PEON_RELAY_PORT:-19998}"
    if ! curl -sf --connect-timeout 1 --max-time 2 "http://${RELAY_HOST}:${RELAY_PORT}/health" >/dev/null 2>&1; then
      echo "peon-ping: devcontainer detected but audio relay not reachable at ${RELAY_HOST}:${RELAY_PORT}" >&2
      echo "peon-ping: run 'peon relay' on your host machine to enable sounds" >&2
    fi
  elif [ "$PLATFORM" = "ssh" ]; then
    RELAY_HOST="${PEON_RELAY_HOST:-localhost}"
    RELAY_PORT="${PEON_RELAY_PORT:-19998}"
    if ! curl -sf --connect-timeout 1 --max-time 2 "http://${RELAY_HOST}:${RELAY_PORT}/health" >/dev/null 2>&1; then
      echo "peon-ping: SSH session detected but audio relay not reachable at ${RELAY_HOST}:${RELAY_PORT}" >&2
      echo "peon-ping: on your LOCAL machine, run: peon relay" >&2
      echo "peon-ping: then reconnect with: ssh -R 19998:localhost:19998 <host>" >&2
    fi
  fi
}
if [ "$EVENT" = "SessionStart" ] && { [ "$PLATFORM" = "devcontainer" ] || [ "$PLATFORM" = "ssh" ]; }; then
  if [ "${PEON_TEST:-0}" = "1" ]; then
    _relay_guidance
  else
    _relay_guidance &
  fi
fi

# --- Build tab title ---
TITLE="${MARKER}${PROJECT}: ${STATUS}"

# --- Set tab title via ANSI escape (works in Warp, iTerm2, Terminal.app, etc.) ---
# Write to /dev/tty so the escape sequence reaches the terminal directly.
# Claude Code captures hook stdout, so plain printf would be swallowed.
if [ -n "$TITLE" ]; then
  printf '\033]0;%s\007' "$TITLE" > /dev/tty 2>/dev/null || true
fi

# --- Set iTerm2 tab color (OSC 6) ---
# Uses /dev/tty for the same reason as tab title above.
# In test mode, write resolved color to file for BATS verification.
[ "${PEON_TEST:-0}" = "1" ] && [ -n "$TAB_COLOR_RGB" ] && echo "$TAB_COLOR_RGB" > "$PEON_DIR/.tab_color_rgb"
[ "${PEON_TEST:-0}" = "1" ] && [ -n "$ICON_PATH" ] && echo "$ICON_PATH" > "$PEON_DIR/.icon_path"
if [ -n "$TAB_COLOR_RGB" ] && [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
  read -r _R _G _B <<< "$TAB_COLOR_RGB"
  printf "\033]6;1;bg;red;brightness;%d\a" "$_R" > /dev/tty 2>/dev/null || true
  printf "\033]6;1;bg;green;brightness;%d\a" "$_G" > /dev/tty 2>/dev/null || true
  printf "\033]6;1;bg;blue;brightness;%d\a" "$_B" > /dev/tty 2>/dev/null || true
fi

_run_sound_and_notify() {
  # --- Play sound ---
  if [ -n "$SOUND_FILE" ] && [ -f "$SOUND_FILE" ]; then
    play_sound "$SOUND_FILE" "$VOLUME"
  fi

  # --- Smart notification: only when terminal is NOT frontmost ---
  if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ] && [ "${DESKTOP_NOTIF:-true}" = "true" ]; then
    if ! terminal_is_focused; then
      send_notification "$MSG" "$TITLE" "${NOTIFY_COLOR:-red}" "${ICON_PATH:-}"
    fi
  fi

  # --- Mobile push notification (always sends when configured, regardless of focus) ---
  if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ] && [ "${MOBILE_NOTIF:-false}" = "true" ]; then
    send_mobile_notification "$MSG" "$TITLE" "${NOTIFY_COLOR:-red}"
  fi
}

# In test mode run synchronously; in production background to avoid blocking the IDE
if [ "${PEON_TEST:-0}" = "1" ]; then
  _run_sound_and_notify
else
  _run_sound_and_notify & disown
fi

# --- Trainer reminder sound (after main sound finishes) ---
if [ -n "${TRAINER_SOUND:-}" ] && [ -f "$TRAINER_SOUND" ]; then
  if [ "${PEON_TEST:-0}" = "1" ]; then
    play_sound "$TRAINER_SOUND" "$VOLUME"
  else
    (
      # Wait for the main pack sound to finish before playing trainer sound
      _pidfile="$PEON_DIR/.sound.pid"
      if [ -f "$_pidfile" ]; then
        _main_pid=$(cat "$_pidfile" 2>/dev/null)
        if [ -n "$_main_pid" ] && kill -0 "$_main_pid" 2>/dev/null; then
          # Wait up to 10s for main sound to finish
          _waited=0
          while kill -0 "$_main_pid" 2>/dev/null && [ "$_waited" -lt 100 ]; do
            sleep 0.1
            _waited=$((_waited + 1))
          done
        fi
      fi
      # Brief pause after main sound ends for natural spacing
      sleep 0.5
      play_sound "$TRAINER_SOUND" "$VOLUME"
      if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ] && [ "${DESKTOP_NOTIF:-true}" = "true" ]; then
        if ! terminal_is_focused; then
          send_notification "Peon Trainer" "${TRAINER_MSG:-Time for reps!}" "blue"
        fi
      fi
    ) & disown 2>/dev/null
  fi
fi

exit 0
