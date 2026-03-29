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

# Detect if headphones/external audio is connected
# Returns 0 (true) if headphones detected, 1 (false) if built-in speakers only
detect_headphones() {
  case "$PLATFORM" in
    mac)
      local output default_section
      output=$(system_profiler SPAudioDataType 2>/dev/null) || return 0
      # Get the device section containing "Default Output Device: Yes" (10 lines before, 5 after)
      default_section=$(echo "$output" | grep -B10 -A5 "Default Output Device: Yes" | tr '[:upper:]' '[:lower:]')
      # Check if this section has built-in transport AND speaker in the name
      if echo "$default_section" | grep -q "transport: built-in" && echo "$default_section" | grep -q "speaker"; then
        return 1  # Built-in speakers, no headphones
      fi
      return 0  # Default: assume headphones
      ;;
    linux)
      local out
      if command -v wpctl &>/dev/null; then
        out=$(wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | tr '[:upper:]' '[:lower:]') || return 0
        if [[ "$out" == *"speaker"* && "$out" != *"headphone"* ]]; then
          return 1
        fi
      elif command -v pactl &>/dev/null; then
        out=$(pactl list sinks 2>/dev/null | tr '[:upper:]' '[:lower:]') || return 0
        if [[ "$out" == *"analog-output-speaker"* && "$out" != *"headphone"* ]]; then
          return 1
        fi
      fi
      return 0
      ;;
    wsl)
      local out
      out=$(powershell.exe -NoProfile -Command 'Get-PnpDevice -Class AudioEndpoint -Status OK -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FriendlyName' 2>/dev/null | tr '[:upper:]' '[:lower:]') || return 0
      local has_speakers=false has_headphones=false
      [[ "$out" == *"speaker"* ]] && has_speakers=true
      [[ "$out" == *"headphone"* || "$out" == *"headset"* || "$out" == *"airpod"* || "$out" == *"buds"* || "$out" == *"earphone"* ]] && has_headphones=true
      if [[ "$has_speakers" == true && "$has_headphones" == false ]]; then
        return 1
      fi
      return 0
      ;;
    *)
      return 0  # Other platforms: assume headphones/allow sound
      ;;
  esac
}

# Detect if user is in an active meeting/call
# Returns 0 (true) if meeting detected, 1 (false) if not
detect_meeting() {
  case "$PLATFORM" in
    mac)
      # Check if any microphone is in use (CoreAudio)
      local _meeting_detect
      _meeting_detect="$(find_bundled_script "meeting-detect")" || true
      if [ -n "$_meeting_detect" ] && [ -x "$_meeting_detect" ]; then
        local mic_status
        mic_status=$("$_meeting_detect" 2>/dev/null) || true
        [ "$mic_status" = "MIC_IN_USE" ] && return 0
      fi
      return 1
      ;;
    linux)
      # Check mic via PipeWire/PulseAudio
      if command -v wpctl &>/dev/null; then
        local sources
        sources=$(wpctl status 2>/dev/null | grep -A50 "Audio/Source" | grep "RUNNING") || true
        [ -n "$sources" ] && return 0
      elif command -v pactl &>/dev/null; then
        # pactl: any source-output that isn't a peak detector means mic is in use
        local total peak
        total=$(pactl list source-outputs 2>/dev/null | grep -c 'Source Output #') || true
        peak=$(pactl list source-outputs 2>/dev/null | grep -c 'media\.name = "Peak detect"') || true
        [ "${total:-0}" -gt "${peak:-0}" ] && return 0
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

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
# Also set PYTHONUTF8=1 to avoid cp932/cp1252 codec errors when settings.json contains Unicode
if [ "$PLATFORM" = "msys2" ]; then
  export PYTHONUTF8=1
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

# --- Export paths for Python blocks (avoids shell→Python string injection) ---
export PEON_ENV_CONFIG="$CONFIG_PY"
export PEON_ENV_GLOBAL_CONFIG="$GLOBAL_CONFIG_PY"
export PEON_ENV_STATE="$STATE_PY"
export PEON_ENV_PEON_DIR="$PEON_DIR_PY"
export PEON_ENV_PLATFORM="$PLATFORM"

# --- Shared Python state I/O helpers (DRY: single definition used by all inline Python blocks) ---
# Included via ${_PEON_STATE_PY_HELPERS} in python3 -c strings.
# Requires: import json, os, time, tempfile (caller must import these before expanding).
read -r -d '' _PEON_STATE_PY_HELPERS <<'PYHELPERS' || true
def _write_state(st, path, indent=None):
    """Atomically write state dict to path via temp+rename."""
    d = os.path.dirname(path) or '.'
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(st, f, indent=indent)
        os.replace(tmp, path)
    except Exception:
        try: os.unlink(tmp)
        except OSError: pass
        raise

def _read_state(path):
    """Read state dict from path with retry on transient I/O failures.
    Short-circuits on FileNotFoundError (first run) to avoid 350ms retry delay."""
    if not os.path.exists(path):
        return {}
    delays = [0.05, 0.1, 0.2]
    for attempt in range(len(delays) + 1):
        try:
            with open(path) as f:
                return json.load(f)
        except FileNotFoundError:
            return {}
        except (json.JSONDecodeError, OSError):
            if attempt < len(delays):
                time.sleep(delays[attempt])
    return {}

# Aliases used by the main hook Python block (public API names)
write_state = _write_state
read_state = _read_state
PYHELPERS

# --- Safe eval: only allow lines matching VAR=value (defense-in-depth for Python output) ---
safe_eval_python() {
  local output="$1"
  [ -z "$output" ] && return 0
  # Reject any line that doesn't look like a shell variable assignment
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      return 1
    fi
  done <<< "$output"
  eval "$output"
}

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
      pa_vol=$(PEON_ENV_VOL="$vol" python3 -c "import os; v=float(os.environ.get('PEON_ENV_VOL','0.5')); print(max(0, min(65536, int(v * 65536))))")
      if [ "$use_bg" = true ]; then
        nohup paplay --volume="$pa_vol" "$file" >/dev/null 2>&1 &
      else
        paplay --volume="$pa_vol" "$file" >/dev/null 2>&1
      fi
      ;;
    ffplay)
      local ff_vol
      ff_vol=$(PEON_ENV_VOL="$vol" python3 -c "import os; v=float(os.environ.get('PEON_ENV_VOL','0.5')); print(max(0, min(100, int(v * 100))))")
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
      if [[ "$file" != *.wav ]]; then
        # aplay only supports WAV (and raw). If we try to play mp3/ogg, it will likely fail or play static.
        if [ -z "${WARNED_APLAY_FORMAT:-}" ]; then
          echo "Warning: aplay can only play WAV files, but '$file' is not a WAV. Install pw-play, paplay, ffplay, mpv, or play (SoX) for better support." >&2
          WARNED_APLAY_FORMAT=1
        fi
        return 0
      fi
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

# SSH audio routing mode.
# relay (default): current behavior, require relay endpoint.
# auto: try relay first, fallback to local host playback.
# local: always use local host playback.
ssh_audio_mode() {
  local mode="${PEON_SSH_AUDIO_MODE:-relay}"
  case "$mode" in
    relay|auto|local) ;;
    *) mode="relay" ;;
  esac
  echo "$mode"
}

# --- Platform-aware audio playback ---
play_sound() {
  local file="$1" vol="$2"
  _peon_log play "backend=$PLATFORM file=$(basename "$file") volume=$vol async=true"
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
      local safe_tmpdir="${tmpdir//\'/\'\'}"
      setsid powershell.exe -NoProfile -NonInteractive -Command "
        (New-Object Media.SoundPlayer '${safe_tmpdir}peon-ping-sound.wav').PlaySync()
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

      local ssh_mode="relay"
      [ "$PLATFORM" = "ssh" ] && ssh_mode="$(ssh_audio_mode)"

      # SSH local mode bypasses relay and plays on the SSH host.
      if [ "$PLATFORM" = "ssh" ] && [ "$ssh_mode" = "local" ]; then
        local player
        player=$(detect_linux_player "${LINUX_AUDIO_PLAYER:-}") || player=""
        if [ -n "$player" ]; then
          play_linux_sound "$file" "$vol" "$player"
          save_sound_pid $!
        fi
      # SSH auto mode tries relay first, then falls back to local playback.
      elif [ "$PLATFORM" = "ssh" ] && [ "$ssh_mode" = "auto" ]; then
        if curl -sf --connect-timeout 1 --max-time 2 -H "X-Volume: $vol" \
          "http://${relay_host}:${relay_port}/play?file=${encoded_path}" >/dev/null 2>&1; then
          :
        else
          local player
          player=$(detect_linux_player "${LINUX_AUDIO_PLAYER:-}") || player=""
          if [ -n "$player" ]; then
            play_linux_sound "$file" "$vol" "$player"
            save_sound_pid $!
          fi
        fi
      else
        if [ "${PEON_TEST:-0}" = "1" ]; then
          curl -sf -H "X-Volume: $vol" \
            "http://${relay_host}:${relay_port}/play?file=${encoded_path}" 2>/dev/null
        else
          nohup curl -sf -H "X-Volume: $vol" \
            "http://${relay_host}:${relay_port}/play?file=${encoded_path}" >/dev/null 2>&1 &
          save_sound_pid $!
        fi
      fi
      ;;
    linux)
      local player
      player=$(detect_linux_player "${LINUX_AUDIO_PLAYER:-}") || player=""
      if [ -n "$player" ]; then
        play_linux_sound "$file" "$vol" "$player"
        save_sound_pid $!
      else
        _peon_log play "error=\"no audio backend found\" searched=\"pw-play,paplay,ffplay,mpv,play,aplay\""
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
    WezTerm)        echo "com.github.wez.wezterm" ;;
    vscode)
      # IDE embedded terminal (Cursor, VS Code, Windsurf all set TERM_PROGRAM=vscode).
      # Async hooks are orphaned from the process tree, so _mac_ide_pid() won't find
      # the IDE. Instead, check which IDE is actually running and return its bundle ID.
      local _bid
      for _candidate in Cursor "Code" Windsurf; do
        _bid=$(osascript -e "tell application \"System Events\" to get bundle identifier of first process whose name is \"$_candidate\"" 2>/dev/null) && [ -n "$_bid" ] && { echo "$_bid"; return; }
      done
      echo "" ;;
    *)
      # Fallback: detect terminal via env vars that survive tmux/screen
      if [ -n "${GHOSTTY_RESOURCES_DIR:-}" ]; then
        echo "com.mitchellh.ghostty"
      elif [ -n "${ITERM_SESSION_ID:-}" ]; then
        echo "com.googlecode.iterm2"
      elif [ -n "${WARP_IS_LOCAL_SHELL_SESSION:-}" ]; then
        echo "dev.warp.Warp-Stable"
      else
        echo ""
      fi ;;
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

