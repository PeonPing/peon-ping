#!/bin/bash
# copyright (c) 2026 Atlassian US, Inc.
# peon-ping adapter for Rovo Dev CLI (Atlassian)
# Translates Rovo Dev event hook names into peon.sh stdin JSON
#
# Rovo Dev CLI fires shell commands on agent lifecycle events.
# Unlike Claude Code / Kiro, events are not piped via stdin —
# the event name is passed as a CLI argument.
#
# Setup: Add to ~/.rovodev/config.yml:
#
#   eventHooks:
#     events:
#       - name: on_complete
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_complete
#       - name: on_error
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_error
#       - name: on_tool_permission
#         commands:
#           - command: bash ~/.claude/hooks/peon-ping/adapters/rovodev.sh on_tool_permission
#
# Note: Use absolute paths if ~ is not expanded in your environment.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
[ -d "$PEON_DIR" ] || PEON_DIR="$HOME/.openpeon"

if [ ! -f "$PEON_DIR/peon.sh" ]; then
  echo "peon-ping not installed. Run: brew install PeonPing/tap/peon-ping" >&2
  exit 1
fi

RD_EVENT="${1:-on_complete}"

# Map Rovo Dev CLI event names to peon.sh hook events
case "$RD_EVENT" in
  on_complete)
    EVENT="Stop"
    ;;
  on_error)
    EVENT="PostToolUseFailure"
    ;;
  on_tool_permission|on_permission_request)
    EVENT="PermissionRequest"
    ;;
  *)
    # Unknown event — exit silently
    exit 0
    ;;
esac

SESSION_ID="rovodev-${ROVODEV_SESSION_ID:-$$}"

# Build JSON and pipe to peon.sh
# peon.sh reads tool_name/error at the top level, so they must not be nested
TOOL_NAME=""
ERROR_MSG=""
[ "$EVENT" = "PostToolUseFailure" ] && TOOL_NAME="Bash" && ERROR_MSG="Agent error"

if command -v jq &>/dev/null; then
  jq -nc \
    --arg hook "$EVENT" \
    --arg cwd "$PWD" \
    --arg sid "$SESSION_ID" \
    --arg tn "$TOOL_NAME" \
    --arg err "$ERROR_MSG" \
    '{hook_event_name:$hook, cwd:$cwd, session_id:$sid, permission_mode:"", tool_name:$tn, error:$err}'
else
  printf '{"hook_event_name":"%s","cwd":"%s","session_id":"%s","permission_mode":"","tool_name":"%s","error":"%s"}\n' \
    "$EVENT" "$PWD" "$SESSION_ID" "$TOOL_NAME" "$ERROR_MSG"
fi | bash "$PEON_DIR/peon.sh"
