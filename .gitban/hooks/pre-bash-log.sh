#!/bin/bash
# PreToolUse hook: auto-logs every Bash tool call to the active agent JSONL log.
#
# Designed for agent frontmatter PreToolUse hooks on the "Bash" matcher.
# Reads the current log path from .gitban/agents/.active-log (written by
# agent_log_init or created by this script on first invocation).
#
# If no active log exists and AGENT_* environment variables are set, creates
# the log file automatically (bootstrapping without agent compliance).
# If neither sentinel nor env vars exist, exits silently (no-op).
#
# Appended entry format:
#   {"timestamp":"...","operation":"pre_cmd","command":"...","agent_id":"...","agent_type":"..."}
#
# Uses python for reliable JSON parsing (jq may not be available on Windows/MSYS2).
# Resolves paths via git common-dir to work correctly from worktrees.
#
# Performance: ~500ms on MSYS2/Windows (dominated by Python startup).
# Baseline noop script overhead is ~105ms on MSYS2. On Linux this will be faster.
# At 20-50 Bash calls/session, total overhead is 10-25s on 5-10min sessions (~3-8%).

# Resolve git root for the current working tree
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Main repo root (for venv and sentinel access from worktrees)
MAIN_REPO="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
MAIN_REPO="${MAIN_REPO%/.git}"
if [ -z "$MAIN_REPO" ]; then
  MAIN_REPO="$GIT_ROOT"
fi

SENTINEL="$MAIN_REPO/.gitban/agents/.active-log"

# Read stdin (Claude Code sends JSON with tool_input)
INPUT=$(cat)

# Determine log file path
LOG_FILE=""
if [ -f "$SENTINEL" ]; then
  LOG_FILE=$(cat "$SENTINEL")
fi

# If no sentinel, try to bootstrap from environment variables
if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
  if [ -n "$AGENT_SPRINT_TAG" ] && [ -n "$AGENT_CARD_ID" ] && [ -n "$AGENT_ROLE" ]; then
    CYCLE="${AGENT_CYCLE:-1}"
    LOG_DIR="$GIT_ROOT/.gitban/agents/${AGENT_ROLE}/logs"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$(cd "$LOG_DIR" && pwd)/${AGENT_SPRINT_TAG}-${AGENT_CARD_ID}-${AGENT_ROLE}-${CYCLE}.jsonl"

    # Write sentinel for subsequent invocations
    mkdir -p "$(dirname "$SENTINEL")"
    echo "$LOG_FILE" > "$SENTINEL"
  else
    # No sentinel and no env vars -- silent no-op
    exit 0
  fi
fi

# Find python: venv in worktree, venv in main repo, then system
PYTHON=""
for candidate in "$GIT_ROOT/.venv/Scripts/python.exe" "$GIT_ROOT/.venv/bin/python" "$MAIN_REPO/.venv/Scripts/python.exe" "$MAIN_REPO/.venv/bin/python" python3 python; do
  if [ -x "$candidate" ] 2>/dev/null || command -v "$candidate" &>/dev/null; then
    PYTHON="$candidate"
    break
  fi
done

if [ -z "$PYTHON" ]; then
  exit 0
fi

# Parse stdin and append pre_cmd entry
ENTRY=$("$PYTHON" -c "
import json, sys, datetime
try:
    data = json.loads(sys.argv[1])
    cmd = data.get('tool_input', {}).get('command', '')
    if not cmd:
        sys.exit(1)
    ts = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    entry = {'timestamp': ts, 'operation': 'pre_cmd', 'command': cmd}
    # Include agent identity if available (provided by Claude Code for subagents)
    agent_id = data.get('agent_id')
    agent_type = data.get('agent_type')
    if agent_id:
        entry['agent_id'] = agent_id
    if agent_type:
        entry['agent_type'] = agent_type
    print(json.dumps(entry, separators=(',', ':')))
except Exception:
    sys.exit(1)
" "$INPUT" 2>/dev/null) || exit 0

echo "$ENTRY" >> "$LOG_FILE"

exit 0