# --- Resolve session TTY (for iTerm2 tab-level focus detection) ---
# Walks the process tree to find an ancestor with a real tty, then exports
# PEON_SESSION_TTY. No-ops if already resolved.
_resolve_session_tty() {
  [ -n "${PEON_SESSION_TTY:-}" ] && return 0
  if [ -n "${TMUX:-}" ]; then
    PEON_SESSION_TTY=$(tmux display-message -p '#{client_tty}' 2>/dev/null || true)
  else
    # Walk the full process tree; keep the LAST (highest ancestor) tty found.
    # Claude Code spawns hooks from worker processes that may have their own
    # ptys, so the first tty in the tree is often a worker pty, not the
    # terminal tty. The highest ancestor with a tty is the terminal session.
    local walk_pid="$PPID" last_tty=""
    while [ "$walk_pid" -gt 1 ] 2>/dev/null; do
      local walk_tty
      walk_tty=$(ps -p "$walk_pid" -o tty= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
      if [ -n "$walk_tty" ] && [ "$walk_tty" != "??" ]; then
        last_tty="/dev/$walk_tty"
      fi
      walk_pid=$(ps -p "$walk_pid" -o ppid= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
    done
    PEON_SESSION_TTY="$last_tty"
  fi
  export PEON_SESSION_TTY
}

# --- Ghostty active terminal match (best-effort) ---
# Ghostty exposes focused terminal metadata via AppleScript. We use it to avoid
# suppressing notifications for every Ghostty window/tab just because the app is
# frontmost. Title match is strongest; cwd is a fallback heuristic.
_ghostty_terminal_is_current() {
  local active_info active_name active_cwd
  active_info=$(osascript -e 'tell application "Ghostty"
    try
      set win to front window
      set tab_ to selected tab of win
      set term to focused terminal of tab_
      return (name of term) & "	" & (working directory of term)
    on error
      return ""
    end try
  end tell' 2>/dev/null || true)
  [ -z "$active_info" ] && return 0

  active_name=${active_info%%$'	'*}
  active_cwd=${active_info#*$'	'}
  active_name=$(printf '%s' "$active_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  active_cwd=$(printf '%s' "$active_cwd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  [ -n "${TITLE:-}" ] && [ "$active_name" = "$TITLE" ] && return 0
  [ -n "${PROJECT:-}" ] && [ "$active_name" = "$PROJECT" ] && return 0
  [ -n "${CWD:-}" ] && [ "$active_cwd" = "$CWD" ] && return 0

  return 1
}

# --- Platform-aware notification ---
# Args: msg, title, color (red/blue/yellow)
send_notification() {
  local msg="$1" title="$2" color="${3:-red}"
  local icon_path="${4:-}"

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
      export PEON_NOTIF_POSITION="${NOTIF_POSITION:-top-center}"
      export PEON_NOTIF_DISMISS="${NOTIF_DISMISS:-4}"
      export PEON_NOTIF_ALL_SCREENS="${NOTIF_ALL_SCREENS:-true}"
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
        # Resolve session TTY for iTerm2 tab/window focus
        _resolve_session_tty
      fi
      export PEON_MSG_SUBTITLE="${MSG_SUBTITLE:-}"
      export PEON_NOTIFY_TYPE="${NOTIFY_TYPE:-}"
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
          # iTerm2 is frontmost, but check if OUR tab/pane is active.
          # Scan ALL windows (not just "current window") because users may
          # have multiple iTerm2 windows; try/catch handles special windows
          # (hotkey windows, etc.) that have no tabs.
          local my_tty="${PEON_SESSION_TTY:-}"
          if [ -z "$my_tty" ]; then
            return 0  # No TTY info, assume focused
          fi
          local active_ttys
          active_ttys=$(osascript -e 'tell application "iTerm2"
            set ttys to {}
            repeat with w in windows
              try
                set end of ttys to tty of current session of current tab of w
              end try
            end repeat
            return ttys
          end tell' 2>/dev/null || true)
          local IFS=','
          for _t in $active_ttys; do
            _t="${_t## }"  # trim leading space from AppleScript list format
            [ "$_t" = "$my_tty" ] && return 0
          done
          return 1  # Different tab/pane is active in all windows — notify
          ;;
        Ghostty|ghostty) _ghostty_terminal_is_current ; return $? ;;
        Terminal|Warp|Alacritty|kitty|WezTerm) return 0 ;;
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
  export PEON_ENV_CONFIG_RO="$config"
  mobile_vars=$(python3 -c "
import json, sys, shlex, os
q = shlex.quote
try:
    cfg = json.load(open(os.environ.get('PEON_ENV_CONFIG_RO', '')))
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

  safe_eval_python "$mobile_vars" || return 0

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
    export PEON_ENV_SYNC_SRC="$CONFIG_PY" PEON_ENV_SYNC_DST="$_target"
    python3 -c "
import json, sys, os

src_path = os.environ.get('PEON_ENV_SYNC_SRC', '')
dst_path = os.environ.get('PEON_ENV_SYNC_DST', '')

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

LOG_DIR="$PEON_DIR/logs"

# Prune log files older than debug_retention_days.
# Uses filename-based date parsing (peon-ping-YYYY-MM-DD.log) for cross-platform consistency.
_prune_old_logs() {
  local retention_days="${1:-7}"
  [ ! -d "$LOG_DIR" ] && return 0
  local today_epoch
  today_epoch=$(date +%s)
  local cutoff_epoch=$(( today_epoch - retention_days * 86400 ))
  for logfile in "$LOG_DIR"/peon-ping-*.log; do
    [ -f "$logfile" ] || continue
    local basename="${logfile##*/}"
    # Extract YYYY-MM-DD from peon-ping-YYYY-MM-DD.log
    local date_part="${basename#peon-ping-}"
    date_part="${date_part%.log}"
    # Validate date format (YYYY-MM-DD)
    case "$date_part" in
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;;
      *) continue ;;
    esac
    # Parse date to epoch (portable: use date -d on Linux, date -j on macOS)
    local file_epoch
    if date -d "$date_part" +%s >/dev/null 2>&1; then
      file_epoch=$(date -d "$date_part" +%s 2>/dev/null) || continue
    elif date -j -f "%Y-%m-%d" "$date_part" +%s >/dev/null 2>&1; then
      file_epoch=$(date -j -f "%Y-%m-%d" "$date_part" +%s 2>/dev/null) || continue
    else
      continue
    fi
    if [ "$file_epoch" -lt "$cutoff_epoch" ]; then
      rm -f "$logfile"
    fi
  done
}

case "${1:-}" in
  pause|mute)   touch "$PAUSED_FILE"; sync_adapter_paused; echo "peon-ping: sounds paused (run 'peon toggle' to unpause)"; exit 0 ;;
  resume|unmute)  rm -f "$PAUSED_FILE"; sync_adapter_paused; echo "peon-ping: sounds resumed"; exit 0 ;;
  toggle)
    if [ -f "$PAUSED_FILE" ]; then rm -f "$PAUSED_FILE"; echo "peon-ping: sounds resumed"
    else touch "$PAUSED_FILE"; echo "peon-ping: sounds paused (run 'peon toggle' to unpause)"; fi
    sync_adapter_paused; exit 0 ;;
  status)
    [ -f "$PAUSED_FILE" ] && echo "peon-ping: paused" || echo "peon-ping: active"
    # Run headphone detection in bash before Python
    _headphones_detected=true
    detect_headphones || _headphones_detected=false
    _verbose_flag="${2:-}"
    python3 -c "
import json, os, sys

config_path = os.environ.get('PEON_ENV_CONFIG', '')
peon_dir = os.environ.get('PEON_ENV_PEON_DIR', '')
headphones_detected = '$_headphones_detected' == 'true'
verbose = '$_verbose_flag' == '--verbose'

# --- Config ---
try:
    c = json.load(open(config_path))
except Exception:
    c = {}

if verbose:
    dn = c.get('desktop_notifications', True)
    dn_status = 'on' if dn else 'off (sounds still play)'
    print('peon-ping: desktop notifications ' + dn_status)
    ns = c.get('notification_style', 'overlay')
    print('peon-ping: notification style ' + ns)
    np = c.get('notification_position', 'top-center')
    print('peon-ping: notification position ' + np)
    nd = c.get('notification_dismiss_seconds', 4)
    print('peon-ping: dismiss time ' + (str(nd) + 's' if nd > 0 else 'persistent (click to dismiss)'))
    _lbl = c.get('notification_title_override', '')
    _pmap = c.get('project_name_map', {})
    if _lbl:
        print('peon-ping: label override: ' + _lbl)
    if _pmap:
        print('peon-ping: project name map: ' + str(len(_pmap)) + ' pattern(s)')
    _tpls = c.get('notification_templates', {})
    if _tpls:
        print('peon-ping: notification templates:')
        for _tk, _tv in _tpls.items():
            print(f'  {_tk} = "{_tv}"')

    mn = c.get('mobile_notify', {})
    if mn and mn.get('service'):
        enabled = mn.get('enabled', True)
        svc = mn.get('service', '?')
        mobile_status = 'on' if enabled else 'off'
        print(f'peon-ping: mobile notifications {mobile_status} ({svc})')
    else:
        print('peon-ping: mobile notifications not configured')

    # --- Headphones-only mode ---
    headphones_only = c.get('headphones_only', False)
    print('peon-ping: headphones_only: ' + ('on' if headphones_only else 'off'))
    status_str = 'connected' if headphones_detected else 'not detected'
    if headphones_only and not headphones_detected:
        status_str += ' (sounds muted)'
    print('peon-ping: headphones: ' + status_str)

# --- Debug logging ---
_debug = c.get('debug', False)
_debug_status = 'enabled' if _debug else 'disabled'
_log_dir = os.path.join(peon_dir, 'logs')
print('peon-ping: debug logging: ' + _debug_status)
if verbose:
    print('  log dir: ' + _log_dir + '/')
    _retention = c.get('debug_retention_days', 7)
    print('  retention: ' + str(_retention) + ' days')

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
if not verbose:
    print('peon-ping: run \"peon status --verbose\" for full details')
if verbose:
    rules = c.get('path_rules', [])
    if rules:
        import fnmatch as _fnm
        _cwd = os.getcwd()
        _matched = None
        for _r in rules:
            _pat = _r.get('pattern', '')
            if _cwd and _fnm.fnmatch(_cwd, _pat):
                _matched = _r
                break
        if _matched:
            _mp = _matched.get('pattern', '')
            _mk = _matched.get('pack', '')
            print(f'peon-ping: path rule: {_mp} -> {_mk}')
        print(f'peon-ping: path rules: {len(rules)} configured')

if verbose:
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

    # Rovo Dev CLI: check if hooks are registered in config.yml
    rovodev_dir = os.path.join(home, '.rovodev')
    rovodev_config = os.path.join(rovodev_dir, 'config.yml')
    rovodev_config_yaml = os.path.join(rovodev_dir, 'config.yaml')
    if os.path.isdir(rovodev_dir):
        config_file = rovodev_config if os.path.isfile(rovodev_config) else rovodev_config_yaml if os.path.isfile(rovodev_config_yaml) else None
        if config_file:
            try:
                with open(config_file) as f:
                    content = f.read()
                if 'rovodev.sh' in content:
                    ides.append(('Rovo Dev CLI', rovodev_dir, 'installed'))
                else:
                    ides.append(('Rovo Dev CLI', rovodev_dir, 'detected (not set up)'))
            except Exception:
                ides.append(('Rovo Dev CLI', rovodev_dir, 'detected'))
        else:
            ides.append(('Rovo Dev CLI', rovodev_dir, 'detected (not set up)'))

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

    # OpenAI Codex: check if notify hook points to codex adapter
    codex_dir = os.environ.get('CODEX_HOME', os.path.join(home, '.codex'))
    codex_config = os.path.join(codex_dir, 'config.toml')
    if os.path.isdir(codex_dir):
        codex_installed = False
        if os.path.isfile(codex_config):
            try:
                codex_cfg_text = open(codex_config).read()
                codex_installed = (
                    'adapters/codex.sh' in codex_cfg_text or
                    'adapters/codex.ps1' in codex_cfg_text
                )
            except Exception:
                codex_installed = False
        if codex_installed:
            ides.append(('OpenAI Codex', codex_dir, 'installed'))
        else:
            ides.append(('OpenAI Codex', codex_dir, 'detected (not set up)'))

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
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
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
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
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
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
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
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['notification_style'] = 'standard'
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: notification style set to standard')
"
        sync_adapter_configs; exit 0 ;;
      position)
        POS_ARG="${3:-}"
        if [ -z "$POS_ARG" ]; then
          python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    print('peon-ping: notification position ' + cfg.get('notification_position', 'top-center'))
