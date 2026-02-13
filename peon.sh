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
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      elif [ "${REMOTE_CONTAINERS:-}" = "true" ] || [ "${CODESPACES:-}" = "true" ]; then
        echo "devcontainer"
      elif [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_CLIENT:-}" ]; then
        echo "ssh"
      else
        echo "linux"
      fi ;;
    *) echo "unknown" ;;
  esac
}
PLATFORM=${PLATFORM:-$(detect_platform)}

PEON_DIR="${CLAUDE_PEON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CONFIG="$PEON_DIR/config.json"
STATE="$PEON_DIR/.state.json"

# --- Linux audio backend detection ---
detect_linux_player() {
  # Helper to check if a player is available (respects test-mode disable markers)
  player_available() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null || return 1
    # In test mode, check for disable marker
    [ "${PEON_TEST:-0}" = "1" ] && [ -f "${CLAUDE_PEON_DIR}/.disabled_${cmd}" ] && return 1
    return 0
  }

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
        nohup pw-play --volume "$vol" "$file" >/dev/null 2>&1 &
      else
        pw-play --volume "$vol" "$file" >/dev/null 2>&1
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
      nohup afplay -v "$vol" "$file" >/dev/null 2>&1 &
      save_sound_pid $!
      ;;
    wsl)
      local wpath
      wpath=$(wslpath -w "$file")
      # Convert backslashes to forward slashes for file:/// URI
      wpath="${wpath//\\//}"
      powershell.exe -NoProfile -NonInteractive -Command "
        Add-Type -AssemblyName PresentationCore
        \$p = New-Object System.Windows.Media.MediaPlayer
        \$p.Open([Uri]::new('file:///$wpath'))
        \$p.Volume = $vol
        Start-Sleep -Milliseconds 200
        \$p.Play()
        Start-Sleep -Seconds 3
        \$p.Close()
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
      player=$(detect_linux_player) || player=""
      if [ -n "$player" ]; then
        play_linux_sound "$file" "$vol" "$player"
        save_sound_pid $!
      fi
      ;;
  esac
}

# --- Platform-aware notification ---
# Args: msg, title, color (red/blue/yellow)
send_notification() {
  local msg="$1" title="$2" color="${3:-red}"
  local icon_path="$PEON_DIR/docs/peon-icon.png"
  case "$PLATFORM" in
    mac)
      # Use terminal-native escape sequences where supported (shows terminal icon).
      # Falls back to terminal-notifier (with peon icon) or osascript.
      case "${TERM_PROGRAM:-}" in
        iTerm.app)
          # iTerm2 OSC 9 — notification with iTerm2 icon
          printf '\e]9;%s\007' "$title: $msg" 2>/dev/null
          ;;
        kitty)
          # Kitty OSC 99
          printf '\e]99;i=peon:d=0;%s\e\\' "$title: $msg" 2>/dev/null
          ;;
        *)
          if command -v terminal-notifier &>/dev/null && [ -f "$icon_path" ]; then
            # terminal-notifier supports custom icon (brew install terminal-notifier)
            nohup terminal-notifier \
              -title "$title" \
              -message "$msg" \
              -appIcon "$icon_path" \
              -group "peon-ping" >/dev/null 2>&1 &
          else
            # Terminal.app, Warp, Ghostty, etc. — no native escape; use osascript
            nohup osascript - "$msg" "$title" >/dev/null 2>&1 <<'APPLESCRIPT' &
on run argv
  display notification (item 1 of argv) with title (item 2 of argv)
