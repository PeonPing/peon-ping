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
PLATFORM="${PEON_PLATFORM:-$(detect_platform)}"

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
    linux)
      if command -v pw-play &>/dev/null; then
        nohup pw-play --volume "$vol" "$file" >/dev/null 2>&1 &
      elif command -v paplay &>/dev/null; then
        local pa_vol
        pa_vol=$(python3 -c "print(int(float('$vol') * 65536))")
        nohup paplay --volume "$pa_vol" "$file" >/dev/null 2>&1 &
      fi
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
    linux)
      if command -v notify-send &>/dev/null; then
        local urgency="normal"
        case "$color" in
          red)    urgency="normal" ;;
          yellow) urgency="low" ;;
          blue)   urgency="low" ;;
        esac
        nohup notify-send --urgency="$urgency" "$title" "$msg" >/dev/null 2>&1 &
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
active_pack = cfg.get('active_pack', 'peon')
pack_rotation = cfg.get('pack_rotation', [])
annoyed_threshold = int(cfg.get('annoyed_threshold', 3))
annoyed_window = float(cfg.get('annoyed_window_seconds', 10))
cats = cfg.get('categories', {})
cat_enabled = {}
for c in ['greeting','acknowledge','complete','error','permission','resource_limit','annoyed']:
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

# --- Pack rotation: pin a random pack per session ---
if pack_rotation:
    session_packs = state.get('session_packs', {})
    if session_id in session_packs and session_packs[session_id] in pack_rotation:
        active_pack = session_packs[session_id]
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
    category = 'greeting'
    status = 'ready'
elif event == 'UserPromptSubmit':
    status = 'working'
    if cat_enabled.get('annoyed', True):
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
            category = 'annoyed'
elif event == 'Stop':
    category = 'complete'
    status = 'done'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'blue'
    msg = project + '  \u2014  Task complete'
elif event == 'Notification':
    if ntype == 'permission_prompt':
        category = 'permission'
        status = 'needs approval'
        marker = '\u25cf '
        notify = '1'
        notify_color = 'red'
        msg = project + '  \u2014  Permission needed'
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
    category = 'permission'
    status = 'needs approval'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'red'
    msg = project + '  \u2014  Permission needed'
else:
    # Unknown event (e.g. PostToolUseFailure) — exit cleanly
    print('PEON_EXIT=true')
    sys.exit(0)

# --- Check if category is enabled ---
if category and not cat_enabled.get(category, True):
    category = ''

# --- Pick sound (skip if no category or paused) ---
sound_file = ''
if category and not paused:
    pack_dir = os.path.join(peon_dir, 'packs', active_pack)
    try:
        manifest = json.load(open(os.path.join(pack_dir, 'manifest.json')))
        sounds = manifest.get('categories', {}).get(category, {}).get('sounds', [])
        if sounds:
            last_played = state.get('last_played', {})
            last_file = last_played.get(category, '')
            candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s['file'] != last_file]
            pick = random.choice(candidates)
            last_played[category] = pick['file']
            state['last_played'] = last_played
            state_dirty = True
            sound_file = os.path.join(pack_dir, 'sounds', pick['file'])
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
if [ -n "$NOTIFY" ] && [ "$PAUSED" != "true" ]; then
  if ! terminal_is_focused; then
    send_notification "$MSG" "$TITLE" "${NOTIFY_COLOR:-red}"
  fi
fi

wait
exit 0