except Exception:
    print('peon-ping: notification position top-center')
"
          exit 0
        fi
        python3 -c "
import json, sys
config_path = '$CONFIG_PY'
pos = '$POS_ARG'
valid = ('top-center', 'top-right', 'top-left', 'bottom-right', 'bottom-left', 'bottom-center')
if pos not in valid:
    print(f'peon-ping: invalid position \"{pos}\" — use one of: ' + ', '.join(valid), file=sys.stderr)
    sys.exit(1)
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['notification_position'] = pos
json.dump(cfg, open(config_path, 'w'), indent=2)
print(f'peon-ping: notification position set to {pos}')
"
        _rc=$?; [ "$_rc" -ne 0 ] && exit "$_rc"
        sync_adapter_configs; exit 0 ;;
      dismiss)
        DISMISS_ARG="${3:-}"
        if [ -z "$DISMISS_ARG" ]; then
          python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    d = cfg.get('notification_dismiss_seconds', 4)
    if d <= 0:
        print('peon-ping: dismiss time persistent (click to dismiss)')
    else:
        print(f'peon-ping: dismiss time {d}s')
except Exception:
    print('peon-ping: dismiss time 4s')
"
          exit 0
        fi
        python3 -c "
import json, sys
config_path = '$CONFIG_PY'
try:
    secs = int('$DISMISS_ARG')
except ValueError:
    print('peon-ping: invalid dismiss time \"$DISMISS_ARG\" — use a number (0 = persistent)', file=sys.stderr)
    sys.exit(1)
if secs < 0:
    print('peon-ping: dismiss time cannot be negative', file=sys.stderr)
    sys.exit(1)
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['notification_dismiss_seconds'] = secs
json.dump(cfg, open(config_path, 'w'), indent=2)
if secs == 0:
    print('peon-ping: notifications set to persistent (click to dismiss)')
else:
    print(f'peon-ping: dismiss time set to {secs}s')
"
        _rc=$?; [ "$_rc" -ne 0 ] && exit "$_rc"
        sync_adapter_configs; exit 0 ;;
      label)
        LABEL_ARG="${3:-}"
        if [ -z "$LABEL_ARG" ]; then
          python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    lbl = cfg.get('notification_title_override', '')
    pmap = cfg.get('project_name_map', {})
    if lbl:
        print(f'peon-ping: label override: {lbl}')
    else:
        print('peon-ping: no label override set')
    if pmap:
        print(f'peon-ping: project name map ({len(pmap)} patterns):')
        for pat, name in pmap.items():
            print(f'  {pat} → {name}')
except Exception:
    print('peon-ping: no label override set')
"
          exit 0
        fi
        if [ "$LABEL_ARG" = "reset" ]; then
          python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['notification_title_override'] = ''
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: label override cleared')
"
          sync_adapter_configs; exit 0
        fi
        python3 -c "
import json, sys
config_path = '$CONFIG_PY'
label = sys.argv[1][:50]
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['notification_title_override'] = label
json.dump(cfg, open(config_path, 'w'), indent=2)
print(f'peon-ping: label override set to \"{label}\"')
" "$LABEL_ARG"
        _rc=$?; [ "$_rc" -ne 0 ] && exit "$_rc"
        sync_adapter_configs; exit 0 ;;
      test)
        # Read config to check if notifications are enabled and get style
        _py_out="$(python3 -c "
import json, shlex, os
q = shlex.quote
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
dn = cfg.get('desktop_notifications', True)
ns = cfg.get('notification_style', 'overlay')
np = cfg.get('notification_position', 'top-center')
nd = cfg.get('notification_dismiss_seconds', 4)
na = cfg.get('notification_all_screens', True)
print('_NOTIF_ENABLED=' + ('true' if dn else 'false'))
print('NOTIF_STYLE=' + q(ns))
print('NOTIF_POSITION=' + q(np))
print('NOTIF_DISMISS=' + q(str(nd)))
print('NOTIF_ALL_SCREENS=' + ('true' if na else 'false'))
")"
        safe_eval_python "$_py_out" || true
        if [ "$_NOTIF_ENABLED" != "true" ]; then
          echo "peon-ping: desktop notifications are off (run 'peon notifications on' to enable)" >&2
          exit 1
        fi
        echo "peon-ping: sending test notification (style: $NOTIF_STYLE)"
        PEON_TEST=1 send_notification "This is a test notification" "peon-ping" "blue"
        exit 0 ;;
      template)
        TPL_KEY="${3:-}"
        TPL_VAL="${4:-}"
        if [ -z "$TPL_KEY" ]; then
          # Show all templates
          python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG_PY'))
    tpls = cfg.get('notification_templates', {})
except Exception:
    tpls = {}
if not tpls:
    print('peon-ping: no notification templates configured (using defaults)')
else:
    valid = ('stop', 'permission', 'error', 'idle', 'question')
    for k in valid:
        v = tpls.get(k, '')
        if v:
            print(f'peon-ping: template {k} = \"{v}\"')
    extra = set(tpls) - set(valid)
    for k in sorted(extra):
        print(f'peon-ping: template {k} = \"{tpls[k]}\" (unknown key)')
"
          exit 0
        fi
        if [ "$TPL_KEY" = "--reset" ]; then
          python3 -c "
import json
config_path = '$CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg.pop('notification_templates', None)
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: notification templates cleared')
"
          sync_adapter_configs; exit 0
        fi
        # Validate key and set/show value
        python3 -c "
import json, sys
config_path = '$CONFIG_PY'
key = '$TPL_KEY'
valid = ('stop', 'permission', 'error', 'idle', 'question')
if key not in valid:
    print(f'peon-ping: invalid template key \"{key}\" — use one of: ' + ', '.join(valid), file=sys.stderr)
    sys.exit(1)
val = sys.argv[1] if len(sys.argv) > 1 else ''
if not val:
    # Show single template
    try:
        cfg = json.load(open(config_path))
        tpls = cfg.get('notification_templates', {})
    except Exception:
        tpls = {}
    v = tpls.get(key, '')
    if v:
        print(f'peon-ping: template {key} = \"{v}\"')
    else:
        print(f'peon-ping: template {key} not set (default: \"{{project}}\")')
    sys.exit(0)
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
tpls = cfg.get('notification_templates', {})
tpls[key] = val
cfg['notification_templates'] = tpls
json.dump(cfg, open(config_path, 'w'), indent=2)
print(f'peon-ping: template {key} set to \"{val}\"')
" "$TPL_VAL"
        _rc=$?; [ "$_rc" -ne 0 ] && exit "$_rc"
        sync_adapter_configs; exit 0 ;;
      *)
        echo "Usage: peon notifications <on|off|overlay|standard|position|dismiss|label|template|test>" >&2; exit 1 ;;
    esac ;;
  popups)
    # Alias for 'notifications' command - same behavior
    case "${2:-}" in
      on)
        python3 -c "
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
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
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['desktop_notifications'] = False
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: desktop notifications off')
"
        sync_adapter_configs; exit 0 ;;
      *)
        echo "Usage: peon popups on|off" >&2
        exit 1 ;;
    esac ;;
  volume)
    VOL_ARG="${2:-}"
    if [ -z "$VOL_ARG" ]; then
      export PEON_ENV_CONFIG_RO="$CONFIG_PY"
      python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ.get('PEON_ENV_CONFIG_RO', '')))
    print('peon-ping: volume ' + str(cfg.get('volume', 0.5)))
except Exception:
    print('peon-ping: volume 0.5')
"
      exit 0
    fi
    export PEON_ENV_VOL_ARG="$VOL_ARG"
    python3 -c "
import json, sys, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
vol_arg = os.environ.get('PEON_ENV_VOL_ARG', '')
try:
    vol = float(vol_arg)
except ValueError:
    print('peon-ping: invalid volume \"' + vol_arg + '\" — use a number between 0.0 and 1.0', file=sys.stderr)
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
      export PEON_ENV_CONFIG_RO="$CONFIG_PY"
      python3 -c "
import json, os
try:
    cfg = json.load(open(os.environ.get('PEON_ENV_CONFIG_RO', '')))
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
        export PEON_ENV_ROT_ARG="$ROT_ARG"
        python3 -c "
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
# Normalize agentskill alias to session_override
mode = os.environ.get('PEON_ENV_ROT_ARG', '')
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
import json, os
no_color = os.environ.get('NO_COLOR', '')
CYAN = '' if no_color else '\033[36m'
GREEN = '' if no_color else '\033[32m'
DIM = '' if no_color else '\033[90m'
RST = '' if no_color else '\033[0m'
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    _cfg_list = json.load(open(config_path))
    active = _cfg_list.get('default_pack', _cfg_list.get('active_pack', 'peon'))
except Exception:
    active = 'peon'
packs_dir = os.path.join(os.environ.get('PEON_ENV_PEON_DIR', ''), 'packs')
entries = []
for d in sorted(os.listdir(packs_dir)):
    for mname in ('openpeon.json', 'manifest.json'):
        mpath = os.path.join(packs_dir, d, mname)
        if os.path.exists(mpath):
            info = json.load(open(mpath))
            display = info.get('display_name', info.get('name', d))
            sdir = os.path.join(packs_dir, d, 'sounds')
            count = len(os.listdir(sdir)) if os.path.isdir(sdir) else 0
            entries.append((d, display, count))
            break
if not entries:
    print('  No packs installed.')