end run
APPLESCRIPT
          fi
          ;;
      esac
      ;;
    wsl)
      # Map color name to RGB
      local rgb_r=180 rgb_g=0 rgb_b=0
      case "$color" in
        blue)   rgb_r=30  rgb_g=80  rgb_b=180 ;;
        yellow) rgb_r=200 rgb_g=160 rgb_b=0   ;;
        red)    rgb_r=180 rgb_g=0   rgb_b=0   ;;
      esac
      local icon_win_path=""
      if [ -f "$icon_path" ]; then
        icon_win_path=$(wslpath -w "$icon_path" 2>/dev/null || true)
      fi
      (
        # Claim a popup slot for vertical stacking
        slot_dir="/tmp/peon-ping-popups"
        mkdir -p "$slot_dir"
        slot=0
        while ! mkdir "$slot_dir/slot-$slot" 2>/dev/null; do
          slot=$((slot + 1))
        done
        y_offset=$((40 + slot * 90))
        powershell.exe -NoProfile -NonInteractive -Command "
          Add-Type -AssemblyName System.Windows.Forms
          Add-Type -AssemblyName System.Drawing
          foreach (\$screen in [System.Windows.Forms.Screen]::AllScreens) {
            \$form = New-Object System.Windows.Forms.Form
            \$form.FormBorderStyle = 'None'
            \$form.BackColor = [System.Drawing.Color]::FromArgb($rgb_r, $rgb_g, $rgb_b)
            \$form.Size = New-Object System.Drawing.Size(500, 80)
            \$form.TopMost = \$true
            \$form.ShowInTaskbar = \$false
            \$form.StartPosition = 'Manual'
            \$form.Location = New-Object System.Drawing.Point(
              (\$screen.WorkingArea.X + (\$screen.WorkingArea.Width - 500) / 2),
              (\$screen.WorkingArea.Y + $y_offset)
            )
            \$iconLeft = 10
            \$iconSize = 60
            if ('$icon_win_path' -ne '' -and (Test-Path '$icon_win_path')) {
              \$pb = New-Object System.Windows.Forms.PictureBox
              \$pb.Image = [System.Drawing.Image]::FromFile('$icon_win_path')
              \$pb.SizeMode = 'Zoom'
              \$pb.Size = New-Object System.Drawing.Size(\$iconSize, \$iconSize)
              \$pb.Location = New-Object System.Drawing.Point(\$iconLeft, 10)
              \$pb.BackColor = [System.Drawing.Color]::Transparent
              \$form.Controls.Add(\$pb)
              \$label = New-Object System.Windows.Forms.Label
              \$label.Location = New-Object System.Drawing.Point((\$iconLeft + \$iconSize + 5), 0)
              \$label.Size = New-Object System.Drawing.Size((500 - \$iconLeft - \$iconSize - 15), 80)
            } else {
              \$label = New-Object System.Windows.Forms.Label
              \$label.Dock = 'Fill'
            }
            \$label.Text = '$msg'
            \$label.ForeColor = [System.Drawing.Color]::White
            \$label.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
            \$label.TextAlign = 'MiddleCenter'
            \$form.Controls.Add(\$label)
            \$form.Show()
          }
          Start-Sleep -Seconds 4
          [System.Windows.Forms.Application]::Exit()
        " &>/dev/null
        rm -rf "$slot_dir/slot-$slot"
      ) &
      ;;
    devcontainer|ssh)
      local relay_host_default="host.docker.internal"
      [ "$PLATFORM" = "ssh" ] && relay_host_default="localhost"
      local relay_host="${PEON_RELAY_HOST:-$relay_host_default}"
      local relay_port="${PEON_RELAY_PORT:-19998}"
      local json_title json_msg
      json_title=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$title" 2>/dev/null || echo "\"$title\"")
      json_msg=$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$msg" 2>/dev/null || echo "\"$msg\"")
      nohup curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d "{\"title\":${json_title},\"message\":${json_msg},\"color\":\"$color\"}" \
        "http://${relay_host}:${relay_port}/notify" >/dev/null 2>&1 &
      ;;
    linux)
      if command -v notify-send &>/dev/null; then
        local urgency="normal"
        case "$color" in
          red) urgency="critical" ;;
        esac
        local icon_flag=""
        if [ -f "$icon_path" ]; then
          icon_flag="--icon=$icon_path"
        fi
        nohup notify-send --urgency="$urgency" $icon_flag "$title" "$msg" >/dev/null 2>&1 &
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
        Terminal|iTerm2|Warp|Alacritty|kitty|WezTerm|Ghostty) return 0 ;;
        *) return 1 ;;
      esac
      ;;
    wsl)
      # Checking Windows focus from WSL adds too much latency; always notify
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
  local config="$CONFIG"

  # Read mobile config via Python (fast, single invocation)
  local mobile_vars
  mobile_vars=$(python3 -c "
import json, sys, shlex
q = shlex.quote
try:
    cfg = json.load(open('$config'))
    mn = cfg.get('mobile_notify', {})
except:
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

  case "$MOBILE_SERVICE" in
    ntfy)
      [ -z "$MOBILE_TOPIC" ] && return 0
      local ntfy_url="${MOBILE_SERVER}/${MOBILE_TOPIC}"
      local auth_header=""
      [ -n "$MOBILE_TOKEN" ] && auth_header="-H \"Authorization: Bearer ${MOBILE_TOKEN}\""
      nohup curl -sf \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: video_game" \
        $auth_header \
        -d "$msg" \
        "$ntfy_url" >/dev/null 2>&1 &
      ;;
    pushover)
      [ -z "$MOBILE_USER_KEY" ] || [ -z "$MOBILE_APP_TOKEN" ] && return 0
      local po_priority=0
      case "$priority" in
        high) po_priority=1 ;;
        low) po_priority=-1 ;;
      esac
      nohup curl -sf \
        -d "token=${MOBILE_APP_TOKEN}" \
        -d "user=${MOBILE_USER_KEY}" \
        -d "title=${title}" \
        -d "message=${msg}" \
        -d "priority=${po_priority}" \
        "https://api.pushover.net/1/messages.json" >/dev/null 2>&1 &
      ;;
    telegram)
      [ -z "$MOBILE_BOT_TOKEN" ] || [ -z "$MOBILE_CHAT_ID" ] && return 0
      local tg_text="${title}%0A${msg}"
      nohup curl -sf \
        "https://api.telegram.org/bot${MOBILE_BOT_TOKEN}/sendMessage?chat_id=${MOBILE_CHAT_ID}&text=${tg_text}" >/dev/null 2>&1 &
      ;;
  esac
}

