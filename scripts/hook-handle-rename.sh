#!/bin/bash
# UserPromptSubmit hook for /peon-ping-rename command
# Intercepts `/peon-ping-rename <name>` before it reaches the LLM
set -euo pipefail

INPUT=$(cat)
LOG_FILE="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping/hook-handle-rename.log"
LOG_FALLBACK="${TMPDIR:-/tmp}/peon-ping-hook.log"
log() {
  local line="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$line" >> "$LOG_FILE" 2>/dev/null || echo "$line" >> "$LOG_FALLBACK" 2>/dev/null || true
}

log "invoked stdin_len=${#INPUT}"

# Try to parse session ID from conversation_id (Cursor) or session_id (Claude Code)
SESSION_ID=$(echo "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    session = data.get("conversation_id") or data.get("session_id") or "default"
    print(session)
except:
    print("default")
' 2>/dev/null || echo "default")

# Capture PPID — Claude Code's process PID, stable across /clear (process continues, session_id changes).
# Different terminal tabs spawn separate Claude Code processes → different PPIDs → no cross-tab bleed.
HOOK_PPID="${PPID:-}"

# Extract CWD from event JSON — combined with PPID for a composite key that isolates by process+project
HOOK_CWD=$(echo "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    cwd = data.get("cwd", "") or ""
    roots = data.get("workspace_roots", [])
    print(cwd or (roots[0] if roots else ""))
except:
    pass
' 2>/dev/null || echo "")

# Composite key: ppid::cwd (ppid for per-process isolation, cwd for project-level safety net)
HOOK_PPID_KEY="${HOOK_PPID}${HOOK_CWD:+::${HOOK_CWD}}"

# Extract prompt text
PROMPT=$(echo "$INPUT" | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get("prompt", ""))
except:
    pass
' 2>/dev/null || echo "")

# Check if this is a /peon-ping-rename command
if ! echo "$PROMPT" | grep -qE '^\s*/peon-ping-rename(\s+.*)?$'; then
  log "passthrough: not_our_cmd prompt_preview=${PROMPT:0:80}..."
  echo '{"continue": true}'
  exit 0
fi

# Extract name (everything after the command, trimmed)
SESSION_NAME=$(echo "$PROMPT" | sed -E 's/^[[:space:]]*\/peon-ping-rename[[:space:]]*//' | sed -E 's/^[[:space:]]+|[[:space:]]+$//')
log "matched name='$SESSION_NAME' sessionId=$SESSION_ID"

# Sanitize session ID
if ! echo "$SESSION_ID" | grep -qE '^[a-zA-Z0-9_-]+$'; then
  log "sanitize: invalid session_id charset, using default"
  SESSION_ID="default"
fi

# Locate peon-ping installation
PEON_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping"
if [ ! -d "$PEON_DIR" ]; then
  PEON_DIR="$HOME/.cursor/hooks/peon-ping"
fi
if [ ! -d "$PEON_DIR" ]; then
  log "error: peon-ping not installed"
  echo '{"continue": false, "user_message": "[X] peon-ping not installed"}'
  exit 0
fi

STATE="$PEON_DIR/.state.json"

# Clear name if called with no argument (reset to auto-detect)
if [ -z "$SESSION_NAME" ]; then
  export PEON_ENV_STATE="$STATE" PEON_ENV_SESSION_ID="$SESSION_ID" PEON_ENV_HOOK_PPID_KEY="$HOOK_PPID_KEY"
  python3 -c "
import json, os

state_path = os.environ.get('PEON_ENV_STATE', '')
session_id = os.environ.get('PEON_ENV_SESSION_ID', '')
hook_ppid_key = os.environ.get('PEON_ENV_HOOK_PPID_KEY', '')

try:
    with open(state_path) as f:
        state = json.load(f)
except:
    state = {}

if 'session_names' in state and session_id in state['session_names']:
    del state['session_names'][session_id]
if hook_ppid_key and 'tty_names' in state and hook_ppid_key in state['tty_names']:
    del state['tty_names'][hook_ppid_key]
with open(state_path, 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"
  log "cleared name sessionId=$SESSION_ID ppid_key=$HOOK_PPID_KEY"
  echo '{"continue": false, "user_message": "Session name cleared (auto-detect resumed)"}'
  exit 0
fi

# Clamp to 50 chars and sanitize (same charset as peon.sh project name)
SESSION_NAME=$(echo "$SESSION_NAME" | cut -c1-50 | tr -dc 'a-zA-Z0-9 ._-')
if [ -z "$SESSION_NAME" ]; then
  log "reject: name empty after sanitization"
  echo '{"continue": false, "user_message": "[X] Invalid name (use letters, numbers, spaces, dots, hyphens, underscores)"}'
  exit 0
fi

# Write session name to .state.json (by session_id AND ppid::cwd for cross-clear-context persistence)
export PEON_ENV_STATE="$STATE" PEON_ENV_SESSION_ID="$SESSION_ID" PEON_ENV_SESSION_NAME="$SESSION_NAME" PEON_ENV_HOOK_PPID_KEY="$HOOK_PPID_KEY"
python3 -c "
import json, os

state_path = os.environ.get('PEON_ENV_STATE', '')
session_id = os.environ.get('PEON_ENV_SESSION_ID', '')
session_name = os.environ.get('PEON_ENV_SESSION_NAME', '')
hook_ppid_key = os.environ.get('PEON_ENV_HOOK_PPID_KEY', '')

try:
    with open(state_path) as f:
        state = json.load(f)
except:
    state = {}

if 'session_names' not in state:
    state['session_names'] = {}
state['session_names'][session_id] = session_name

# Also store by ppid::cwd composite key so the name survives /clear (which generates a new session_id)
# PPID isolates per Claude Code process; different terminal tabs have different PPIDs
if hook_ppid_key:
    if 'tty_names' not in state:
        state['tty_names'] = {}
    state['tty_names'][hook_ppid_key] = session_name

with open(state_path, 'w') as f:
    json.dump(state, f, indent=2)
    f.write('\n')
"

# Immediately update tab title via ANSI escape (peon.sh will keep it updated on future events)
printf '\033]0;%s\007' "• ${SESSION_NAME}: ready" > /dev/tty 2>/dev/null || true

log "success name='$SESSION_NAME' sessionId=$SESSION_ID ppid_key=$HOOK_PPID_KEY"
echo "{\"continue\": false, \"user_message\": \"Session renamed to \\\"${SESSION_NAME}\\\"\"}"
exit 0
