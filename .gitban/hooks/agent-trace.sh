#!/bin/bash
# PreToolUse hook: logs every tool call to a per-agent trace file.
# Wire this into agent frontmatter on matcher "*" to capture all tool activity.
#
# Log location: .gitban/agents/traces/{agent_type}-{agent_id}.jsonl
# Falls back to: .gitban/agents/traces/session-{date}.jsonl
#
# Each line is a JSON object with: timestamp, tool_name, tool_input (truncated)
#
# Set AGENT_TRACE=0 to disable tracing entirely.
# Set AGENT_TRACE_VERBOSE=1 to log full tool_input (no truncation).
# Default: tracing on, values truncated to 200 chars.

if [ "${AGENT_TRACE:-1}" = "0" ]; then
  exit 0
fi

INPUT=$(cat)

# Resolve git root (works from worktrees too)
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MAIN_REPO="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
MAIN_REPO="${MAIN_REPO%/.git}"
if [ -z "$MAIN_REPO" ]; then
  MAIN_REPO="$GIT_ROOT"
fi

TRACE_DIR="$MAIN_REPO/.gitban/agents/traces"
mkdir -p "$TRACE_DIR"

VERBOSE="${AGENT_TRACE_VERBOSE:-0}"

# Find python
PYTHON=""
for candidate in "$MAIN_REPO/.venv/Scripts/python.exe" "$MAIN_REPO/.venv/bin/python" "$GIT_ROOT/.venv/Scripts/python.exe" "$GIT_ROOT/.venv/bin/python" python3 python; do
  if [ -x "$candidate" ] 2>/dev/null || command -v "$candidate" &>/dev/null; then
    PYTHON="$candidate"
    break
  fi
done

if [ -z "$PYTHON" ]; then
  exit 0
fi

"$PYTHON" -c "
import json, sys, datetime, os

try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)

verbose = sys.argv[3] == '1'
tool_name = data.get('tool_name', 'unknown')
tool_input = data.get('tool_input', {})
agent_id = data.get('agent_id', '')
agent_type = data.get('agent_type', '')
ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

# Build summary of tool_input
if verbose:
    summary = {k: str(v) for k, v in tool_input.items()}
else:
    summary = {}
    for k, v in tool_input.items():
        s = str(v)
        if len(s) > 200:
            s = s[:200] + '...'
        summary[k] = s

# Determine log filename
if agent_type and agent_id:
    short_id = agent_id[:8] if len(agent_id) > 8 else agent_id
    filename = f'{agent_type}-{short_id}.jsonl'
else:
    filename = f'session-{ts[:10]}.jsonl'

trace_dir = sys.argv[2]
filepath = os.path.join(trace_dir, filename)

entry = {
    'ts': ts,
    'tool': tool_name,
    'input': summary,
}
if agent_id:
    entry['agent_id'] = agent_id[:8]
if agent_type:
    entry['agent_type'] = agent_type

with open(filepath, 'a', encoding='utf-8') as f:
    f.write(json.dumps(entry, separators=(',', ':')) + '\n')
" "$INPUT" "$TRACE_DIR" "$VERBOSE" 2>/dev/null

exit 0
