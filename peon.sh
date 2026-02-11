#!/bin/bash
# peon-ping: Warcraft III Peon voice lines for Claude Code hooks
# Replaces notify.sh — handles sounds, tab titles, and notifications
set -uo pipefail

# --- Platform detection ---
detect_platform() {
  case "$(uname -s)" in
    Darwin) echo "mac" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      else
        echo "linux"
      fi ;;
    *) echo "unknown" ;;
  esac
}
PLATFORM=$(detect_platform)

PEON_DIR="${CLAUDE_PEON_DIR:-$HOME/.claude/hooks/peon-ping}"
CONFIG="$PEON_DIR/config.json"
STATE="$PEON_DIR/.state.json"

# --- Platform-aware audio playback ---
play_sound() {
  local file="$1" vol="$2"
  case "$PLATFORM" in
    mac)
      nohup afplay -v "$vol" "$file" >/dev/null 2>&1 &
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
      ;;
  esac
}

# --- Platform-aware notification ---
# Args: msg, title, color (red/blue/yellow)
send_notification() {
  local msg="$1" title="$2" color="${3:-red}"
  case "$PLATFORM" in
    mac)
      nohup osascript - "$msg" "$title" >/dev/null 2>&1 <<'APPLESCRIPT' &
on run argv
  display notification (item 1 of argv) with title (item 2 of argv)
end run
APPLESCRIPT
      ;;
    wsl)
      # Map color name to RGB
      local rgb_r=180 rgb_g=0 rgb_b=0
      case "$color" in
        blue)   rgb_r=30  rgb_g=80  rgb_b=180 ;;
        yellow) rgb_r=200 rgb_g=160 rgb_b=0   ;;
        red)    rgb_r=180 rgb_g=0   rgb_b=0   ;;
      esac
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
            \$label = New-Object System.Windows.Forms.Label
            \$label.Text = '$msg'
            \$label.ForeColor = [System.Drawing.Color]::White
            \$label.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
            \$label.TextAlign = 'MiddleCenter'
            \$label.Dock = 'Fill'
            \$form.Controls.Add(\$label)
            \$form.Show()
          }
          Start-Sleep -Seconds 4
          [System.Windows.Forms.Application]::Exit()
        " &>/dev/null
        rm -rf "$slot_dir/slot-$slot"
      ) &
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
    *)
      return 1
      ;;
  esac
}

# --- CLI subcommands (must come before INPUT=$(cat) which blocks on stdin) ---
PAUSED_FILE="$PEON_DIR/.paused"
case "${1:-}" in
  --pause)   touch "$PAUSED_FILE"; echo "peon-ping: sounds paused"; exit 0 ;;
  --resume)  rm -f "$PAUSED_FILE"; echo "peon-ping: sounds resumed"; exit 0 ;;
  --toggle)
    if [ -f "$PAUSED_FILE" ]; then rm -f "$PAUSED_FILE"; echo "peon-ping: sounds resumed"
    else touch "$PAUSED_FILE"; echo "peon-ping: sounds paused"; fi
    exit 0 ;;
  --status)
    [ -f "$PAUSED_FILE" ] && echo "peon-ping: paused" || echo "peon-ping: active"
    exit 0 ;;
  --packs)
    python3 -c "
import json, os, glob
config_path = '$CONFIG'
try:
    active = json.load(open(config_path)).get('active_pack', 'peon')
except:
    active = 'peon'
packs_dir = '$PEON_DIR/packs'
for m in sorted(glob.glob(os.path.join(packs_dir, '*/manifest.json'))):
    info = json.load(open(m))
    name = info.get('name', os.path.basename(os.path.dirname(m)))
    display = info.get('display_name', name)
    marker = ' *' if name == active else ''
    print(f'  {name:24s} {display}{marker}')
"
    exit 0 ;;
  --pack)
    PACK_ARG="${2:-}"
    if [ -z "$PACK_ARG" ]; then
      # No argument — cycle to next pack alphabetically
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
    os.path.basename(os.path.dirname(m))
    for m in glob.glob(os.path.join(packs_dir, '*/manifest.json'))
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
mpath = os.path.join(packs_dir, next_pack, 'manifest.json')
display = json.load(open(mpath)).get('display_name', next_pack)
print(f'peon-ping: switched to {next_pack} ({display})')
"
    else
      # Argument given — set specific pack
      python3 -c "