else:
    max_w = max(len(e[0]) for e in entries) + 2
    name_w = max(max_w, 24)
    print()
    print(f'  {CYAN}Installed packs ({len(entries)}){RST}')
    print()
    for d, display, count in entries:
        marker = f'  {GREEN}<-- active{RST}' if d == active else ''
        count_str = f'{DIM}{str(count).rjust(4)} sounds{RST}'
        disp_str = f'   {DIM}{display}{RST}' if display != d else ''
        print(f'  {d:<{name_w}}{count_str}{disp_str}{marker}')
    print()
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
config_path = os.environ.get('PEON_ENV_CONFIG', '')
pack_arg = os.environ.get('PACK_ARG', '')
packs_dir = os.path.join(os.environ.get('PEON_ENV_PEON_DIR', ''), 'packs')
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
      bind)
        # Parse --install, --pattern flags and pack name from remaining args
        BIND_INSTALL=0
        BIND_PATTERN=""
        PACK_ARG=""
        _skip_next=0
        for arg in "${@:3}"; do
          if [ "$_skip_next" -eq 1 ]; then
            BIND_PATTERN="$arg"
            _skip_next=0
            continue
          fi
          case "$arg" in
            --install) BIND_INSTALL=1 ;;
            --pattern) _skip_next=1 ;;
            --pattern=*) BIND_PATTERN="${arg#--pattern=}" ;;
            "") ;;
            *) PACK_ARG="$arg" ;;
          esac
        done
        if [ -z "$PACK_ARG" ]; then
          echo "Usage: peon packs bind <pack> [--pattern <glob>] [--install]" >&2; exit 1
        fi

        # If --install, download pack first
        if [ "$BIND_INSTALL" -eq 1 ]; then
          PACK_DL="$(resolve_pack_download)" || exit 1
          bash "$PACK_DL" --dir="$PEON_DIR" --packs="$PACK_ARG" || exit 1
        fi

        PACK_ARG="$PACK_ARG" BIND_PATTERN="$BIND_PATTERN" python3 -c "
import json, os, sys

config_path = os.environ.get('PEON_ENV_CONFIG', '')
pack_arg = os.environ.get('PACK_ARG', '')
bind_pattern = os.environ.get('BIND_PATTERN', '')
packs_dir = os.path.join(os.environ.get('PEON_ENV_PEON_DIR', ''), 'packs')
cwd = os.getcwd()

# Validate pack exists
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

# Determine pattern
if not bind_pattern:
    bind_pattern = cwd

# Load config
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

path_rules = cfg.get('path_rules', [])

# Update existing rule or append new one
found = False
for rule in path_rules:
    if rule.get('pattern') == bind_pattern:
        rule['pack'] = pack_arg
        found = True
        break
if not found:
    path_rules.append({'pattern': bind_pattern, 'pack': pack_arg})

cfg['path_rules'] = path_rules
json.dump(cfg, open(config_path, 'w'), indent=2)
print(f'peon-ping: bound {pack_arg} to {bind_pattern}')
if not os.environ.get('BIND_PATTERN', ''):
    print(f'Tip: use --pattern \"*/{os.path.basename(cwd)}\" to match any directory named {os.path.basename(cwd)}')
" || exit 1
        sync_adapter_configs; exit 0 ;;
      unbind)
        # Parse --pattern flag from remaining args
        UNBIND_PATTERN=""
        _skip_next=0
        for arg in "${@:3}"; do
          if [ "$_skip_next" -eq 1 ]; then
            UNBIND_PATTERN="$arg"
            _skip_next=0
            continue
          fi
          case "$arg" in
            --pattern) _skip_next=1 ;;
            --pattern=*) UNBIND_PATTERN="${arg#--pattern=}" ;;
          esac
        done

        UNBIND_PATTERN="$UNBIND_PATTERN" python3 -c "
import json, os, sys, fnmatch

config_path = os.environ.get('PEON_ENV_CONFIG', '')
unbind_pattern = os.environ.get('UNBIND_PATTERN', '')
cwd = os.getcwd()

# Load config
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

path_rules = cfg.get('path_rules', [])
if not path_rules:
    print('No pack bindings configured.')
    sys.exit(0)

# Determine which pattern to remove
target = unbind_pattern if unbind_pattern else cwd

# Try exact match first
new_rules = [r for r in path_rules if r.get('pattern') != target]
if len(new_rules) < len(path_rules):
    cfg['path_rules'] = new_rules
    json.dump(cfg, open(config_path, 'w'), indent=2)
    print(f'peon-ping: unbound {target}')
    sys.exit(0)

# No exact match — try fnmatch to find rules that match current directory
if not unbind_pattern:
    matching = [r for r in path_rules if fnmatch.fnmatch(cwd, r.get('pattern', ''))]
    if matching:
        print(f'No binding for \"{target}\", but found rules matching this directory:', file=sys.stderr)
        for r in matching:
            pat = r.get('pattern', '')
            pk = r.get('pack', '')
            print(f'  {pat} -> {pk}', file=sys.stderr)
        print(f'Use --pattern to remove a specific rule.', file=sys.stderr)
        sys.exit(1)

print(f'No binding found for \"{target}\".')
" || exit 1
        sync_adapter_configs; exit 0 ;;
      bindings)
        python3 -c "
import json, os, fnmatch

config_path = os.environ.get('PEON_ENV_CONFIG', '')
cwd = os.getcwd()

try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}

path_rules = cfg.get('path_rules', [])
if not path_rules:
    print('No pack bindings configured.')
else:
    for rule in path_rules:
        pattern = rule.get('pattern', '')
        pack = rule.get('pack', '')
        marker = ' *' if fnmatch.fnmatch(cwd, pattern) else ''
        print(f'  {pattern} -> {pack}{marker}')
"
        exit 0 ;;
      next)
        python3 -c "
import json, os, glob
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
active = cfg.get('default_pack', cfg.get('active_pack', 'peon'))
packs_dir = os.path.join(os.environ.get('PEON_ENV_PEON_DIR', ''), 'packs')
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

config_path = os.environ.get('PEON_ENV_CONFIG', '')
peon_dir = os.environ.get('PEON_ENV_PEON_DIR', '')
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

config_path = os.environ.get('PEON_ENV_CONFIG', '')
peon_dir = os.environ.get('PEON_ENV_PEON_DIR', '')
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
        export PEON_ENV_PACKS_TO_REMOVE="$PACKS_TO_REMOVE"
        python3 -c "
import json, os, shutil

config_path = os.environ.get('PEON_ENV_CONFIG', '')
peon_dir = os.environ.get('PEON_ENV_PEON_DIR', '')
packs_dir = os.path.join(peon_dir, 'packs')
to_remove = os.environ.get('PEON_ENV_PACKS_TO_REMOVE', '').split(',')

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
packs_dir = os.path.join(os.environ.get('PEON_ENV_PEON_DIR', ''), 'packs')

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

config_path = os.environ.get('PEON_ENV_GLOBAL_CONFIG', '')
peon_dir = os.environ.get('PEON_ENV_PEON_DIR', '')
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

config_path = os.environ.get('PEON_ENV_GLOBAL_CONFIG', '')
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
          clear)
            local _tmp
            _tmp=$(mktemp)
            sed -e ':a' -e 'N' -e '$!ba' \
                -e 's/"pack_rotation": \[[^]]*\]/"pack_rotation": []/' \
                "$PEON_ENV_GLOBAL_CONFIG" > "$_tmp" \
              && mv "$_tmp" "$PEON_ENV_GLOBAL_CONFIG" \
              || { rm -f "$_tmp"; exit 1; }
            echo "Rotation cleared"
            sync_adapter_configs; exit 0 ;;
          list|"")
            python3 -c "
import json, os
config_path = os.environ.get('PEON_ENV_GLOBAL_CONFIG', '')
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
            echo "Usage: peon packs rotation <list|add|remove|clear>" >&2; exit 1 ;;
        esac ;;
      community)
        python3 -c "
import json, os, urllib.request
no_color = os.environ.get('NO_COLOR', '')
CYAN = '' if no_color else '\033[36m'
GREEN = '' if no_color else '\033[32m'
DIM = '' if no_color else '\033[90m'
RST = '' if no_color else '\033[0m'
packs_dir = os.path.join(os.environ.get('PEON_ENV_PEON_DIR', ''), 'packs')
installed = set()
if os.path.isdir(packs_dir):
    installed = set(os.listdir(packs_dir))
try:
    req = urllib.request.urlopen('https://peonping.github.io/registry/index.json', timeout=10)
    reg = json.loads(req.read().decode())
except Exception as e:
    print(f'Error: could not fetch registry: {e}', flush=True)
    raise SystemExit(1)
packs = reg.get('packs', [])
grouped = {}
for p in packs:
    tier = p.get('trust_tier', 'unknown')
    grouped.setdefault(tier, []).append(p)
max_w = max((len(p['name']) for p in packs), default=20) + 2
name_w = max(max_w, 24)
tier_order = ['official'] + sorted(k for k in grouped if k != 'official')
print()
print(f'  {CYAN}Registry packs ({len(packs)} available){RST}')
print()
for tier in tier_order:
    if tier not in grouped:
        continue
    tier_packs = sorted(grouped[tier], key=lambda p: p['name'])
    tier_label = tier.capitalize()
    inst_count = sum(1 for p in tier_packs if p['name'] in installed)
    info = f'{len(tier_packs)} packs'
    if inst_count > 0:
        info += f', {inst_count} installed'
    print(f'  {DIM}--- {tier_label} ({info}) ---{RST}')
    for p in tier_packs:
        is_inst = p['name'] in installed
        check = f'{GREEN}\u2713{RST} ' if is_inst else '  '
        scount = p.get('sound_count')
        count_str = f'{DIM}{str(scount).rjust(4)} sounds{RST}' if scount else f'{DIM}   ? sounds{RST}'
        dname = p.get('display_name', '')
        disp_str = f'   {DIM}{dname}{RST}' if dname else ''
        print(f'  {check}{p[\"name\"]:<{name_w}}{count_str}{disp_str}')
    print()
"
        exit $? ;;
      search)
        if [ -z "${3:-}" ]; then
          echo "Usage: peon packs search <query>" >&2; exit 1
        fi
        export PEON_ENV_SEARCH_QUERY="${3}"
        python3 -c "
import json, os, urllib.request
no_color = os.environ.get('NO_COLOR', '')
CYAN = '' if no_color else '\033[36m'
GREEN = '' if no_color else '\033[32m'
DIM = '' if no_color else '\033[90m'
RST = '' if no_color else '\033[0m'
query = os.environ.get('PEON_ENV_SEARCH_QUERY', '').lower()
packs_dir = os.path.join(os.environ.get('PEON_ENV_PEON_DIR', ''), 'packs')
installed = set()
if os.path.isdir(packs_dir):
    installed = set(os.listdir(packs_dir))
try:
    req = urllib.request.urlopen('https://peonping.github.io/registry/index.json', timeout=10)
    reg = json.loads(req.read().decode())
except Exception as e:
    print(f'Error: could not fetch registry: {e}', flush=True)
    raise SystemExit(1)
matches = [p for p in reg.get('packs', []) if query in p.get('name', '').lower()]
if not matches:
    print(f'No packs matching \"{os.environ.get(\"PEON_ENV_SEARCH_QUERY\", \"\")}\".')
    raise SystemExit(0)
