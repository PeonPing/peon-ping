#!/bin/bash
# peon-ping adapter for Cursor IDE
# Translates Cursor hook events into peon.sh stdin JSON
#
# Setup: Add to ~/.cursor/hooks.json:
#   {
#     "hooks": [
#       {
#         "event": "stop",
#         "command": "bash ~/.claude/hooks/peon-ping/adapters/cursor.sh stop"
#       },
#       {
#         "event": "beforeShellExecution",
#         "command": "bash ~/.claude/hooks/peon-ping/adapters/cursor.sh beforeShellExecution"
#       }
#     ]
#   }

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

CURSOR_EVENT="${1:-stop}"

case "$CURSOR_EVENT" in
  stop)
    EVENT="Stop"
    ;;
  beforeShellExecution)
    EVENT="UserPromptSubmit"
    ;;
  beforeMCPExecution)
    EVENT="UserPromptSubmit"
    ;;
  afterFileEdit)
    EVENT="Stop"
    ;;
  beforeReadFile)
    # Too noisy — skip
    exit 0
    ;;
  *)
    EVENT="Stop"
    ;;
esac

SESSION_ID="cursor-${CURSOR_SESSION_ID:-$$}"
CWD="${PWD}"

echo "{\"hook_event_name\":\"$EVENT\",\"notification_type\":\"\",\"cwd\":\"$CWD\",\"session_id\":\"$SESSION_ID\",\"permission_mode\":\"\"}" \
  | bash "$PEON_DIR/peon.sh"
