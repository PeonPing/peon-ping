#!/bin/bash
# peon-ping adapter for Windsurf IDE (Cascade hooks)
# Translates Windsurf hook events into peon.sh stdin JSON
#
# Setup: Add to ~/.codeium/windsurf/hooks.json (see README for full hooks.json):
#   {
#     "hooks": {
#       "post_cascade_response": [
#         { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh post_cascade_response", "show_output": false }
#       ],
#       "pre_user_prompt": [
#         { "command": "bash ~/.claude/hooks/peon-ping/adapters/windsurf.sh pre_user_prompt", "show_output": false }
#       ]
#     }
#   }

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

WINDSURF_EVENT="${1:-post_cascade_response}"

# Drain stdin (Windsurf sends JSON context we don't need)
cat > /dev/null

# Map Windsurf hook events to peon.sh PascalCase events
case "$WINDSURF_EVENT" in
  post_cascade_response)
    EVENT="Stop"
    ;;
  pre_user_prompt)
    # First prompt in a session → SessionStart (greeting); subsequent → UserPromptSubmit (spam detection)
    SESSION_MARKER="$PEON_DIR/.windsurf-session-${PPID:-$$}"
    find "$PEON_DIR" -name ".windsurf-session-*" -mtime +0 -delete 2>/dev/null
    if [ ! -f "$SESSION_MARKER" ]; then
      touch "$SESSION_MARKER"
      EVENT="SessionStart"
    else
      EVENT="UserPromptSubmit"
    fi
    ;;
  post_write_code)
    EVENT="Stop"
    ;;
  post_run_command)
    EVENT="Stop"
    ;;
  *)
    # Unknown event — skip
    exit 0
    ;;
esac

SESSION_ID="windsurf-${PPID:-$$}"
CWD="${PWD}"

_PE="$EVENT" _PC="$CWD" _PS="$SESSION_ID" python3 -c "
import json, os
print(json.dumps({
    'hook_event_name': os.environ['_PE'],
    'notification_type': '',
    'cwd': os.environ['_PC'],
    'session_id': os.environ['_PS'],
    'permission_mode': '',
}))
" | bash "$PEON_DIR/peon.sh"