matches.sort(key=lambda p: p['name'])
max_w = max(len(p['name']) for p in matches) + 2
name_w = max(max_w, 24)
raw_query = os.environ.get('PEON_ENV_SEARCH_QUERY', '')
print()
print(f'  {CYAN}Search results for \"{raw_query}\" ({len(matches)} found){RST}')
print()
for p in matches:
    is_inst = p['name'] in installed
    check = f'{GREEN}\u2713{RST} ' if is_inst else '  '
    tier = p.get('trust_tier', 'unknown')
    scount = p.get('sound_count')
    count_str = f'{DIM}{str(scount).rjust(4)} sounds{RST}' if scount else f'{DIM}   ? sounds{RST}'
    dname = p.get('display_name', '')
    disp_str = f'   {DIM}{dname}{RST}' if dname else ''
    tier_str = f'  {DIM}[{tier}]{RST}'
    print(f'  {check}{p[\"name\"]:<{name_w}}{count_str}{disp_str}{tier_str}')
print()
"
        exit $? ;;
      *)
        echo "Usage: peon packs <list|use|next|install|install-local|remove|rotation|bind|unbind|bindings|community|search>" >&2; exit 1 ;;
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
        export PEON_ENV_NTFY_TOPIC="$TOPIC" PEON_ENV_NTFY_SERVER="$NTFY_SERVER" PEON_ENV_NTFY_TOKEN="$NTFY_TOKEN"
        python3 -c "
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['mobile_notify'] = {
    'enabled': True,
    'service': 'ntfy',
    'topic': os.environ.get('PEON_ENV_NTFY_TOPIC', ''),
    'server': os.environ.get('PEON_ENV_NTFY_SERVER', 'https://ntfy.sh'),
    'token': os.environ.get('PEON_ENV_NTFY_TOKEN', '')
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
        export PEON_ENV_PO_USER_KEY="$USER_KEY" PEON_ENV_PO_APP_TOKEN="$APP_TOKEN"
        python3 -c "
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['mobile_notify'] = {
    'enabled': True,
    'service': 'pushover',
    'user_key': os.environ.get('PEON_ENV_PO_USER_KEY', ''),
    'app_token': os.environ.get('PEON_ENV_PO_APP_TOKEN', '')
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
        export PEON_ENV_TG_BOT_TOKEN="$BOT_TOKEN" PEON_ENV_TG_CHAT_ID="$CHAT_ID"
        python3 -c "
import json, os
config_path = os.environ.get('PEON_ENV_CONFIG', '')
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['mobile_notify'] = {
    'enabled': True,
    'service': 'telegram',
    'bot_token': os.environ.get('PEON_ENV_TG_BOT_TOKEN', ''),
    'chat_id': os.environ.get('PEON_ENV_TG_CHAT_ID', '')
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
        topic = mn.get('topic', '?')
        server = mn.get('server', 'https://ntfy.sh')
        print(f'  Topic:  {topic}')
        print(f'  Server: {server}')
    elif service == 'pushover':
        ukey = mn.get('user_key', '?')
        print(f'  User:   {ukey[:8]}...')
    elif service == 'telegram':
        chat = mn.get('chat_id', '?')
        print(f'  Chat:   {chat}')
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
  ssh-audio)
    SSH_MODE_ARG="${2:-}"
    if [ -z "$SSH_MODE_ARG" ]; then
      python3 -c "
import json
try:
    cfg = json.load(open('$GLOBAL_CONFIG_PY'))
except Exception:
    cfg = {}
print('peon-ping: ssh audio mode ' + cfg.get('ssh_audio_mode', 'relay'))
"
      exit 0
    fi
    if [ "$SSH_MODE_ARG" != "relay" ] && [ "$SSH_MODE_ARG" != "auto" ] && [ "$SSH_MODE_ARG" != "local" ]; then
      echo "Usage: peon ssh-audio [relay|auto|local]" >&2
      exit 1
    fi
    python3 -c "
import json
config_path = '$GLOBAL_CONFIG_PY'
mode = '$SSH_MODE_ARG'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['ssh_audio_mode'] = mode
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: ssh audio mode set to ' + mode)
"
    sync_adapter_configs; exit 0 ;;
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
print('LINUX_AUDIO_PLAYER=' + repr(cfg.get('linux_audio_player', '')))                                                                                                                                                                    
print('PEON_SSH_AUDIO_MODE=' + repr(cfg.get('ssh_audio_mode', 'relay')))

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
    LINUX_AUDIO_PLAYER=$(echo "$PREVIEW_OUTPUT" | grep '^LINUX_AUDIO_PLAYER=' | head -1 | sed "s/^LINUX_AUDIO_PLAYER=//;s/^'//;s/'$//")                                                                                              
    PEON_SSH_AUDIO_MODE=$(echo "$PREVIEW_OUTPUT" | grep '^PEON_SSH_AUDIO_MODE=' | head -1 | sed "s/^PEON_SSH_AUDIO_MODE=//;s/^'//;s/'$//")

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
migrations = []
if 'active_pack' in cfg and 'default_pack' not in cfg:
    cfg['default_pack'] = cfg.pop('active_pack')
    changed = True
    migrations.append('active_pack -> default_pack')
elif 'active_pack' in cfg:
    cfg.pop('active_pack')
    changed = True
    migrations.append('active_pack removed')
if cfg.get('pack_rotation_mode') == 'agentskill':
    cfg['pack_rotation_mode'] = 'session_override'
    changed = True
    migrations.append('agentskill -> session_override')
if 'debug' not in cfg:
    cfg['debug'] = False
    changed = True
    migrations.append('debug')
if 'debug_retention_days' not in cfg:
    cfg['debug_retention_days'] = 7
    changed = True
    migrations.append('debug_retention_days')
if 'notification_all_screens' not in cfg:
    _theme = cfg.get('overlay_theme', '')
    # Default overlay always showed on all screens; themed overlays (glass/jarvis/sakura) only showed on the focused screen
    cfg['notification_all_screens'] = _theme not in ('glass', 'jarvis', 'sakura')
    changed = True
    migrations.append('notification_all_screens')
if changed:
    json.dump(cfg, open(config_path, 'w'), indent=2)
    print('peon-ping: config keys updated (' + ', '.join(migrations) + ')')
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
  mute                 Alias for 'pause'
  unmute               Alias for 'resume'
  toggle               Toggle mute on/off
  status               Check if paused or active
  volume [0.0-1.0]     Get or set volume level
  rotation [mode]      Get or set pack rotation mode (random|round-robin|session_override)
  notifications on        Enable desktop notification popups (sounds continue playing)
  notifications off       Disable desktop notification popups (sounds continue playing)
  notifications overlay   Use large overlay banners (default)
  notifications standard  Use standard system notifications
  notifications position [pos]  Get or set overlay position
                       Positions: top-center (default), top-right, top-left,
                       bottom-right, bottom-left, bottom-center
  notifications dismiss [N]  Get or set auto-dismiss time in seconds (0 = persistent)
  notifications label [text|reset]  Get, set, or reset notification label override
  notifications template [key] [fmt]  Get/set message templates (keys: stop, permission, error, idle, question)
  notifications test      Send a test notification
  popups on|off         Alias for 'notifications' - toggle desktop notification popups
  preview [category]   Play all sounds from a category (default: session.start)
  preview --list       List all categories and sound counts in the active pack
                       Categories: session.start, task.acknowledge, task.complete,
                       task.error, input.required, resource.limit, user.spam
  debug on             Enable debug logging
  debug off            Disable debug logging
  debug status         Show debug state, log directory, file count, total size
  logs                 Show last 50 lines of today's log
  logs --last N        Show last N lines across all log files
  logs --session ID    Filter today's log by session ID
  logs --session ID --all  Search across all log files for session ID
  logs --clear         Delete all log files (with confirmation)
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
  packs rotation clear    Clear all packs from rotation

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

Debug logging:
  debug on               Enable debug logging
  debug off              Disable debug logging
  debug status           Show debug logging state

Log management:
  logs                   Show last 50 lines of the most recent log
  logs --last N          Show last N lines of the most recent log
  logs --session <id>    Filter log entries by session ID
  logs --session <id> --all  Search across all log files
  logs --prune           Delete log files older than debug_retention_days
  logs --clear           Delete all log files

Relay (SSH/devcontainer/Codespaces):
  ssh-audio [mode]        SSH routing mode: relay (default), auto, or local
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
import json, datetime, sys, os, time, tempfile

config_path = '$CONFIG_PY'
state_path = '$STATE_PY'

${_PEON_STATE_PY_HELPERS}

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

state = _read_state(state_path)

trainer_state = state.get('trainer', {})
today = datetime.date.today().isoformat()

# Auto-reset if date changed
if trainer_state.get('date', '') != today:
    trainer_state = {'date': today, 'reps': {k: 0 for k in exercises}, 'last_reminder_ts': 0}
    state['trainer'] = trainer_state
    _write_state(state, state_path, indent=2)

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
import json, datetime, sys, os, time, tempfile

config_path = '$CONFIG_PY'
state_path = '$STATE_PY'
count = int('$COUNT')
exercise = '$EXERCISE'

${_PEON_STATE_PY_HELPERS}

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

state = _read_state(state_path)

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
_write_state(state, state_path, indent=2)

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
  debug)
    shift
    case "${1:-}" in
      "")
        echo "Usage: peon debug <on|off|status>"; exit 0 ;;
      on)
        python3 -c "
import json
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['debug'] = True
if 'debug_retention_days' not in cfg:
    cfg['debug_retention_days'] = 7
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        mkdir -p "$LOG_DIR"
        echo "peon-ping: debug logging enabled"
        echo "peon-ping: logs directory: $LOG_DIR"
        exit 0 ;;
      off)
        python3 -c "
import json
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
cfg['debug'] = False
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: debug logging disabled"
        exit 0 ;;
      status)
        python3 -c "
