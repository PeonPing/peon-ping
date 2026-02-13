#!/bin/bash
# peon-ping adapter for OpenAI Codex CLI
# Translates Codex notify events into peon.sh stdin JSON
#
# Setup: Add to ~/.codex/config.toml:
#   notify = ["bash", "/absolute/path/to/.claude/hooks/peon-ping/adapters/codex.sh"]
#
# Or if installed locally:
#   notify = ["bash", "/absolute/path/to/peon-ping/adapters/codex.sh"]

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"

# Codex currently sends limited event info via notify
# Map what we can to CESP categories via peon-ping events
CODEX_EVENT="${1:-agent-turn-complete}"

case "$CODEX_EVENT" in
  agent-turn-complete|complete|done)
    EVENT="Stop"
    ;;
  start|session-start)
    EVENT="SessionStart"
    ;;
  error|fail*)
    EVENT="Stop"  # peon.sh doesn't have a direct error event yet
    ;;
  permission*|approve*)
    EVENT="Notification"
    NTYPE="permission_prompt"
    ;;
  *)
    EVENT="Stop"
    ;;
esac

NTYPE="${NTYPE:-}"
SESSION_ID="codex-${CODEX_SESSION_ID:-$$}"
CWD="${PWD}"

echo "{\"hook_event_name\":\"$EVENT\",\"notification_type\":\"$NTYPE\",\"cwd\":\"$CWD\",\"session_id\":\"$SESSION_ID\",\"permission_mode\":\"\"}" \
  | bash "$PEON_DIR/peon.sh"