import json, os, glob, sys
config_path = '$CONFIG'
pack_arg = '$PACK_ARG'
packs_dir = '$PEON_DIR/packs'
names = sorted([
    os.path.basename(os.path.dirname(m))
    for m in glob.glob(os.path.join(packs_dir, '*/manifest.json'))
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
mpath = os.path.join(packs_dir, pack_arg, 'manifest.json')
display = json.load(open(mpath)).get('display_name', pack_arg)
print(f'peon-ping: switched to {pack_arg} ({display})')
" || exit 1
    fi
    exit 0 ;;
  --help|-h)
    cat <<'HELPEOF'
Usage: peon <command>

Commands:
  --pause        Mute sounds
  --resume       Unmute sounds
  --toggle       Toggle mute on/off
  --status       Check if paused or active
  --packs        List available sound packs
  --pack <name>  Switch to a specific pack
  --pack         Cycle to the next pack
  --help         Show this help
HELPEOF
    exit 0 ;;
  --*)
    echo "Unknown option: $1" >&2
    echo "Run 'peon --help' for usage." >&2; exit 1 ;;
esac

INPUT=$(cat)

# Debug log (uncomment to troubleshoot)
# echo "$(date): peon hook — $INPUT" >> /tmp/peon-ping-debug.log

# --- Load config (shlex.quote prevents shell injection) ---
eval "$(python3 -c "
import json, shlex
try:
    c = json.load(open('$CONFIG'))
except:
    c = {}
print('ENABLED=' + shlex.quote(str(c.get('enabled', True)).lower()))
print('VOLUME=' + shlex.quote(str(c.get('volume', 0.5))))
print('ACTIVE_PACK=' + shlex.quote(c.get('active_pack', 'peon')))
print('ANNOYED_THRESHOLD=' + shlex.quote(str(c.get('annoyed_threshold', 3))))
print('ANNOYED_WINDOW=' + shlex.quote(str(c.get('annoyed_window_seconds', 10))))
cats = c.get('categories', {})
for cat in ['greeting','acknowledge','complete','error','permission','resource_limit','annoyed']:
    print('CAT_' + cat.upper() + '=' + shlex.quote(str(cats.get(cat, True)).lower()))
" 2>/dev/null)"

[ "$ENABLED" = "false" ] && exit 0

PAUSED=false
[ -f "$PEON_DIR/.paused" ] && PAUSED=true

# --- Parse event fields (shlex.quote prevents shell injection) ---
eval "$(python3 -c "
import sys, json, shlex
d = json.load(sys.stdin)
print('EVENT=' + shlex.quote(d.get('hook_event_name', '')))
print('NTYPE=' + shlex.quote(d.get('notification_type', '')))
print('CWD=' + shlex.quote(d.get('cwd', '')))
print('SESSION_ID=' + shlex.quote(d.get('session_id', '')))
print('PERM_MODE=' + shlex.quote(d.get('permission_mode', '')))
" <<< "$INPUT" 2>/dev/null)"

# --- Detect agent/teammate sessions (suppress sounds for non-interactive sessions) ---
# Only truly autonomous modes are agents; interactive modes (default, acceptEdits, plan) are not.
# We track agent sessions by session_id because Notification events lack permission_mode.
AGENT_MODES="delegate"
IS_AGENT=$(python3 -c "
import json, os
state_file = '$STATE'
session_id = '$SESSION_ID'
perm_mode = '$PERM_MODE'
agent_modes = set('$AGENT_MODES'.split())
try:
    state = json.load(open(state_file))
except:
    state = {}
agent_sessions = set(state.get('agent_sessions', []))
if perm_mode and perm_mode in agent_modes:
    agent_sessions.add(session_id)
    state['agent_sessions'] = list(agent_sessions)
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    json.dump(state, open(state_file, 'w'))
    print('true')
elif session_id in agent_sessions:
    print('true')
else:
    print('false')
" 2>/dev/null)

[ "$IS_AGENT" = "true" ] && exit 0

PROJECT="${CWD##*/}"
[ -z "$PROJECT" ] && PROJECT="claude"
# Sanitize PROJECT for safe interpolation into AppleScript/notifications
PROJECT=$(printf '%s' "$PROJECT" | tr -cd '[:alnum:] ._-')

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
        "https://raw.githubusercontent.com/tonyyont/peon-ping/main/VERSION" 2>/dev/null | tr -d '[:space:]')
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
    echo "peon-ping update available: ${CUR_VER:-?} → $NEW_VER — run: curl -fsSL https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.sh | bash" >&2
  fi
fi

# --- Show pause status on SessionStart ---
if [ "$EVENT" = "SessionStart" ] && [ "$PAUSED" = "true" ]; then
  echo "peon-ping: sounds paused — run 'peon --resume' or '/peon-ping-toggle' to unpause" >&2
fi

