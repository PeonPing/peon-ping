#!/bin/bash
# Minimal peon-ping relay hook for remote Claude Code sessions
#
# This hook is for machines where peon-ping isn't installed but a relay
# is accessible (e.g., over SSH port forwarding). It sends category names
# to the relay, which handles sound selection server-side.
#
# Setup:
#   1. On your LOCAL machine: peon relay --daemon
#   2. SSH with port forwarding: ssh -R 19998:localhost:19998 <host>
#   3. Copy this script to the remote machine
#   4. Register in ~/.claude/settings.json:
#      {
#        "hooks": {
#          "SessionStart": [{"command": "bash /path/to/remote-hook.sh"}],
#          "Stop": [{"command": "bash /path/to/remote-hook.sh"}],
#          "PermissionRequest": [{"command": "bash /path/to/remote-hook.sh"}]
#        }
#      }
#
# The relay URL defaults to localhost:19998 (SSH tunnel). Override with:
#   PEON_RELAY_URL=http://host.docker.internal:19998  (for devcontainers)
#
set -uo pipefail

RELAY_URL="${PEON_RELAY_URL:-http://127.0.0.1:19998}"

# Parse hook event from JSON stdin
EVENT=$(cat | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('hook_event_name',''))" 2>/dev/null)

# Map Claude Code events to CESP categories
case "$EVENT" in
  SessionStart)      CATEGORY="session.start" ;;
  Stop)              CATEGORY="task.complete" ;;
  PermissionRequest) CATEGORY="input.required" ;;
  *)                 exit 0 ;;  # Ignore other events
esac

# Fire and forget - don't block Claude Code
curl -sf "${RELAY_URL}/play?category=${CATEGORY}" >/dev/null 2>&1 &
