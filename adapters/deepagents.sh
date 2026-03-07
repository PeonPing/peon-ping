#!/bin/bash
# peon-ping adapter for deepagents-cli
# Translates deepagents hook events into peon.sh stdin JSON
#
# deepagents-cli pipes JSON with an "event" field (dotted names like
# "session.start") and an optional "thread_id".  This adapter remaps
# to Claude Code PascalCase event names and forwards to peon.sh.
#
# Setup: Add to ~/.deepagents/hooks.json:
#   {
#     "hooks": [
#       {
#         "command": ["bash", "/absolute/path/to/.claude/hooks/peon-ping/adapters/deepagents.sh"],
#         "events": ["session.start", "session.end", "task.complete", "input.required", "task.error", "tool.error", "user.prompt", "permission.request", "compact"]
#       }
#     ]
#   }
#
# Note: tool.call is intentionally excluded — it fires on every tool
# invocation and would be extremely noisy.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

# Read JSON payload from stdin, map event to CESP, and forward to peon.sh
MAPPED_JSON=$(python3 -c "
import sys, json, os

data = json.load(sys.stdin)
event = data.get('event')
if not event:
    sys.exit(0)

# deepagents event → (PascalCase hook event, notification_type)
remap = {
    'session.start':      ('SessionStart',      ''),
    'session.end':        ('SessionEnd',        ''),
    'task.complete':      ('Stop',              ''),
    'input.required':     ('Notification',      'permission_prompt'),
    'task.error':         ('Stop',              ''),
    'tool.error':         ('Notification',      'postToolUseFailure'),
    'user.prompt':        ('UserPromptSubmit',  ''),
    'permission.request': ('PermissionRequest', ''),
    'compact':            ('Notification',      'preCompact'),
}

mapped = remap.get(event)
if mapped is None:
    # Unknown or intentionally skipped events (tool.call)
    sys.exit(0)

tid = data.get('thread_id', str(os.getpid()))

print(json.dumps({
    'hook_event_name':  mapped[0],
    'notification_type': mapped[1],
    'cwd':              os.getcwd(),
    'session_id':       'deepagents-' + str(tid),
    'permission_mode':  '',
}))
")

# Forward to peon.sh only if python3 produced a mapped event
if [ -n "$MAPPED_JSON" ]; then
  echo "$MAPPED_JSON" | bash "$PEON_DIR/peon.sh"
fi