# --- Check annoyed state (rapid prompts) ---
check_annoyed() {
  python3 -c "
import json, time, sys, os

state_file = '$STATE'
now = time.time()
window = float('$ANNOYED_WINDOW')
threshold = int('$ANNOYED_THRESHOLD')

try:
    state = json.load(open(state_file))
except:
    state = {}

timestamps = state.get('prompt_timestamps', [])
timestamps = [t for t in timestamps if now - t < window]
timestamps.append(now)

state['prompt_timestamps'] = timestamps
os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
json.dump(state, open(state_file, 'w'))

if len(timestamps) >= threshold:
    print('annoyed')
else:
    print('normal')
" 2>/dev/null
}

# --- Pick random sound from category, avoiding immediate repeats ---
pick_sound() {
  local category="$1"
  python3 -c "
import json, random, sys, os

pack_dir = '$PEON_DIR/packs/$ACTIVE_PACK'
manifest = json.load(open(os.path.join(pack_dir, 'manifest.json')))
state_file = '$STATE'

try:
    state = json.load(open(state_file))
except:
    state = {}

category = '$category'
sounds = manifest.get('categories', {}).get(category, {}).get('sounds', [])
if not sounds:
    sys.exit(1)

last_played = state.get('last_played', {})
last_file = last_played.get(category, '')

# Filter out last played (if more than one option)
candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s['file'] != last_file]
pick = random.choice(candidates)

# Update state
last_played[category] = pick['file']
state['last_played'] = last_played
json.dump(state, open(state_file, 'w'))

sound_path = os.path.join(pack_dir, 'sounds', pick['file'])
print(sound_path)
" 2>/dev/null
}

# --- Determine category and tab state ---
CATEGORY=""
STATUS=""
MARKER=""
NOTIFY=""
MSG=""

case "$EVENT" in
  SessionStart)
    CATEGORY="greeting"
    STATUS="ready"
    ;;
  UserPromptSubmit)
    # No sound normally — user just hit enter, they know.
    # Exception: annoyed easter egg fires if they're spamming prompts.
    if [ "$CAT_ANNOYED" = "true" ]; then
      MOOD=$(check_annoyed)
      if [ "$MOOD" = "annoyed" ]; then
        CATEGORY="annoyed"
      fi
    fi
    STATUS="working"
    ;;
  Stop)
    CATEGORY="complete"
    STATUS="done"
    MARKER="● "
    NOTIFY=1
    NOTIFY_COLOR="blue"
    MSG="$PROJECT  —  Task complete"
    ;;
  Notification)
    if [ "$NTYPE" = "permission_prompt" ]; then
      CATEGORY="permission"
      STATUS="needs approval"
      MARKER="● "
      NOTIFY=1
      NOTIFY_COLOR="red"
      MSG="$PROJECT  —  Permission needed"
    elif [ "$NTYPE" = "idle_prompt" ]; then
      # No sound — Stop already played the completion sound.
      STATUS="done"
      MARKER="● "
      NOTIFY=1
      NOTIFY_COLOR="yellow"
      MSG="$PROJECT  —  Waiting for input"
    else
      exit 0
    fi
    ;;
  PermissionRequest)
    CATEGORY="permission"
    STATUS="needs approval"
    MARKER="● "
    NOTIFY=1
    NOTIFY_COLOR="red"
    MSG="$PROJECT  —  A tool is waiting for your permission"
    ;;
  # PostToolUseFailure — no sound. Claude retries on its own.
  *)
    exit 0
    ;;
esac

# --- Check if category is enabled ---
CAT_VAR="CAT_$(echo "$CATEGORY" | tr '[:lower:]' '[:upper:]')"
CAT_ENABLED="${!CAT_VAR:-true}"
[ "$CAT_ENABLED" = "false" ] && CATEGORY=""

# --- Build tab title ---
TITLE="${MARKER}${PROJECT}: ${STATUS}"

# --- Set tab title via ANSI escape (works in Warp, iTerm2, Terminal.app, etc.) ---
if [ -n "$TITLE" ]; then
  printf '\033]0;%s\007' "$TITLE"
fi

# --- Play sound ---
if [ -n "$CATEGORY" ] && [ "$PAUSED" != "true" ]; then
  SOUND_FILE=$(pick_sound "$CATEGORY")
  if [ -n "$SOUND_FILE" ] && [ -f "$SOUND_FILE" ]; then
    play_sound "$SOUND_FILE" "$VOLUME"
  fi
fi

# --- Smart notification: only when terminal is NOT frontmost ---
if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ]; then
  if ! terminal_is_focused; then
    send_notification "$MSG" "$TITLE" "${NOTIFY_COLOR:-red}"
  fi
fi

wait
exit 0
