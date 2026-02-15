#!/bin/bash
# peon-ping adapter for OpenClaw gateway agents
# Translates OpenClaw events into peon.sh stdin JSON
#
# Setup: Add play.sh to your OpenClaw skill, or call this adapter directly:
#   bash adapters/openclaw.sh <event>
#
# Core events:
#   session.start    — Agent session started
#   task.complete    — Agent finished a task
#   task.error       — Agent encountered an error
#   input.required   — Agent needs user input
#   task.acknowledge — Agent acknowledged a task
#   resource.limit   — Rate limit / token quota / fallback triggered
#
# Extended events:
#   user.spam        — Too many rapid prompts
#   session.end      — Agent session closed / disconnected
#   task.progress    — Long-running task still in progress
#
# Or use Claude Code hook event names:
#   SessionStart, Stop, Notification, UserPromptSubmit

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
[ -d "$PEON_DIR" ] || PEON_DIR="$HOME/.openpeon"

if [ ! -f "$PEON_DIR/peon.sh" ]; then
  echo "peon-ping not installed. Run: brew install PeonPing/tap/peon-ping" >&2
  exit 1
fi

OC_EVENT="${1:-task.complete}"
NTYPE=""

# Map OpenClaw event names to peon.sh hook events
case "$OC_EVENT" in
  # Core CESP categories
  session.start|greeting|ready|heartbeat.first)
    EVENT="SessionStart"
    ;;
  task.complete|complete|done|deployed|merged)
    EVENT="Stop"
    ;;
  task.acknowledge|acknowledge|ack|building|working)
    EVENT="UserPromptSubmit"
    ;;
  task.error|error|fail|crash|build.failed)
    EVENT="Stop"
    ;;
  input.required|permission|input|waiting|blocked|approval)
    EVENT="Notification"
    NTYPE="permission_prompt"
    ;;
  resource.limit|ratelimit|rate.limit|quota|fallback|throttled|token.limit)
    EVENT="Notification"
    NTYPE="resource_limit"
    ;;

  # Extended CESP categories
  user.spam|annoyed|spam)
    EVENT="UserPromptSubmit"
    ;;
  session.end|disconnect|shutdown|goodbye)
    EVENT="Stop"
    ;;
  task.progress|progress|running|backfill|syncing)
    EVENT="Notification"
    NTYPE="progress"
    ;;

  # Also accept raw Claude Code hook event names
  SessionStart|Stop|Notification|UserPromptSubmit|PermissionRequest)
    EVENT="$OC_EVENT"
    ;;
  *)
    EVENT="Stop"
    ;;
esac

SESSION_ID="openclaw-${OPENCLAW_SESSION_ID:-$$}"

# Build JSON safely — use jq if available, fall back to printf
if command -v jq &>/dev/null; then
  jq -nc \
    --arg hook "$EVENT" \
    --arg ntype "$NTYPE" \
    --arg cwd "$PWD" \
    --arg sid "$SESSION_ID" \
    '{hook_event_name:$hook, notification_type:$ntype, cwd:$cwd, session_id:$sid, permission_mode:""}'
else
  printf '{"hook_event_name":"%s","notification_type":"%s","cwd":"%s","session_id":"%s","permission_mode":""}\n' \
    "$EVENT" "$NTYPE" "$PWD" "$SESSION_ID"
fi | bash "$PEON_DIR/peon.sh"