import json, os, glob
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
enabled = cfg.get('debug', False)
retention = cfg.get('debug_retention_days', 7)
print('peon-ping: debug logging ' + ('on' if enabled else 'off'))
print('peon-ping: log retention: ' + str(retention) + ' days')
"
        echo "peon-ping: logs directory: $LOG_DIR"
        if [ -d "$LOG_DIR" ]; then
          _count=$(find "$LOG_DIR" -name "peon-ping-*.log" 2>/dev/null | wc -l | tr -d ' ')
          echo "peon-ping: log files: $_count"
        fi
        exit 0 ;;
      *)
        echo "Usage: peon debug <on|off|status>" >&2; exit 1 ;;
    esac ;;
  logs)
    shift
    case "${1:---last}" in
      --prune)
        _retention=$(python3 -c "
import json
config_path = '$GLOBAL_CONFIG_PY'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
print(cfg.get('debug_retention_days', 7))
" 2>/dev/null)
        _retention="${_retention:-7}"
        if [ ! -d "$LOG_DIR" ]; then
          echo "peon-ping: no logs directory found"
          exit 0
        fi
        # Count files before pruning
        _before=$(find "$LOG_DIR" -name "peon-ping-*.log" 2>/dev/null | wc -l | tr -d ' ')
        _prune_old_logs "$_retention"
        _after=$(find "$LOG_DIR" -name "peon-ping-*.log" 2>/dev/null | wc -l | tr -d ' ')
        _removed=$(( _before - _after ))
        if [ "$_removed" -gt 0 ]; then
          echo "peon-ping: pruned $_removed log file(s) older than ${_retention} days"
        else
          echo "peon-ping: no log files older than ${_retention} days"
        fi
        exit 0 ;;
      --clear)
        if [ -d "$LOG_DIR" ]; then
          _count=$(find "$LOG_DIR" -name "peon-ping-*.log" 2>/dev/null | wc -l | tr -d ' ')
          if [ "$_count" -gt 0 ]; then
            rm -f "$LOG_DIR"/peon-ping-*.log
            echo "peon-ping: cleared $_count log file(s)"
          else
            echo "peon-ping: no log files to clear"
          fi
        else
          echo "peon-ping: no logs directory found"
        fi
        exit 0 ;;
      --last)
        _n="${2:-50}"
        if [ -d "$LOG_DIR" ]; then
          _files=$(ls -1 "$LOG_DIR"/peon-ping-*.log 2>/dev/null | sort)
          if [ -n "$_files" ]; then
            cat $_files | tail -n "$_n"
          else
            echo "peon-ping: no log files found"
          fi
        else
          echo "peon-ping: no logs directory found"
        fi
        exit 0 ;;
      --session)
        _sid="${2:-}"
        if [ -z "$_sid" ]; then
          echo "Usage: peon logs --session <id> [--all]" >&2; exit 1
        fi
        _all_flag="${3:-}"
        if [ "$_all_flag" = "--all" ]; then
          # Search across all log files in chronological order
          if [ ! -d "$LOG_DIR" ] || [ -z "$(ls "$LOG_DIR"/peon-ping-*.log 2>/dev/null)" ]; then
            echo "peon-ping: no log files found"
            exit 0
          fi
          _matches=$(ls -1 "$LOG_DIR"/peon-ping-*.log 2>/dev/null | sort | xargs grep -F "session=$_sid" 2>/dev/null)
          if [ -z "$_matches" ]; then
            echo "peon-ping: no entries for session=$_sid across all log files"
          else
            echo "$_matches" | sed 's/^[^:]*://'
          fi
          exit 0
        fi
        # Default: search today's log only
        _today=$(date +%Y-%m-%d)
        _logfile="$LOG_DIR/peon-ping-${_today}.log"
        if [ ! -f "$_logfile" ]; then
          echo "peon-ping: no log file for today ($_today)"
          exit 0
        fi
        grep -F "session=$_sid" "$_logfile" || echo "peon-ping: no entries for session=$_sid"
        exit 0 ;;
      *)
        echo "Usage: peon logs [--last N | --session <id> [--all] | --prune | --clear]" >&2; exit 1 ;;
    esac ;;
  --*)
    echo "Unknown option: $1" >&2
    echo "Run 'peon help' for usage." >&2; exit 1 ;;
  ?*)
    echo "Unknown command: $1" >&2
    echo "Run 'peon help' for usage." >&2; exit 1 ;;
esac

# Skip non-interactive Claude sessions (claude -p).
# CLAUDE_CODE_ENTRYPOINT is undocumented; if unset or unrecognised, do nothing.
if [ "${PEON_ALLOW_HEADLESS:-0}" != "1" ] && [ "${CLAUDE_CODE_ENTRYPOINT:-}" = "sdk-cli" ]; then
  exit 0
fi

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

