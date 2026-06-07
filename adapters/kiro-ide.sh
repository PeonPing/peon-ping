#!/bin/bash
# peon-ping adapter for Kiro IDE (Amazon)
# Translates Kiro IDE agent-hook events into peon.sh stdin JSON.
#
# Kiro IDE is DISTINCT from the Kiro CLI (see adapters/kiro.sh). The IDE's
# Agent Hooks are `.kiro/hooks/*.kiro.hook` JSON files with a `when`/`then`
# shape; the `then.type: runCommand` action runs a shell command with NO
# stdin JSON — the triggering event name is passed to this adapter as an argv
# argument. (The CLI, by contrast, pipes camelCase JSON on stdin.)
#
# Setup: create one `.kiro/hooks/peon-ping-<event>.kiro.hook` per event, e.g.
# `.kiro/hooks/peon-ping-stop.kiro.hook`:
#   {
#     "version": "1.0.0",
#     "enabled": true,
#     "name": "peon-ping-stop",
#     "when": { "type": "agentStop" },
#     "then": {
#       "type": "runCommand",
#       "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro-ide.sh agentStop"
#     }
#   }
# Repeat with when.type = promptSubmit / preToolUse and a matching command arg.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
[ -f "$PEON_DIR/peon.sh" ] || PEON_DIR="$HOME/.openpeon/hooks/peon-ping"
[ -f "$PEON_DIR/peon.sh" ] || exit 0

KIRO_EVENT="${1:-agentStop}"

# Map Kiro IDE when.type values (passed as argv) to CESP events. postToolUse,
# file*, and userTriggered carry no peon-relevant signal (runCommand has no
# payload), so they exit silently.
case "$KIRO_EVENT" in
  agentStop|stop)                 EVENT="Stop" ;;
  promptSubmit|userPromptSubmit)  EVENT="UserPromptSubmit" ;;
  preToolUse|on_tool_permission)  EVENT="PermissionRequest" ;;
  sessionStart|agentSpawn|start)  EVENT="SessionStart" ;;
  *)                              exit 0 ;;
esac

# Kiro IDE provides no session id to runCommand; key off an optional env var,
# else the PID. Distinct `kiro-ide-` prefix from the CLI adapter's `kiro-`.
SESSION_ID="kiro-ide-${KIRO_IDE_SESSION_ID:-$$}"

if command -v python3 &>/dev/null; then
  _PE="$EVENT" _PS="$SESSION_ID" _PC="$PWD" python3 -c "
import json, os
print(json.dumps({
    'hook_event_name': os.environ['_PE'],
    'notification_type': '',
    'cwd': os.environ['_PC'],
    'session_id': os.environ['_PS'],
    'permission_mode': '',
}))
" | bash "$PEON_DIR/peon.sh"
else
  printf '{"hook_event_name":"%s","notification_type":"","cwd":"%s","session_id":"%s","permission_mode":""}\n' \
    "$EVENT" "$PWD" "$SESSION_ID" | bash "$PEON_DIR/peon.sh"
fi