# --- CLI subcommands (must come before INPUT=$(cat) which blocks on stdin) ---
PAUSED_FILE="$PEON_DIR/.paused"
case "${1:-}" in
  pause)   touch "$PAUSED_FILE"; echo "peon-ping: sounds paused"; exit 0 ;;
  resume)  rm -f "$PAUSED_FILE"; echo "peon-ping: sounds resumed"; exit 0 ;;
  toggle)
    if [ -f "$PAUSED_FILE" ]; then rm -f "$PAUSED_FILE"; echo "peon-ping: sounds resumed"
    else touch "$PAUSED_FILE"; echo "peon-ping: sounds paused"; fi
    exit 0 ;;
  status)
    [ -f "$PAUSED_FILE" ] && echo "peon-ping: paused" || echo "peon-ping: active"
    python3 -c "
import json
try:
    c = json.load(open('$CONFIG'))
    dn = c.get('desktop_notifications', True)
    print('peon-ping: desktop notifications ' + ('on' if dn else 'off'))
    mn = c.get('mobile_notify', {})
    if mn and mn.get('service'):
        enabled = mn.get('enabled', True)
        svc = mn.get('service', '?')
        print(f'peon-ping: mobile notifications ' + ('on' if enabled else 'off') + f' ({svc})')
    else:
        print('peon-ping: mobile notifications not configured')
except:
    print('peon-ping: desktop notifications on')
    print('peon-ping: mobile notifications not configured')
"
    exit 0 ;;
  notifications)
    case "${2:-}" in
      on)
        python3 -c "
import json
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
    cfg = {}
cfg['desktop_notifications'] = True
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: desktop notifications on')
"
        exit 0 ;;
      off)
        python3 -c "
import json
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
    cfg = {}
