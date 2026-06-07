#!/bin/bash
# peon-ping adapter for iFlow CLI (iflow-ai/iflow-cli, cli.iflow.cn)
# Translates iFlow hook events into peon.sh stdin JSON.
#
# iFlow CLI ships a Claude-Code-style hook system: events are piped to the
# hook command as JSON on stdin using PascalCase names (SessionStart,
# UserPromptSubmit, Stop, SubagentStop, SessionEnd, PreToolUse, PostToolUse,
# Notification, SetUpEnvironment). This adapter forwards the meaningful
# lifecycle events to peon.sh with an `iflow-` session prefix, mapping a
# failed PostToolUse to PostToolUseFailure and dropping the noisy rest.
#
# Setup: add to ~/.iflow/settings.json (user) or ./.iflow/settings.json:
#
#   {
#     "hooks": {
#       "SessionStart":     [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/iflow.sh" }] }],
#       "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/iflow.sh" }] }],
#       "Stop":             [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/iflow.sh" }] }],
#       "Notification":     [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/iflow.sh" }] }],
#       "PostToolUse":      [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/iflow.sh" }] }],
#       "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/iflow.sh" }] }]
#     }
#   }

set -euo pipefail

# PEON_DIR resolution: explicit override → BASH_SOURCE-relative → global install.
PEON_DIR="${CLAUDE_PEON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -f "$PEON_DIR/peon.sh" ] || PEON_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping"
[ -f "$PEON_DIR/peon.sh" ] || exit 0

# iFlow pipes its event JSON on stdin. Forward the lifecycle events; map a
# failed PostToolUse to PostToolUseFailure; drop the noisy success-path events.
MAPPED_JSON=$(python3 -c "
import sys, json, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)

event = str(data.get('hook_event_name', '')).strip()

# Pass these CESP PascalCase events straight through.
passthrough = {'SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'SessionEnd'}

mapped = None
if event in passthrough:
    mapped = event
elif event == 'PostToolUse':
    # iFlow has no dedicated failure event; surface only failed tool calls.
    failed = False
    try:
        ec = data.get('exit_code', data.get('exitCode'))
        if ec is not None and int(ec) != 0:
            failed = True
    except Exception:
        pass
    if str(data.get('success', '')).lower() == 'false':
        failed = True
    if data.get('error') or data.get('stderr'):
        failed = True
    if not failed:
        sys.exit(0)
    mapped = 'PostToolUseFailure'
else:
    sys.exit(0)

sid = str(data.get('session_id') or os.getpid())
payload = {
    'hook_event_name': mapped,
    'notification_type': data.get('notification_type', ''),
    'cwd': data.get('cwd') or os.getcwd(),
    'session_id': 'iflow-' + sid,
    'permission_mode': data.get('permission_mode', ''),
}
if mapped == 'PostToolUseFailure':
    payload['tool_name'] = data.get('tool_name') or 'Bash'
    payload['error'] = data.get('error') or data.get('stderr') or 'Tool failed'
print(json.dumps(payload))
" 2>/dev/null) || exit 0

if [ -n "$MAPPED_JSON" ]; then
  echo "$MAPPED_JSON" | bash "$PEON_DIR/peon.sh"
fi
