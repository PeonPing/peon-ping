#!/bin/bash
# peon-ping adapter for Grok Build
# Translates Grok Build hook events into peon.sh stdin JSON.
#
# Grok sends camelCase stdin (hookEventName, sessionId, notificationType)
# with snake_case event values (session_start, stop, notification). peon.sh
# expects Claude-style PascalCase hook_event_name. This adapter translates
# and then calls peon.sh.
#
# Setup: if ~/.grok already exists, install.sh / install.ps1 write
#   ~/.grok/hooks/peon-ping.json automatically. Re-run the installer after
#   installing Grok Build, or point Grok's hooks at this script by hand.
#
# Grok's Stop / SubagentStop hooks are stop-gates: anything that looks like
# decision JSON on stdout can keep the agent working. peon.sh output is
# discarded so a chime can never be parsed as a gate decision.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
PEON_SH="$PEON_DIR/peon.sh"
[ -f "$PEON_SH" ] || exit 0

if [ -t 0 ]; then
  GROK_STDIN=""
else
  GROK_STDIN="$(cat)"
fi

MAPPED_JSON="$(
  _GROK_STDIN="$GROK_STDIN" python3 - <<'PY'
import json
import os
import re
import sys


def first_non_empty(*values):
    for value in values:
        if value is None:
            continue
        if isinstance(value, str):
            if value.strip():
                return value.strip()
        else:
            return value
    return ""


raw_stdin = os.environ.get("_GROK_STDIN", "").strip()
event_data = {}
if raw_stdin:
    try:
        parsed = json.loads(raw_stdin)
        if isinstance(parsed, dict):
            event_data = parsed
    except Exception:
        event_data = {}

raw_event = first_non_empty(
    os.environ.get("GROK_HOOK_EVENT", ""),
    event_data.get("hookEventName", ""),
    event_data.get("hook_event_name", ""),
    event_data.get("event", ""),
)
event_key = str(raw_event).strip().lower().replace("-", "_")

notif_type = str(
    first_non_empty(
        event_data.get("notificationType", ""),
        event_data.get("notification_type", ""),
        event_data.get("type", ""),
    )
).strip().lower()

reason = str(
    first_non_empty(
        event_data.get("reason", ""),
        event_data.get("stopReason", ""),
        event_data.get("stop_reason", ""),
    )
).strip().lower()

# Per-tool hooks are too noisy. Completion / error / attention events
# are the ones peon-ping has sounds for.
if event_key in (
    "pre_tool_use",
    "pretooluse",
    "post_tool_use",
    "posttooluse",
    "post_compact",
    "postcompact",
    "permission_denied",
    "permissiondenied",
):
    sys.exit(0)

if event_key in ("session_start", "sessionstart"):
    mapped_event = "SessionStart"
    mapped_ntype = ""
elif event_key in ("session_end", "sessionend"):
    mapped_event = "SessionEnd"
    mapped_ntype = ""
elif event_key in ("user_prompt_submit", "userpromptsubmit"):
    mapped_event = "UserPromptSubmit"
    mapped_ntype = ""
elif event_key in ("subagent_start", "subagentstart"):
    mapped_event = "SubagentStart"
    mapped_ntype = ""
elif event_key in ("subagent_stop", "subagentstop", "subagent_end", "subagentend"):
    mapped_event = "SubagentStop"
    mapped_ntype = ""
elif event_key in ("pre_compact", "precompact"):
    mapped_event = "PreCompact"
    mapped_ntype = ""
elif event_key in ("post_tool_use_failure", "posttoolusefailure"):
    mapped_event = "PostToolUseFailure"
    mapped_ntype = ""
elif event_key in ("stop_failure", "stopfailure"):
    mapped_event = "PostToolUseFailure"
    mapped_ntype = ""
elif event_key in ("notification",):
    if notif_type in ("permission_prompt", "permission", "approval_required"):
        mapped_event = "PermissionRequest"
        mapped_ntype = "permission_prompt"
    elif notif_type in ("idle_prompt", "idle"):
        mapped_event = "Notification"
        mapped_ntype = "idle_prompt"
    elif notif_type in ("elicitation_dialog", "elicitation", "question"):
        mapped_event = "Notification"
        mapped_ntype = "elicitation_dialog"
    elif notif_type in ("task_complete", "turn_complete"):
        # Stop already covers genuine turn completion.
        sys.exit(0)
    else:
        sys.exit(0)
