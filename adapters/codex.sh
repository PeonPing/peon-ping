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

_PE="$EVENT" _PN="$NTYPE" _PC="$CWD" _PS="$SESSION_ID" python3 -c "
import json, os
print(json.dumps({
    'hook_event_name': os.environ['_PE'],
    'notification_type': os.environ['_PN'],
    'cwd': os.environ['_PC'],
    'session_id': os.environ['_PS'],
    'permission_mode': '',
}))
" | bash "$PEON_DIR/peon.sh"
