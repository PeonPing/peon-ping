#!/bin/bash
# peon-ping adapter for ECA (Editor Code Assistant, eca.dev)
# Translates ECA hook events into peon.sh stdin JSON.
#
# ECA is an editor-agnostic LLM-agent integration. Its hooks pipe JSON on
# stdin (top-level keys snake_case) and fire on these types:
#   sessionStart / sessionEnd / chatStart / chatEnd / preRequest /
#   postRequest / subagentPostRequest / preToolCall / postToolCall.
# This adapter maps them to CESP with an `eca-` session prefix derived from
# the ECA db_cache_path (stable per session), and pipes to peon.sh.
#
# Originally contributed in PeonPing/peon-ping#261; vendored first-party here
# with thanks to the original author.
#
# Setup: add a shell hook to your ECA config pointing at this script, e.g.:
#   { "hooks": { "sessionStart": [ { "actions": [ { "type": "shell",
#     "command": "bash ~/.claude/hooks/peon-ping/adapters/eca.sh sessionStart" } ] } ] } }
# The hook type may arrive as an argv argument and/or a `type` field on stdin.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
[ -f "$PEON_DIR/peon.sh" ] || PEON_DIR="$HOME/.openpeon/hooks/peon-ping"
[ -f "$PEON_DIR/peon.sh" ] || exit 0

MAPPED_JSON=$(_ECA_TYPE="${1:-}" python3 -c "
import sys, json, os, re

try:
    data = json.load(sys.stdin)
except Exception:
    data = {}
if not isinstance(data, dict):
    data = {}

# Hook type: argv first, then a stdin field (top-level keys are snake_case,
# but the type *value* is ECA's camelCase hook name).
etype = (os.environ.get('_ECA_TYPE', '').strip()
         or str(data.get('type') or data.get('hook_type') or data.get('hook_event_name') or '').strip())

type_map = {
    'sessionStart': 'SessionStart',
    'sessionEnd': 'SessionEnd',
    'chatStart': 'SessionStart',
    'preRequest': 'UserPromptSubmit',
    'postRequest': 'Stop',
    'subagentPostRequest': 'Stop',
    'preToolCall': 'PermissionRequest',
    'postToolCall': 'Stop',
}
mapped = type_map.get(etype)
if mapped is None:
    sys.exit(0)

# Stable session id from db_cache_path; else session_id; else PID.
dbp = str(data.get('db_cache_path') or data.get('session_id') or '').strip()
if dbp:
    sid = re.sub(r'[^A-Za-z0-9._:-]', '-', dbp).strip('-')[-60:]
else:
    sid = str(os.getpid())
if not sid:
    sid = str(os.getpid())

payload = {
    'hook_event_name': mapped,
    'notification_type': data.get('notification_type', ''),
    'cwd': data.get('cwd') or data.get('workspace_root') or os.getcwd(),
    'session_id': 'eca-' + sid,
    'permission_mode': data.get('permission_mode', ''),
}
print(json.dumps(payload))
" 2>/dev/null) || exit 0

if [ -n "$MAPPED_JSON" ]; then
  echo "$MAPPED_JSON" | bash "$PEON_DIR/peon.sh"
fi