# Walk the process tree to find the terminal TTY — stable across /clear (the process tree doesn't
# change when session_id resets) and unique per terminal tab (each tab has its own PTY).
# Using raw $PPID was unreliable because hooks run from worker subprocesses whose PIDs change per event.
_peon_walk_tty() {
  local _w="${PPID:-}" _last=""
  while [ -n "$_w" ] && [ "$_w" -gt 1 ] 2>/dev/null; do
    local _t
    _t=$(ps -p "$_w" -o tty= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
    [ -n "$_t" ] && [ "$_t" != "??" ] && _last="$_t"
    _w=$(ps -p "$_w" -o ppid= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)
  done
  echo "$_last"
}
_PEON_HOOK_TTY=$(_peon_walk_tty)

# --- Single Python call: config, event parsing, agent detection, category routing, sound picking ---
# Consolidates 5 separate python3 invocations into one for ~120-200ms faster hook response.
# Outputs shell variables consumed by the bash play/notify/title logic below.
_PEON_PYOUT=$(python3 -c "
import sys, json, os, re, random, time, shlex, tempfile
q = shlex.quote
_peon_start = time.monotonic()

config_path = '$CONFIG_PY'
state_file = '$STATE_PY'
peon_dir = '$PEON_DIR_PY'
paused = '$PAUSED' == 'true'
hook_tty = '$_PEON_HOOK_TTY'
agent_modes = {'delegate', 'dangerouslySkipPermissions'}
state_dirty = False

# --- Atomic state I/O helpers (shared definition from _PEON_STATE_PY_HELPERS) ---
${_PEON_STATE_PY_HELPERS}

# --- Load config ---
_config_error = None
try:
    cfg = json.load(open(config_path))
except Exception as _ce:
    cfg = {}
    _config_error = str(_ce)

if str(cfg.get('enabled', True)).lower() == 'false':
    print('PEON_EXIT=true')
    sys.exit(0)

# --- Structured debug logging (ADR-002) ---
_inv = os.urandom(2).hex()
_log_enabled = cfg.get('debug', False) or os.environ.get('PEON_DEBUG') == '1'
_log_fh = None

if _log_enabled:
    import datetime as _dt
    _log_dir = os.path.join(peon_dir, 'logs')
    try:
        os.makedirs(_log_dir, exist_ok=True)
        _log_date = _dt.date.today().isoformat()
        _log_path = os.path.join(_log_dir, 'peon-ping-' + _log_date + '.log')
        _log_is_new = not os.path.exists(_log_path)
        _log_fh = open(_log_path, 'a')
    except Exception:
        _log_enabled = False
        _log_fh = None

    def _log_quote(v):
        s = str(v)
        if ' ' in s or '\"' in s or '=' in s or '\n' in s or '\r' in s or not s:
            s = s.replace('\\\\', '\\\\\\\\').replace('\"', '\\\\\"')
            # Escape newlines/CR after backslash escaping to avoid double-escape.
            # Preserves the one-line-per-entry log invariant.
            s = s.replace('\r', '\\\\r').replace('\n', '\\\\n')
            return '\"' + s + '\"'
        return s

    def log(phase, **kw):
        if not _log_fh:
            return
        _now = _dt.datetime.now()
        ts = _now.strftime('%Y-%m-%dT%H:%M:%S.') + f'{_now.microsecond // 1000:03d}'
        parts = [f'{ts} [{phase}] inv={_inv}']
        for k, v in kw.items():
            parts.append(f'{k}={_log_quote(v)}')
        try:
            print(' '.join(parts), file=_log_fh, flush=True)
        except Exception:
            pass

    # Prune old logs on first file of the day
    if _log_is_new and _log_fh:
        _retention = int(cfg.get('debug_retention_days', 7))
        try:
            _cutoff = (_dt.date.today() - _dt.timedelta(days=_retention)).isoformat()
            for f in os.listdir(_log_dir):
                if f.startswith('peon-ping-') and f.endswith('.log'):
                    fdate = f[len('peon-ping-'):-len('.log')]
                    if fdate < _cutoff:
                        os.remove(os.path.join(_log_dir, f))
        except Exception:
            pass
else:
    log = lambda phase, **kw: None

# Log config error if config load failed (captured before logging was initialized)
if _config_error:
    log('config', error=_config_error, fallback='defaults')

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
headphones_only = str(cfg.get('headphones_only', False)).lower() == 'true'
meeting_detect = str(cfg.get('meeting_detect', False)).lower() == 'true'
suppress_sound_when_tab_focused = str(cfg.get('suppress_sound_when_tab_focused', False)).lower() == 'true'

log('config', loaded=config_path, volume=volume, pack=active_pack, enabled=True)

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
    'subagentStop': 'SubagentStop',
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

log('hook', event=event, session=session_id, cwd=cwd, paused=paused)

# --- Load state ---
state = read_state(state_file)

log('state', sessions=len(state.get('agent_sessions', [])), rotation_index=state.get('rotation_index', 0), last_stop=state.get('last_stop_time', 0))

# --- Agent detection ---
agent_sessions = set(state.get('agent_sessions', []))
if perm_mode and perm_mode in agent_modes:
    agent_sessions.add(session_id)
    state['agent_sessions'] = list(agent_sessions)
    state_dirty = True
    log('route', category='none', suppressed=True, reason='delegate_mode')
    log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
    print('PEON_EXIT=true')
    write_state(state, state_file)
    sys.exit(0)
elif session_id in agent_sessions:
    log('route', category='none', suppressed=True, reason='agent_session')
    log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
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

# --- Project name (priority chain: session_names[id] > CLAUDE_SESSION_NAME > .peon-label > notification_title_script > project_name_map > title_override > git repo > folder) ---
project = None

# -1. State-based session name (set via /peon-ping-rename, highest priority)
if session_id:
    _sn_state = state.get('session_names', {}).get(session_id, '').strip()
    if _sn_state: project = re.sub(r'[^a-zA-Z0-9 ._-]', '', _sn_state[:50])

# -0.5. TTY-based session name fallback — persists across /clear (terminal PTY doesn't change when
# session_id resets) and is unique per terminal tab (each tab has its own PTY).
# Composite key tty::cwd adds project-level isolation as a safety net.
hook_tty_key = (hook_tty + '::' + cwd) if hook_tty else cwd
if not project and hook_tty_key:
    _sn_tty = state.get('tty_names', {}).get(hook_tty_key, '').strip()
    if _sn_tty: project = re.sub(r'[^a-zA-Z0-9 ._-]', '', _sn_tty[:50])

# 0. CLAUDE_SESSION_NAME env var (per-terminal session override)
if not project:
    _sn = os.environ.get('CLAUDE_SESSION_NAME', '').strip()
    if _sn: project = re.sub(r'[^a-zA-Z0-9 ._-]', '', _sn[:50])

# 1. .peon-label file in project root
if not project and cwd:
    _lf = os.path.join(cwd, '.peon-label')
    if os.path.isfile(_lf):
        try:
            _l = open(_lf).read().strip().split('\n')[0][:50]
            if _l: project = _l
        except Exception: pass

# 1.5. notification_title_script (dynamic shell command)
if not project:
    _script = cfg.get('notification_title_script', '').strip()
    if _script:
        try:
            import subprocess as _sp
            _env = {**os.environ, 'PEON_SESSION_ID': session_id or '', 'PEON_CWD': cwd or '',
                    'PEON_HOOK_EVENT': event or '', 'PEON_SESSION_NAME': os.environ.get('CLAUDE_SESSION_NAME', '')}
            _r = _sp.run(_script, shell=True, capture_output=True, text=True, timeout=2, env=_env)
            _out = _r.stdout.strip()[:50]
            if _r.returncode == 0 and _out:
                project = re.sub(r'[^a-zA-Z0-9 ._-]', '', _out)
        except Exception:
            pass

# 2. project_name_map (glob pattern matching)
if not project:
    for _pat, _label in cfg.get('project_name_map', {}).items():
        if cwd and fnmatch.fnmatch(cwd, _pat):
            project = str(_label)[:50]; break

# 3. Static override
if not project:
    _ov = cfg.get('notification_title_override', '')
    if _ov: project = str(_ov)[:50]

# 4. Git repo name
if not project and cwd:
    try:
        import subprocess
        _git_remote = subprocess.check_output(
            ['git', 'remote', 'get-url', 'origin'],
            cwd=cwd, stderr=subprocess.DEVNULL, timeout=2
        ).decode().strip()
        project = _git_remote.rstrip('/').rsplit('/', 1)[-1].removesuffix('.git')
    except Exception:
        pass

# 5. Folder name fallback
if not project and cwd:
    project = cwd.rsplit('/', 1)[-1]
if not project:
    # Codex adapter can emit empty/root cwd when launched outside a workspace.
    # Keep labels agent-specific instead of falling back to "claude".
    _bundle = os.environ.get('__CFBundleIdentifier', '')
    if str(session_source).lower() == 'codex' or str(session_id).startswith('codex-') or _bundle == 'com.openai.codex':
        project = 'codex'
    else:
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
        # Compaction is mid-conversation — greeting makes no sense, but maintain title
        log('route', category='none', suppressed=True, reason='compact_source')
        log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
        print('PROJECT=' + q(project or ''))
        print('STATUS=ready')
        print('MARKER=')
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
        log('route', category='task.complete', suppressed=True, reason='subagent_session')
        log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
        write_state(state, state_file)
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
        # Unknown notification type — maintain tab title (e.g. plan mode events)
        log('route', category='none', suppressed=True, reason='unknown_notification')
        log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
        print('PROJECT=' + q(project or ''))
        print('STATUS=working')
        print('MARKER=')
        print('PEON_EXIT=true')
        sys.exit(0)
elif event == 'PermissionRequest':
    # Suppress permission sound/notification for known sub-agent sessions
    if suppress_subagent_complete and session_id in state.get('subagent_sessions', {}):
        log('route', category='input.required', suppressed=True, reason='subagent_session')
        log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
        write_state(state, state_file)
        print('PEON_EXIT=true')
        sys.exit(0)
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
        # Non-Bash tool failure — no sound, but maintain tab title
        log('route', category='none', suppressed=True, reason='non_bash_tool_failure')
        log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
        print('PROJECT=' + q(project or ''))
        print('STATUS=working')
        print('MARKER=')
        print('PEON_EXIT=true')
        sys.exit(0)
elif event == 'SubagentStop':
    # Subagent finished — suppress sound when configured, skip silently
    if suppress_subagent_complete:
        log('route', category='task.complete', suppressed=True, reason='subagent_stop_suppressed')
        log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
        write_state(state, state_file)
        print('PROJECT=' + q(project or ''))
        print('STATUS=working')
        print('MARKER=')
        print('PEON_EXIT=true')
        sys.exit(0)
    # When not suppressed, fall through to sound logic as task.complete
    category = 'task.complete'
    status = 'done'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'blue'
    msg = project
    msg_subtitle = ''
elif event == 'SubagentStart':
    # Record parent's pack so spawned subagent sessions inherit it, then stay silent
    state['pending_subagent_pack'] = dict(ts=time.time(), pack=active_pack)
    state_dirty = True
    write_state(state, state_file)
    # Maintain parent's tab title while subagent runs (no sound)
    log('route', category='none', suppressed=True, reason='subagent_start')
    log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
    print('PROJECT=' + q(project or ''))
    print('STATUS=working')
    print('MARKER=')
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
    write_state(state, state_file)
    log('route', category='none', suppressed=True, reason='session_end_cleanup')
    log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
    print('EVENT=' + q(event))
    print('PEON_EXIT=true')
    sys.exit(0)
elif event in ('PreToolUse', 'PostToolUse'):
    # Tool use events indicate Claude is actively working — clear needs_approval tab color
    status = 'working'
else:
    # Unknown event (plan mode, etc.) — no sound, but maintain tab title
    log('route', category='none', suppressed=True, reason='unknown_event')
    log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
    print('PROJECT=' + q(project or ''))
    print('STATUS=working')
    print('MARKER=')
    print('PEON_EXIT=true')
    sys.exit(0)

# --- Debounce rapid Stop events (e.g. background task completions) ---
if event == 'Stop':
    now = time.time()
    last_stop = state.get('last_stop_time', 0)
    if now - last_stop < 5:
        log('route', category='task.complete', suppressed=True, reason='debounce_5s')
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
    # --- Debounce rapid SessionStart events (e.g. multi-workspace IDE startup) ---
    # When IDEs open many workspaces at once, each fires SessionStart simultaneously.
    # Only the first one plays the greeting; the rest stay quiet until the cooldown expires.
    _ss_cooldown = float(cfg.get('session_start_cooldown_seconds', 30))
    if _ss_cooldown > 0:
        _last_ss = state.get('last_session_start_sound_time', 0)
        if now - _last_ss < _ss_cooldown:
            log('route', category='session.start', suppressed=True, reason='session_start_cooldown')
            category = ''  # another workspace just greeted — stay quiet
        else:
            state['last_session_start_sound_time'] = now
            state_dirty = True
elif category:
    session_starts = state.get('session_start_times', {})
    start_time = session_starts.get(session_id, 0)
    if start_time and (now - start_time) < 3:
        log('route', category=category, suppressed=True, reason='replay_suppression')
        category = ''
        notify = ''

# --- Check if category is enabled ---
if category and not cat_enabled.get(category, True):
    log('route', category=category, suppressed=True, reason='category_disabled')
    category = ''

# --- Log route decision ---
if category:
    _route_reason = 'paused' if paused else ''
    log('route', category=category, suppressed=bool(paused), reason=_route_reason)
elif not category:
    # No-op: category was cleared by a prior suppression (debounce, replay, cooldown)
    # that already emitted its own [route] log entry.
    pass

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
                if icon_candidate.startswith(('http://', 'https://')):
                    import hashlib, urllib.request
                    cache_dir = os.path.join(peon_dir, '.icon_cache')
                    os.makedirs(cache_dir, exist_ok=True)
                    url_hash = hashlib.md5(icon_candidate.encode()).hexdigest()
                    ext_parts = icon_candidate.split('?')[0].rsplit('.', 1)
                    ext = ext_parts[1][:5] if len(ext_parts) > 1 else 'png'
                    cached = os.path.join(cache_dir, url_hash + '.' + ext)
                    if not os.path.isfile(cached):
                        try:
                            urllib.request.urlretrieve(icon_candidate, cached)
                        except Exception:
                            cached = ''
                    if cached and os.path.isfile(cached):
                        icon_path = cached
                else:
                    icon_resolved = os.path.realpath(os.path.join(pack_dir, icon_candidate))
                    if icon_resolved.startswith(pack_root) and os.path.isfile(icon_resolved):
                        icon_path = icon_resolved
    except Exception as _e:
        log('sound', error=str(_e), fallback='none')

if sound_file:
    log('sound', file=os.path.basename(sound_file), pack=active_pack, candidates=len(candidates) if 'candidates' in dir() else 0, no_repeat=True)
elif category and not paused:
    log('sound', error='no sound found', pack=active_pack, fallback='none')

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
    log('trainer', active=True, reminder=bool(trainer_sound), exercise=list(exercises.keys())[0] if exercises else '', reps=sum(reps.values()), goal=sum(exercises.values()))
elif not trainer_cfg.get('enabled', False):
    log('trainer', active=False, reminder=False)

# --- Write state once ---
if state_dirty:
    write_state(state, state_file)
    # --- Relay state push ---
    if state.get('last_active'):
        import urllib.request as _ureq
        _relay_platform = os.environ.get('PEON_ENV_PLATFORM', '')
        _relay_host = os.environ.get('PEON_RELAY_HOST',
            'host.docker.internal' if _relay_platform == 'devcontainer' else 'localhost')
        _relay_port = os.environ.get('PEON_RELAY_PORT', '19998')
        try:
            _body = json.dumps({'last_active': state['last_active']}).encode()
            _req = _ureq.Request(
                f'http://{_relay_host}:{_relay_port}/state',
                data=_body,
                headers={'Content-Type': 'application/json'},
                method='POST',
            )
            _ureq.urlopen(_req, timeout=1)
        except Exception:
            pass

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

# --- Notification message template resolution ---
from collections import defaultdict as _defaultdict
_templates = cfg.get('notification_templates', {})
_tpl_key_map = {
    'task.complete': 'stop',
    'task.error': 'error',
}
_tpl_key = _tpl_key_map.get(category, '')
if event == 'Notification':
    if ntype == 'idle_prompt': _tpl_key = 'idle'
    elif ntype == 'elicitation_dialog': _tpl_key = 'question'
elif event == 'PermissionRequest':
    _tpl_key = 'permission'
_tpl = _templates.get(_tpl_key, '')
if _tpl:
    _tpl_vars = _defaultdict(str, {
        'project': project,
        'summary': event_data.get('transcript_summary', '').strip()[:120],
        'tool_name': event_data.get('tool_name', ''),
        'status': status,
        'event': event,
    })
    try:
        msg = _tpl.format_map(_tpl_vars)
    except Exception:
        pass

log('notify', desktop=bool(desktop_notif and notify), mobile=bool(cfg.get('mobile_notify', {}).get('service')), template=_tpl or '', rendered=msg)

# --- Log exit ---
_duration_ms = int((time.monotonic() - _peon_start) * 1000)
log('exit', duration_ms=_duration_ms, exit=0)

# --- Export log variables for bash-side [play] logging ---
if _log_enabled and _log_fh:
    try:
        _log_fh.close()
    except Exception:
        pass
    print('_PEON_LOG_FILE=' + q(_log_path))
    print('_PEON_INV_ID=' + q(_inv))

# --- Output shell variables ---
print('PEON_EXIT=false')
print('EVENT=' + q(event))
print('VOLUME=' + q(str(volume)))
print('PROJECT=' + q(project))
print('CWD=' + q(cwd))
print('STATUS=' + q(status))
print('MARKER=' + q(marker))
print('NOTIFY=' + q(notify))
print('NOTIFY_COLOR=' + q(notify_color))
_notify_type = ''
if event == 'Stop': _notify_type = 'complete'
elif event == 'PermissionRequest': _notify_type = 'permission'
elif event == 'PreCompact': _notify_type = 'limit'
elif event == 'Notification':
    if ntype == 'idle_prompt': _notify_type = 'idle'
    elif ntype == 'elicitation_dialog': _notify_type = 'question'
print('NOTIFY_TYPE=' + q(_notify_type))
print('MSG=' + q(msg))
print('MSG_SUBTITLE=' + q(msg_subtitle))
print('DESKTOP_NOTIF=' + ('true' if desktop_notif else 'false'))
print('NOTIF_STYLE=' + q(cfg.get('notification_style', 'overlay')))
print('NOTIF_POSITION=' + q(cfg.get('notification_position', 'top-center')))
print('NOTIF_DISMISS=' + q(str(cfg.get('notification_dismiss_seconds', 4))))
print('NOTIF_ALL_SCREENS=' + ('true' if cfg.get('notification_all_screens', True) else 'false'))
print('USE_SOUND_EFFECTS_DEVICE=' + q(str(use_sound_effects_device).lower()))
print('LINUX_AUDIO_PLAYER=' + q(linux_audio_player))
print('PEON_SSH_AUDIO_MODE=' + q(str(cfg.get('ssh_audio_mode', 'relay'))))
mn = cfg.get('mobile_notify', {})
mobile_on = bool(mn and mn.get('service') and mn.get('enabled', True))
print('MOBILE_NOTIF=' + ('true' if mobile_on else 'false'))
print('HEADPHONES_ONLY=' + ('true' if headphones_only else 'false'))
print('MEETING_DETECT=' + ('true' if meeting_detect else 'false'))
print('SUPPRESS_SOUND_WHEN_TAB_FOCUSED=' + ('true' if suppress_sound_when_tab_focused else 'false'))
print('SOUND_FILE=' + q(sound_file))
print('ICON_PATH=' + q(icon_path))
print('TRAINER_SOUND=' + q(trainer_sound))
print('TRAINER_MSG=' + q(trainer_msg))
print('TAB_COLOR_RGB=' + q(tab_color_rgb))
# Auto-prune: emit retention days so bash can prune without spawning another python3
_auto_debug = cfg.get('debug', False) or os.environ.get('PEON_DEBUG') == '1'
if _auto_debug:
    print('PEON_AUTO_PRUNE=' + q(str(cfg.get('debug_retention_days', 7))))
" <<< "$INPUT" 2>/dev/null)
eval "$_PEON_PYOUT"

# --- Bash-side debug log function for [play] and [notify] phases ---
if [ -n "${_PEON_LOG_FILE:-}" ]; then
  # Detect millisecond timestamp capability once at definition time.
  # GNU date (Linux, Git Bash, WSL) supports %N nanoseconds; BSD date (macOS stock) does not.
  if date '+%Y-%m-%dT%H:%M:%S.%3N' 2>/dev/null | grep -qE '\.[0-9]{3}$'; then
    _peon_log() {
      local phase="$1"; shift
      local ts
      ts=$(date '+%Y-%m-%dT%H:%M:%S.%3N')
      printf '%s [%s] inv=%s %s\n' "$ts" "$phase" "$_PEON_INV_ID" "$*" >> "$_PEON_LOG_FILE" 2>/dev/null
    }
  else
    # Fallback: use python3 for ms (already a dependency). If python3 is
    # unavailable, fall back to .000 (known limitation on stock macOS bash).
    if command -v python3 >/dev/null 2>&1; then
      _peon_log() {
        local phase="$1"; shift
        local ts
        ts=$(python3 -c "import datetime as d;n=d.datetime.now();print(n.strftime('%Y-%m-%dT%H:%M:%S.')+f'{n.microsecond//1000:03d}')")
        printf '%s [%s] inv=%s %s\n' "$ts" "$phase" "$_PEON_INV_ID" "$*" >> "$_PEON_LOG_FILE" 2>/dev/null
      }
    else
      # No ms source available — document as known limitation
      _peon_log() {
        local phase="$1"; shift
        local ts
        ts=$(date '+%Y-%m-%dT%H:%M:%S.000')
        printf '%s [%s] inv=%s %s\n' "$ts" "$phase" "$_PEON_INV_ID" "$*" >> "$_PEON_LOG_FILE" 2>/dev/null
      }
    fi
  fi
else
  _peon_log() { :; }
fi

# Auto-prune old log files in the background if debug is enabled.
# PEON_AUTO_PRUNE is set by the main Python block above — no extra python3 process needed.
if [ -n "${PEON_AUTO_PRUNE:-}" ]; then
  ( _prune_old_logs "$PEON_AUTO_PRUNE" ) &>/dev/null &
fi

# If Python signalled early exit (disabled, agent, unknown event), bail out
if [ "${PEON_EXIT:-true}" = "true" ]; then
  # On session end, kill any lingering overlay popups (macOS only)
  if [ "${EVENT:-}" = "SessionEnd" ] && [ "$PLATFORM" = "mac" ]; then
    pkill -f "mac-overlay" 2>/dev/null || true
  fi
  # Maintain tab title even on suppressed events (plan mode, unknown events, subagent start).
  # PROJECT is only emitted by paths that should maintain the title; agent/disabled paths omit it.
  if [ -n "${PROJECT:-}" ] && [ "${EVENT:-}" != "SessionEnd" ]; then
    { printf '\033]0;%s\007' "${MARKER:-}${PROJECT}: ${STATUS:-working}" > /dev/tty; } 2>/dev/null || true
  fi
  exit 0
fi

# --- Auto-prune old log files (non-blocking, when debug logging is enabled) ---
if [ "${PEON_DEBUG:-0}" = "1" ] || python3 -c "
import json
try:
    cfg = json.load(open('$GLOBAL_CONFIG_PY'))
except Exception:
    cfg = {}
exit(0 if cfg.get('debug', False) else 1)
" 2>/dev/null; then
  (
    _retention=$(python3 -c "
import json
try:
    cfg = json.load(open('$GLOBAL_CONFIG_PY'))
except Exception:
    cfg = {}
print(cfg.get('debug_retention_days', 7))
" 2>/dev/null)
    _retention="${_retention:-7}"
    _prune_old_logs "$_retention"
  ) &>/dev/null &
fi

HEADPHONES_DETECTED=true
if [ "${HEADPHONES_ONLY:-false}" = "true" ]; then
  detect_headphones || HEADPHONES_DETECTED=false
fi

IN_MEETING=false
if [ "${MEETING_DETECT:-false}" = "true" ]; then
  detect_meeting && IN_MEETING=true
fi

# Resolve session tty early so _run_sound_and_notify can check tab focus
if [ "${SUPPRESS_SOUND_WHEN_TAB_FOCUSED:-false}" = "true" ]; then
  _resolve_session_tty
fi

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
  if [ -n "$NEW_VER" ] && [ "$NEW_VER" != "$CUR_VER" ]; then
    echo "peon-ping update available: ${CUR_VER:-?} → $NEW_VER — run: curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash" >&2
  elif [ "$NEW_VER" = "$CUR_VER" ]; then
    rm -f "$PEON_DIR/.update_available"
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
    local _ssh_mode
    _ssh_mode="$(ssh_audio_mode)"
    # In local/auto mode, SSH can play locally without relay.
    [ "$_ssh_mode" = "relay" ] || return 0
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

# --- Resolve TTY for escape sequences ---
# Write to /dev/tty so the escape sequence reaches the terminal directly.
# Claude Code captures hook stdout, so plain printf would be swallowed.
# Inside tmux, /dev/tty may not be available from hook subprocesses;
# fall back to the tmux pane's TTY in that case.
_peon_tty=""
if [ -n "${TMUX:-}" ]; then
  _peon_tty=$(tmux display-message -p '#{pane_tty}' 2>/dev/null || true)
fi
[ -z "$_peon_tty" ] && _peon_tty="/dev/tty"

# Helper: emit an escape sequence, wrapping in DCS passthrough when inside tmux
# so the host terminal (iTerm2, Ghostty, etc.) receives it through the tmux layer.
# Requires tmux 3.3a+ with: set -g allow-passthrough on
_peon_esc() {
  local seq="$1"
  if [ -n "${TMUX:-}" ]; then
    { printf '\033Ptmux;\033%s\033\\' "$seq" > "$_peon_tty"; } 2>/dev/null || true
  else
    { printf '%s' "$seq" > "$_peon_tty"; } 2>/dev/null || true
  fi
}

# --- Set tab title via ANSI escape (works in Warp, iTerm2, Terminal.app, etc.) ---
if [ -n "$TITLE" ]; then
  _peon_esc "$(printf '\033]0;%s\007' "$TITLE")"
fi

# --- Set iTerm2 tab color (OSC 6) ---
# Detects iTerm2 via ITERM_SESSION_ID (persists inside tmux where TERM_PROGRAM=tmux).
# In test mode, write resolved color to file for BATS verification.
[ "${PEON_TEST:-0}" = "1" ] && [ -n "$TAB_COLOR_RGB" ] && echo "$TAB_COLOR_RGB" > "$PEON_DIR/.tab_color_rgb"
[ "${PEON_TEST:-0}" = "1" ] && [ -n "$ICON_PATH" ] && echo "$ICON_PATH" > "$PEON_DIR/.icon_path"
if [ -n "$TAB_COLOR_RGB" ] && { [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]] || [ -n "${ITERM_SESSION_ID:-}" ]; }; then
  read -r _R _G _B <<< "$TAB_COLOR_RGB"
  _peon_esc "$(printf '\033]6;1;bg;red;brightness;%d\a' "$_R")"
  _peon_esc "$(printf '\033]6;1;bg;green;brightness;%d\a' "$_G")"
  _peon_esc "$(printf '\033]6;1;bg;blue;brightness;%d\a' "$_B")"
fi

_run_sound_and_notify() {
  local _focused=""  # lazy: empty = not yet checked

  # --- Play sound ---
  if [ -n "$SOUND_FILE" ] && [ -f "$SOUND_FILE" ]; then
    local _skip_sound=false
    # Check headphones_only: skip sound if enabled but no headphones detected
    if [ "${HEADPHONES_ONLY:-false}" = "true" ] && [ "${HEADPHONES_DETECTED:-true}" = "false" ]; then
      _skip_sound=true
    fi
    # Check meeting_detect: skip sound if in a meeting
    if [ "$_skip_sound" = "false" ] && [ "${MEETING_DETECT:-false}" = "true" ] && [ "${IN_MEETING:-false}" = "true" ]; then
      _skip_sound=true
    fi
    # Check suppress_sound_when_tab_focused: skip sound if tab is focused
    if [ "$_skip_sound" = "false" ] && [ "${SUPPRESS_SOUND_WHEN_TAB_FOCUSED:-false}" = "true" ]; then
      [ -z "$_focused" ] && { terminal_is_focused && _focused=true || _focused=false; }
      [ "$_focused" = "true" ] && _skip_sound=true
    fi
    [ "$_skip_sound" = "false" ] && play_sound "$SOUND_FILE" "$VOLUME"
  fi

  # --- Smart notification: only when terminal is NOT frontmost ---
  if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ] && [ "${DESKTOP_NOTIF:-true}" = "true" ]; then
    [ -z "$_focused" ] && { terminal_is_focused && _focused=true || _focused=false; }
    [ "$_focused" != "true" ] && send_notification "$MSG" "$TITLE" "${NOTIFY_COLOR:-red}" "${ICON_PATH:-}"
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
      local _trainer_focused=""
      if [ "${SUPPRESS_SOUND_WHEN_TAB_FOCUSED:-false}" = "true" ]; then
        terminal_is_focused && _trainer_focused=true || _trainer_focused=false
        [ "$_trainer_focused" != "true" ] && play_sound "$TRAINER_SOUND" "$VOLUME"
      else
        play_sound "$TRAINER_SOUND" "$VOLUME"
      fi
      if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ] && [ "${DESKTOP_NOTIF:-true}" = "true" ]; then
        [ -z "$_trainer_focused" ] && { terminal_is_focused && _trainer_focused=true || _trainer_focused=false; }
        [ "$_trainer_focused" != "true" ] && send_notification "Peon Trainer" "${TRAINER_MSG:-Time for reps!}" "blue"
      fi
    ) & disown 2>/dev/null
  fi
fi

exit 0