elif event_key in ("stop",):
    # Grok also fires observe-only Stop at session end. Only chime on a
    # real turn completion; treat session teardown as SessionEnd.
    if reason in ("channel_closed", "shutdown"):
        mapped_event = "SessionEnd"
        mapped_ntype = ""
    elif reason and reason != "end_turn":
        sys.exit(0)
    else:
        mapped_event = "Stop"
        mapped_ntype = ""
else:
    sys.exit(0)

cwd = str(
    first_non_empty(
        event_data.get("cwd", ""),
        event_data.get("workspaceRoot", ""),
        event_data.get("workspace_root", ""),
        os.environ.get("GROK_WORKSPACE_ROOT", ""),
        os.environ.get("CLAUDE_PROJECT_DIR", ""),
        os.environ.get("PWD", ""),
        "/",
    )
)

raw_session_id = str(
    first_non_empty(
        event_data.get("sessionId", ""),
        event_data.get("session_id", ""),
        os.environ.get("GROK_SESSION_ID", ""),
        os.getpid(),
    )
)
safe_session_id = re.sub(r"[^A-Za-z0-9._:-]", "-", raw_session_id).strip("-")
if not safe_session_id:
    safe_session_id = str(os.getpid())
if safe_session_id.startswith("grok-"):
    session_id = safe_session_id
else:
    session_id = f"grok-{safe_session_id}"

payload = {
    "hook_event_name": mapped_event,
    "notification_type": mapped_ntype,
    "cwd": cwd,
    "session_id": session_id,
    "permission_mode": str(
        first_non_empty(
            event_data.get("permissionMode", ""),
            event_data.get("permission_mode", ""),
            "",
        )
    ),
    "source": "grok",
}

agent_id = first_non_empty(
    event_data.get("agentId", ""),
    event_data.get("agent_id", ""),
    event_data.get("subagentId", ""),
    event_data.get("subagent_id", ""),
)
if isinstance(agent_id, str) and agent_id:
    payload["agent_id"] = agent_id[:80]

agent_type = first_non_empty(
    event_data.get("agentType", ""),
    event_data.get("agent_type", ""),
    event_data.get("subagentType", ""),
    event_data.get("subagent_type", ""),
)
if isinstance(agent_type, str) and agent_type:
    payload["agent_type"] = agent_type[:80]

summary = first_non_empty(
    event_data.get("lastAssistantMessage", ""),
    event_data.get("last_assistant_message", ""),
    event_data.get("transcript_summary", ""),
    event_data.get("summary", ""),
)
if isinstance(summary, str) and summary:
    payload["last_assistant_message"] = summary[:120]
    payload["transcript_summary"] = summary[:120]

tool_name = first_non_empty(
    event_data.get("toolName", ""),
    event_data.get("tool_name", ""),
    event_data.get("tool", ""),
)
shell_tools = {"bash", "run_terminal_command", "shell"}
if mapped_event == "PostToolUseFailure":
    if str(tool_name).strip().lower() in shell_tools or event_key in ("stop_failure", "stopfailure"):
        payload["tool_name"] = "Bash"
    elif isinstance(tool_name, str) and tool_name:
        payload["tool_name"] = tool_name[:64]
    else:
        payload["tool_name"] = "Bash"
elif isinstance(tool_name, str) and tool_name:
    payload["tool_name"] = tool_name[:64]

error = first_non_empty(
    event_data.get("errorDetails", ""),
    event_data.get("error_details", ""),
    event_data.get("error", ""),
    event_data.get("message", ""),
    summary,
)
if mapped_event == "PostToolUseFailure":
    if not error:
        error = f"Grok event: {raw_event or event_key}"
    payload["error"] = str(error)[:180]

print(json.dumps(payload))
PY
)" || MAPPED_JSON=""

if [ -n "${MAPPED_JSON:-}" ]; then
  # Discard peon.sh stdout so Stop/SubagentStop can never be parsed as a
  # gate decision. SessionStart keeps stderr so update notices still surface.
  if printf '%s' "$MAPPED_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("hook_event_name",""))' 2>/dev/null | grep -qx 'SessionStart'; then
    printf '%s' "$MAPPED_JSON" | bash "$PEON_SH" >/dev/null || true
  else
    printf '%s' "$MAPPED_JSON" | bash "$PEON_SH" >/dev/null 2>&1 || true
  fi
fi