cfg['desktop_notifications'] = False
json.dump(cfg, open(config_path, 'w'), indent=2)
print('peon-ping: desktop notifications off')
"
        exit 0 ;;
      *)
        echo "Usage: peon notifications <on|off>" >&2; exit 1 ;;
    esac ;;
  packs)
    case "${2:-}" in
      list)
        python3 -c "
import json, os, glob
config_path = '$CONFIG'
try:
    active = json.load(open(config_path)).get('active_pack', 'peon')
except:
    active = 'peon'
packs_dir = '$PEON_DIR/packs'
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
        PACK_ARG="${3:-}"
        if [ -z "$PACK_ARG" ]; then
          echo "Usage: peon packs use <name>" >&2; exit 1
        fi
        python3 -c "
import json, os, glob, sys
config_path = '$CONFIG'
pack_arg = '$PACK_ARG'
packs_dir = '$PEON_DIR/packs'
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
except:
    cfg = {}
cfg['active_pack'] = pack_arg
json.dump(cfg, open(config_path, 'w'), indent=2)
display = pack_arg
for mname in ('openpeon.json', 'manifest.json'):
    mpath = os.path.join(packs_dir, pack_arg, mname)
    if os.path.exists(mpath):
        display = json.load(open(mpath)).get('display_name', pack_arg)
        break
print(f'peon-ping: switched to {pack_arg} ({display})')
" || exit 1
        exit 0 ;;
      next)
        python3 -c "
import json, os, glob
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
    cfg = {}
active = cfg.get('active_pack', 'peon')
packs_dir = '$PEON_DIR/packs'
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
cfg['active_pack'] = next_pack
json.dump(cfg, open(config_path, 'w'), indent=2)
# Read display name
for mname in ('openpeon.json', 'manifest.json'):
    mpath = os.path.join(packs_dir, next_pack, mname)
    if os.path.exists(mpath):
        display = json.load(open(mpath)).get('display_name', next_pack)
        break
print(f'peon-ping: switched to {next_pack} ({display})')
"
        exit 0 ;;
      remove)
        REMOVE_ARG="${3:-}"
        if [ -n "$REMOVE_ARG" ]; then
          PACKS_TO_REMOVE=$(python3 -c "
import json, os, sys

config_path = '$CONFIG'
peon_dir = '$PEON_DIR'
packs_dir = os.path.join(peon_dir, 'packs')
remove_arg = '$REMOVE_ARG'

try:
    cfg = json.load(open(config_path))
except:
    cfg = {}
active = cfg.get('active_pack', 'peon')

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
        errors.append(f'Cannot remove \"{p}\" — it is the active pack. Switch first with: peon packs use <other>')
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

config_path = '$CONFIG'
peon_dir = '$PEON_DIR'
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
except:
    cfg = {}
rotation = cfg.get('pack_rotation', [])
if rotation:
    cfg['pack_rotation'] = [p for p in rotation if p not in to_remove]
    json.dump(cfg, open(config_path, 'w'), indent=2)
"
        exit 0 ;;
      *)
        echo "Usage: peon packs <list|use|next|remove>" >&2; exit 1 ;;
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
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
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
        exit 0 ;;
      pushover)
        USER_KEY="${3:-}"
        APP_TOKEN="${4:-}"
        if [ -z "$USER_KEY" ] || [ -z "$APP_TOKEN" ]; then
          echo "Usage: peon mobile pushover <user_key> <app_token>" >&2
          exit 1
        fi
        python3 -c "
import json
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
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
        exit 0 ;;
      telegram)
        BOT_TOKEN="${3:-}"
        CHAT_ID="${4:-}"
        if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
          echo "Usage: peon mobile telegram <bot_token> <chat_id>" >&2
          exit 1
        fi
        python3 -c "
import json
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
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
        exit 0 ;;
      off)
        python3 -c "
import json
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
    cfg = {}
mn = cfg.get('mobile_notify', {})
mn['enabled'] = False
cfg['mobile_notify'] = mn
json.dump(cfg, open(config_path, 'w'), indent=2)
"
        echo "peon-ping: mobile notifications disabled"
        exit 0 ;;
      on)
        python3 -c "
