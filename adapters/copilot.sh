#!/bin/bash
# peon-ping adapter for GitHub Copilot
# Translates GitHub Copilot hook events into peon.sh stdin JSON
#
# Setup: Add to .github/hooks/hooks.json in your repository:
#   {
#     "version": 1,
#     "hooks": {
#       "sessionStart": [
#         { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh sessionStart" }
#       ],
#       "sessionEnd": [
#         { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh sessionEnd" }
#       ],
#       "userPromptSubmitted": [
#         { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh userPromptSubmitted" }
#       ],
#       "postToolUse": [
#         { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh postToolUse" }
#       ],
#       "errorOccurred": [
#         { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh errorOccurred" }
#       ]
#     }
#   }

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

COPILOT_EVENT="${1:-sessionStart}"

# Copilot sends JSON with session data on stdin (timestamp, cwd, sessionId, etc.)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && SESSION_ID="copilot-$$"
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null)
[ -z "$CWD" ] && CWD="${PWD}"

# Map Copilot hook events to peon.sh PascalCase events
case "$COPILOT_EVENT" in
  sessionStart)
    EVENT="SessionStart"
    ;;
  sessionEnd)
    # Session end — no sound (not yet mapped in peon.sh)
    exit 0
    ;;
  userPromptSubmitted)
    # Prompt submitted — SessionStart handles greeting, this handles spam detection
    SESSION_MARKER="$PEON_DIR/.copilot-session-${SESSION_ID}"
    find "$PEON_DIR" -name ".copilot-session-*" -mtime +0 -delete 2>/dev/null
    if [ ! -f "$SESSION_MARKER" ]; then
      touch "$SESSION_MARKER"
      EVENT="SessionStart"
    else
      EVENT="UserPromptSubmit"
    fi
    ;;
  preToolUse)
    # Before tool execution — skip (too noisy)
    exit 0
    ;;
  postToolUse)
    # After tool execution — treat as task completion
    EVENT="Stop"
    ;;
  errorOccurred)
    # Error occurred during session
    EVENT="TaskError"
    ;;
  *)
    # Unknown event — skip
    exit 0
    ;;
esac

echo "$INPUT" | jq --arg event "$EVENT" --arg sid "$SESSION_ID" --arg cwd "$CWD" \
  '{hook_event_name: $event, notification_type: "", cwd: $cwd, session_id: $sid, permission_mode: ""}' \
  | bash "$PEON_DIR/peon.sh"
