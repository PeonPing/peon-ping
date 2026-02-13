#!/bin/bash
# peon-ping adapter for Kiro CLI (Amazon)
# Translates Kiro hook events into peon.sh stdin JSON
#
# Kiro CLI has a hook system that pipes JSON to hooks via stdin,
# nearly identical to Claude Code. This adapter remaps the few
# differing event names and forwards to peon.sh.
#
# Setup: Create ~/.kiro/agents/peon-ping.json with:
#
#   {
#     "hooks": {
#       "agentSpawn": [
#         { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
#       ],
#       "userPromptSubmit": [
#         { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
#       ],
#       "stop": [
#         { "command": "bash ~/.claude/hooks/peon-ping/adapters/kiro.sh" }
#       ]
#     }
#   }
#
# Note: preToolUse and postToolUse are intentionally excluded — they
# fire on every tool call (not just permission prompts) and would be
# extremely noisy.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

# Read Kiro's event JSON from stdin and remap event names
MAPPED_JSON=$(python3 -c "
import sys, json, os

data = json.load(sys.stdin)
event = data.get('hook_event_name', 'stop')

# Kiro uses camelCase events; peon.sh expects PascalCase (Claude Code format)
remap = {
    'agentSpawn': 'SessionStart',
    'userPromptSubmit': 'UserPromptSubmit',
    'stop': 'Stop',
}

mapped = remap.get(event)
if mapped is None:
    # Unknown or intentionally skipped events (preToolUse, postToolUse)
    sys.exit(0)

sid = data.get('session_id', str(os.getpid()))
cwd = data.get('cwd', os.getcwd())

print(json.dumps({
    'hook_event_name': mapped,
    'notification_type': '',
    'cwd': cwd,
    'session_id': 'kiro-' + str(sid),
    'permission_mode': data.get('permission_mode', ''),
}))
")

# Only forward to peon.sh if python3 produced a mapped event
if [ -n "$MAPPED_JSON" ]; then
  echo "$MAPPED_JSON" | bash "$PEON_DIR/peon.sh"
fi