import json
config_path = '$CONFIG'
try:
    cfg = json.load(open(config_path))
except:
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
        exit $? ;;
      status)
        python3 -c "
import json
try:
    cfg = json.load(open('$CONFIG'))
    mn = cfg.get('mobile_notify', {})
except:
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
    cfg = json.load(open('$CONFIG'))
    mn = cfg.get('mobile_notify', {})
except:
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
    RELAY_SCRIPT="$PEON_DIR/relay.sh"
    if [ ! -f "$RELAY_SCRIPT" ]; then
      echo "Error: relay.sh not found at $PEON_DIR" >&2
      echo "Re-run the installer to get the relay script." >&2
      exit 1
    fi
    shift
    exec bash "$RELAY_SCRIPT" "$@"
    ;;
  help|--help|-h)
    cat <<'HELPEOF'
Usage: peon <command>

Commands:
  pause                Mute sounds
  resume               Unmute sounds
  toggle               Toggle mute on/off
  status               Check if paused or active
  notifications on     Enable desktop notifications
  notifications off    Disable desktop notifications
  help                 Show this help

Pack management:
  packs list           List installed sound packs
  packs use <name>     Switch to a specific pack
  packs next           Cycle to the next pack
  packs remove <p1,p2> Remove specific packs

Mobile notifications:
  mobile ntfy <topic>  Set up ntfy.sh push notifications
  mobile off           Disable mobile notifications
  mobile status        Show mobile config
  mobile test          Send a test notification

Relay (SSH/devcontainer/Codespaces):
  relay [--port=N]     Start audio relay on your local machine
  relay --daemon       Start relay in background
  relay --stop         Stop background relay
  relay --status       Check if relay is running
HELPEOF
    exit 0 ;;
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

config_path = '$CONFIG'
state_file = '$STATE'
peon_dir = '$PEON_DIR'
paused = '$PAUSED' == 'true'
agent_modes = {'delegate'}
state_dirty = False

# --- Load config ---
try:
    cfg = json.load(open(config_path))
except:
    cfg = {}

if str(cfg.get('enabled', True)).lower() == 'false':
    print('PEON_EXIT=true')
    sys.exit(0)

volume = cfg.get('volume', 0.5)
desktop_notif = cfg.get('desktop_notifications', True)
active_pack = cfg.get('active_pack', 'peon')
pack_rotation = cfg.get('pack_rotation', [])
annoyed_threshold = int(cfg.get('annoyed_threshold', 3))
annoyed_window = float(cfg.get('annoyed_window_seconds', 10))
silent_window = float(cfg.get('silent_window_seconds', 0))
cats = cfg.get('categories', {})
cat_enabled = {}
for c in ['session.start','task.acknowledge','task.complete','task.error','input.required','resource.limit','user.spam']:
    cat_enabled[c] = str(cats.get(c, True)).lower() == 'true'

# --- Parse event JSON from stdin ---
event_data = json.load(sys.stdin)
event = event_data.get('hook_event_name', '')
ntype = event_data.get('notification_type', '')
cwd = event_data.get('cwd', '')
session_id = event_data.get('session_id', '')
perm_mode = event_data.get('permission_mode', '')

# --- Load state ---
try:
    state = json.load(open(state_file))
except:
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

# --- Pack rotation: pin a pack per session ---
if pack_rotation:
    session_packs = state.get('session_packs', {})
    if session_id in session_packs and session_packs[session_id] in pack_rotation:
        active_pack = session_packs[session_id]
    else:
        rotation_mode = cfg.get('pack_rotation_mode', 'random')
        if rotation_mode == 'round-robin':
            rotation_index = state.get('rotation_index', 0) % len(pack_rotation)
            active_pack = pack_rotation[rotation_index]
            state['rotation_index'] = rotation_index + 1
        else:
            active_pack = random.choice(pack_rotation)
        session_packs[session_id] = active_pack
        state['session_packs'] = session_packs
        state_dirty = True

