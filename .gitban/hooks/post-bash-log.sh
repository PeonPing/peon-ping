#!/bin/bash
# PostToolUse hook: auto-logs every Bash tool call to the active agent JSONL log.
#
# Reads the current log path from .gitban/agents/.active-log (written by agent_log_init).
# If no active log exists, exits silently (no-op outside agent sessions).
#
# Appended entry format:
#   {"timestamp":"...","operation":"hook_cmd","command":"..."}
#
# This is the safety net — agents don't need to remember to wrap commands.
# Uses python from venv for reliable JSON parsing on Windows/MSYS2.
# Resolves paths via git root to work correctly from worktrees.

GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SENTINEL="$GIT_ROOT/.gitban/agents/.active-log"

if [ ! -f "$SENTINEL" ]; then
  exit 0
fi

LOG_FILE=$(cat "$SENTINEL")
if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
  exit 0
fi

INPUT=$(cat)

# Find python: venv first (relative to git root), then system
PYTHON=""
for candidate in "$GIT_ROOT/.venv/Scripts/python.exe" "$GIT_ROOT/.venv/bin/python" python3 python; do
  if command -v "$candidate" &>/dev/null || [ -x "$candidate" ]; then
    PYTHON="$candidate"
    break
  fi
done

if [ -z "$PYTHON" ]; then
  exit 0
fi

ENTRY=$("$PYTHON" -c "
import json, sys, datetime
try:
    data = json.loads(sys.argv[1])
    cmd = data.get('tool_input', {}).get('command', '')
    if not cmd:
        sys.exit(1)
    ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    print(json.dumps({'timestamp': ts, 'operation': 'hook_cmd', 'command': cmd}, separators=(',', ':')))
except Exception:
    sys.exit(1)
" "$INPUT" 2>/dev/null) || exit 0

echo "$ENTRY" >> "$LOG_FILE"

exit 0
