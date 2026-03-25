#!/bin/bash
# Agent watchdog: monitors trace files for staleness and writes marker files.
#
# Usage:
#   bash scripts/agent-watchdog.sh <agent_id_prefix> [timeout_seconds] [poll_seconds]
#
# The watchdog monitors .gitban/agents/traces/ for JSONL files matching the
# agent_id_prefix. If no new lines are appended within timeout_seconds, it
# writes a stale marker file that the dispatcher can check.
#
# Arguments:
#   agent_id_prefix  - Partial match for the trace filename (e.g. "executor-a7f22aef")
#   timeout_seconds  - Seconds of inactivity before marking stale (default: 300 = 5 min)
#   poll_seconds     - How often to check (default: 30)
#
# Outputs:
#   .gitban/agents/traces/{matched_file}.stale  - Written when agent appears hung
#   .gitban/agents/traces/{matched_file}.alive  - Removed when stale, written when active
#
# The dispatcher checks for .stale files to detect hung agents.
# Kill this watchdog when the agent completes (it exits cleanly on SIGTERM).

set -euo pipefail

AGENT_PREFIX="${1:?Usage: agent-watchdog.sh <agent_id_prefix> [timeout_seconds] [poll_seconds]}"
TIMEOUT_SECS="${2:-300}"
POLL_SECS="${3:-30}"

# Resolve repo root (works from worktrees)
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MAIN_REPO="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
MAIN_REPO="${MAIN_REPO%/.git}"
if [ -z "$MAIN_REPO" ]; then
  MAIN_REPO="$GIT_ROOT"
fi

TRACE_DIR="$MAIN_REPO/.gitban/agents/traces"

# Clean exit on SIGTERM
cleanup() {
  # Remove alive marker if we created one
  if [ -n "${TRACE_FILE:-}" ] && [ -f "${TRACE_FILE}.alive" ]; then
    rm -f "${TRACE_FILE}.alive"
  fi
  exit 0
}
trap cleanup SIGTERM SIGINT

# Wait for the trace file to appear (agent may not have started yet)
TRACE_FILE=""
WAIT_COUNT=0
MAX_WAIT=60  # seconds to wait for trace file to appear

while [ -z "$TRACE_FILE" ]; do
  # Find the newest matching trace file
  MATCH=$(find "$TRACE_DIR" -maxdepth 1 -name "*${AGENT_PREFIX}*.jsonl" -type f 2>/dev/null | head -1)
  if [ -n "$MATCH" ]; then
    TRACE_FILE="$MATCH"
    break
  fi

  WAIT_COUNT=$((WAIT_COUNT + POLL_SECS))
  if [ "$WAIT_COUNT" -ge "$MAX_WAIT" ]; then
    echo "watchdog: no trace file matching '$AGENT_PREFIX' found after ${MAX_WAIT}s — exiting" >&2
    exit 1
  fi
  sleep "$POLL_SECS"
done

echo "watchdog: monitoring $TRACE_FILE (timeout=${TIMEOUT_SECS}s, poll=${POLL_SECS}s)" >&2

# Get initial line count
LAST_LINES=$(wc -l < "$TRACE_FILE" 2>/dev/null || echo 0)
LAST_ACTIVITY=$(date +%s)

# Write alive marker
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${TRACE_FILE}.alive"

while true; do
  sleep "$POLL_SECS"

  # Check if trace file still exists
  if [ ! -f "$TRACE_FILE" ]; then
    echo "watchdog: trace file removed — agent likely completed" >&2
    rm -f "${TRACE_FILE}.alive"
    exit 0
  fi

  CURRENT_LINES=$(wc -l < "$TRACE_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)

  if [ "$CURRENT_LINES" -gt "$LAST_LINES" ]; then
    # Activity detected
    LAST_LINES="$CURRENT_LINES"
    LAST_ACTIVITY="$NOW"

    # Remove stale marker if it exists, refresh alive marker
    rm -f "${TRACE_FILE}.stale"
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${TRACE_FILE}.alive"
  else
    # No new activity
    IDLE_SECS=$((NOW - LAST_ACTIVITY))

    if [ "$IDLE_SECS" -ge "$TIMEOUT_SECS" ]; then
      echo "watchdog: agent idle for ${IDLE_SECS}s (threshold: ${TIMEOUT_SECS}s) — marking stale" >&2

      # Write stale marker with diagnostics
      cat > "${TRACE_FILE}.stale" <<EOF
stale_since: $(date -u +%Y-%m-%dT%H:%M:%SZ)
idle_seconds: $IDLE_SECS
threshold_seconds: $TIMEOUT_SECS
trace_file: $TRACE_FILE
last_line_count: $CURRENT_LINES
last_line: $(tail -1 "$TRACE_FILE" 2>/dev/null || echo "unknown")
EOF
      rm -f "${TRACE_FILE}.alive"

      # Don't exit — keep monitoring in case the agent wakes up.
      # The dispatcher reads the .stale file and decides whether to kill.
    fi
  fi
done