# --- Project name ---
project = cwd.rsplit('/', 1)[-1] if cwd else 'claude'
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

if event == 'SessionStart':
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
    if silent_window > 0:
        prompt_starts = state.get('prompt_start_times', {})
        prompt_starts[session_id] = time.time()
        state['prompt_start_times'] = prompt_starts
        state_dirty = True
elif event == 'Stop':
    category = 'task.complete'
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
        msg = project + '  \u2014  Task complete'
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
        msg = project + '  \u2014  Waiting for input'
    else:
        print('PEON_EXIT=true')
        sys.exit(0)
elif event == 'PermissionRequest':
    category = 'input.required'
    status = 'needs approval'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'red'
    msg = project + '  \u2014  Permission needed'
else:
    # Unknown event (e.g. PostToolUseFailure) — exit cleanly
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
    except:
        pass

# --- Write state once ---
if state_dirty:
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    json.dump(state, open(state_file, 'w'))

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
print('DESKTOP_NOTIF=' + ('true' if desktop_notif else 'false'))
mn = cfg.get('mobile_notify', {})
mobile_on = bool(mn and mn.get('service') and mn.get('enabled', True))
print('MOBILE_NOTIF=' + ('true' if mobile_on else 'false'))
print('SOUND_FILE=' + q(sound_file))
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

# --- Devcontainer relay guidance on SessionStart ---
if [ "$EVENT" = "SessionStart" ] && [ "$PLATFORM" = "devcontainer" ]; then
  RELAY_HOST="${PEON_RELAY_HOST:-host.docker.internal}"
  RELAY_PORT="${PEON_RELAY_PORT:-19998}"
  if ! curl -sf --connect-timeout 1 --max-time 2 "http://${RELAY_HOST}:${RELAY_PORT}/health" >/dev/null 2>&1; then
    echo "peon-ping: devcontainer detected but audio relay not reachable at ${RELAY_HOST}:${RELAY_PORT}" >&2
    echo "peon-ping: run 'peon relay' on your host machine to enable sounds" >&2
  fi
fi

# --- SSH relay guidance on SessionStart ---
if [ "$EVENT" = "SessionStart" ] && [ "$PLATFORM" = "ssh" ]; then
  RELAY_HOST="${PEON_RELAY_HOST:-localhost}"
  RELAY_PORT="${PEON_RELAY_PORT:-19998}"
  if ! curl -sf --connect-timeout 1 --max-time 2 "http://${RELAY_HOST}:${RELAY_PORT}/health" >/dev/null 2>&1; then
    echo "peon-ping: SSH session detected but audio relay not reachable at ${RELAY_HOST}:${RELAY_PORT}" >&2
    echo "peon-ping: on your LOCAL machine, run: peon relay" >&2
    echo "peon-ping: then reconnect with: ssh -R 19998:localhost:19998 <host>" >&2
  fi
fi

# --- Build tab title ---
TITLE="${MARKER}${PROJECT}: ${STATUS}"

# --- Set tab title via ANSI escape (works in Warp, iTerm2, Terminal.app, etc.) ---
if [ -n "$TITLE" ]; then
  printf '\033]0;%s\007' "$TITLE"
fi

# --- Play sound ---
if [ -n "$SOUND_FILE" ] && [ -f "$SOUND_FILE" ]; then
  play_sound "$SOUND_FILE" "$VOLUME"
fi

# --- Smart notification: only when terminal is NOT frontmost ---
if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ] && [ "${DESKTOP_NOTIF:-true}" = "true" ]; then
  if ! terminal_is_focused; then
    send_notification "$MSG" "$TITLE" "${NOTIFY_COLOR:-red}"
  fi
fi

# --- Mobile push notification (always sends when configured, regardless of focus) ---
if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ] && [ "${MOBILE_NOTIF:-false}" = "true" ]; then
  send_mobile_notification "$MSG" "$TITLE" "${NOTIFY_COLOR:-red}"
fi

wait
exit 0
