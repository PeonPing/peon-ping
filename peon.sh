#!/bin/bash
# peon-ping: Warcraft III Peon voice lines for Claude Code hooks
# Replaces notify.sh — handles sounds, tab titles, and notifications
set -uo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-$HOME/.claude/hooks/peon-ping}"
CONFIG="$PEON_DIR/config.json"
STATE="$PEON_DIR/.state.json"

INPUT=$(cat)

# Debug log (comment out for quiet operation)
# echo "$(date): peon hook — $INPUT" >> /tmp/peon-ping-debug.log

# --- Load config (shlex.quote prevents shell injection) ---
eval "$(/usr/bin/python3 -c "
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

# --- Parse event fields (shlex.quote prevents shell injection) ---
eval "$(/usr/bin/python3 -c "
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
IS_AGENT=$(/usr/bin/python3 -c "
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

# --- Check annoyed state (rapid prompts) ---
check_annoyed() {
  /usr/bin/python3 -c "
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
  /usr/bin/python3 -c "
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
    ;;
  Notification)
    if [ "$NTYPE" = "permission_prompt" ]; then
      CATEGORY="permission"
      STATUS="needs approval"
      MARKER="● "
      NOTIFY=1
      MSG="$PROJECT — A tool is waiting for your permission"
    elif [ "$NTYPE" = "idle_prompt" ]; then
      # No sound — Stop already played the completion sound.
      STATUS="done"
      MARKER="● "
      NOTIFY=1
      MSG="$PROJECT — Ready for your next instruction"
    else
      exit 0
    fi
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
if [ -n "$CATEGORY" ]; then
  SOUND_FILE=$(pick_sound "$CATEGORY")
  if [ -n "$SOUND_FILE" ] && [ -f "$SOUND_FILE" ]; then
    nohup afplay -v "$VOLUME" "$SOUND_FILE" >/dev/null 2>&1 &
  fi
fi

# --- Smart notification: only when terminal is NOT frontmost ---
if [ -n "$NOTIFY" ]; then
  FRONTMOST=$(osascript -e 'tell application "System Events" to get name of first process whose frontmost is true' 2>/dev/null)
  case "$FRONTMOST" in
    Terminal|iTerm2|Warp|Alacritty|kitty|WezTerm|Ghostty) ;; # terminal is focused, skip notification
    *)
      nohup osascript - "$MSG" "$TITLE" >/dev/null 2>&1 <<'APPLESCRIPT' &
on run argv
  display notification (item 1 of argv) with title (item 2 of argv)
end run
APPLESCRIPT
      ;;
  esac
fi

wait
exit 0
