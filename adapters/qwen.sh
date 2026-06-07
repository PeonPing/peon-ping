#!/bin/bash
# peon-ping adapter for Qwen Code CLI (QwenLM/qwen-code)
# Translates Qwen Code hook events into peon.sh stdin JSON.
#
# Qwen Code ships a Claude-Code-style hook system: events are piped to the
# hook command as JSON on stdin, and the event vocabulary already matches
# peon.sh's PascalCase CESP names (SessionStart, UserPromptSubmit, Stop,
# Notification, PostToolUseFailure, PermissionRequest, SessionEnd, ...).
# This adapter is a thin passthrough that re-tags the session id with a
# `qwen-` prefix and drops the noisy per-tool-call events, forwarding the
# rest to peon.sh unchanged.
#
# Setup: add to ~/.qwen/settings.json:
#
#   {
#     "hooks": {
#       "SessionStart":       [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/qwen.sh" }] }],
#       "UserPromptSubmit":   [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/qwen.sh" }] }],
#       "Stop":               [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/qwen.sh" }] }],
#       "Notification":       [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/qwen.sh" }] }],
#       "PostToolUseFailure": [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/qwen.sh" }] }],
#       "SessionEnd":         [{ "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/peon-ping/adapters/qwen.sh" }] }]
#     }
#   }

set -euo pipefail

# PEON_DIR resolution: explicit override → BASH_SOURCE-relative → global install.
PEON_DIR="${CLAUDE_PEON_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -f "$PEON_DIR/peon.sh" ] || PEON_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping"
[ -f "$PEON_DIR/peon.sh" ] || exit 0

# Qwen Code pipes its event JSON on stdin. Re-tag the session id and forward
# the allowlisted CESP events; drop noisy success-path tool events.
MAPPED_JSON=$(python3 -c "
import sys, json, os

try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)
if not isinstance(data, dict):
    sys.exit(0)

event = str(data.get('hook_event_name', '')).strip()

# Qwen already emits PascalCase CESP events; forward an allowlist as-is and
# drop the noisy success-path tool events (PreToolUse/PostToolUse) plus
# subagent/compaction chatter so peon-ping only speaks on meaningful moments.
allow = {
    'SessionStart', 'UserPromptSubmit', 'Stop', 'Notification',
    'PostToolUseFailure', 'PermissionRequest', 'SessionEnd',
}
if event not in allow:
    sys.exit(0)

sid = str(data.get('session_id') or os.getpid())
payload = {
    'hook_event_name': event,
    'notification_type': data.get('notification_type', ''),
    'cwd': data.get('cwd') or os.getcwd(),
    'session_id': 'qwen-' + sid,
    'permission_mode': data.get('permission_mode', ''),
}
if event == 'PostToolUseFailure':
    payload['tool_name'] = data.get('tool_name') or 'Bash'
    payload['error'] = data.get('error') or data.get('stderr') or 'Tool failed'
print(json.dumps(payload))
" 2>/dev/null) || exit 0

# Only forward to peon.sh if python3 produced a mapped event.
if [ -n "$MAPPED_JSON" ]; then
  echo "$MAPPED_JSON" | bash "$PEON_DIR/peon.sh"
fi
