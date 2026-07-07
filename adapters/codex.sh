#!/bin/bash
# peon-ping adapter for OpenAI Codex CLI
# Translates Codex events into peon.sh stdin JSON.
#
# Codex ships a stable hook event set delivered as JSON on stdin with a
# `hook_event_name` field, AND a legacy `notify` callback (event name passed
# as argv). This adapter handles both: it prefers stdin stable-hook JSON when
# present and falls back to the argv notify event. PostToolUse is deliberately
# ignored because Codex does not expose a separate failure-only hook and
# successful tool hooks are too noisy for peon-ping.
#
# Setup (legacy notify): Add to ~/.codex/config.toml:
#   notify = ["bash", "/absolute/path/to/.claude/hooks/peon-ping/adapters/codex.sh"]
#
# Setup (stable hooks): re-run install.sh after Codex creates ~/.codex, or point
#   Codex's stable lifecycle hooks at this script.

set -euo pipefail

PEON_DIR="${CLAUDE_PEON_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/hooks/peon-ping}"
PEON_SH="$PEON_DIR/peon.sh"
[ -f "$PEON_SH" ] || exit 0

# Codex notifies with limited payload; accept event arg and optional stdin JSON.
CODEX_EVENT="${1:-}"
if [ -n "$CODEX_EVENT" ] || [ -t 0 ]; then
  CODEX_STDIN=""
else
  CODEX_STDIN="$(cat)"
fi

# Map to a CESP payload. Silent events (PreToolUse, PostToolUse) print nothing,
# so peon.sh is never invoked for per-tool-call chatter.
MAPPED_JSON="$(_CODEX_EVENT="$CODEX_EVENT" _CODEX_STDIN="$CODEX_STDIN" python3 - <<'PY'
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


raw_stdin = os.environ.get("_CODEX_STDIN", "").strip()
event_data = {}
if raw_stdin:
    try:
        parsed = json.loads(raw_stdin)
        if isinstance(parsed, dict):
            event_data = parsed
    except Exception:
        event_data = {}


workspace_roots = event_data.get("workspace_roots")
root0 = ""
if isinstance(workspace_roots, list) and workspace_roots:
    root0 = str(workspace_roots[0] or "")

raw_event = first_non_empty(
    os.environ.get("_CODEX_EVENT", ""),
    event_data.get("hook_event_name", ""),
    event_data.get("event", ""),
    event_data.get("type", ""),
    "agent-turn-complete",
)
event_key = str(raw_event).strip().lower().replace("_", "-")

notif_type = str(event_data.get("notification_type", "")).strip().lower()
if event_key in ("permissionrequest", "permission-request"):
    mapped_event = "PermissionRequest"
    mapped_ntype = notif_type
elif (
    event_key.startswith("permission")
    or event_key.startswith("approve")
    or event_key in ("approval-requested", "approval-needed", "input-required")
    or notif_type == "permission_prompt"
):
    mapped_event = "Notification"
    mapped_ntype = "permission_prompt"
elif event_key in ("start", "session-start", "sessionstart"):
    mapped_event = "SessionStart"
    mapped_ntype = notif_type
elif event_key in ("session-end", "sessionend"):
    mapped_event = "SessionEnd"
    mapped_ntype = notif_type
elif event_key in ("subagent-start", "subagentstart"):
    mapped_event = "SubagentStart"
    mapped_ntype = notif_type
elif event_key in ("subagent-stop", "subagentstop"):
    mapped_event = "SubagentStop"
    mapped_ntype = notif_type
elif event_key in ("user-prompt-submit", "userpromptsubmit"):
    mapped_event = "UserPromptSubmit"
    mapped_ntype = notif_type
elif event_key in ("precompact", "pre-compact"):
    mapped_event = "PreCompact"
    mapped_ntype = notif_type
elif event_key in ("postcompact", "post-compact"):
    sys.exit(0)
elif event_key == "idle-prompt":
    mapped_event = "Notification"
    mapped_ntype = "idle_prompt"
elif event_key in ("pre-tool-use", "pretooluse"):
    # Fires before every tool call — far too noisy; emit nothing.
    sys.exit(0)
elif event_key in ("post-tool-use", "posttooluse"):
    # Codex has PostToolUse, but not PostToolUseFailure. Stay silent rather than
    # trying to infer failures from event payload details.
    sys.exit(0)
elif event_key.startswith("error") or event_key.startswith("fail"):
    mapped_event = "PostToolUseFailure"
    mapped_ntype = notif_type
else:
    mapped_event = "Stop"
    mapped_ntype = notif_type

cwd = str(
    first_non_empty(
        event_data.get("cwd", ""),
        event_data.get("workspace_root", ""),
        root0,
        os.environ.get("CODEX_CWD", ""),
        os.environ.get("PWD", ""),
        "/",
    )
)

raw_session_id = str(
    first_non_empty(
        event_data.get("session_id", ""),
        event_data.get("conversation_id", ""),
        event_data.get("thread_id", ""),
        os.environ.get("CODEX_SESSION_ID", ""),
        os.getpid(),
    )
)
safe_session_id = re.sub(r"[^A-Za-z0-9._:-]", "-", raw_session_id).strip("-")
if not safe_session_id:
    safe_session_id = str(os.getpid())
session_id = f"codex-{safe_session_id}"

payload = {
    "hook_event_name": mapped_event,
    "notification_type": mapped_ntype,
    "cwd": cwd,
    "session_id": session_id,
    "permission_mode": str(event_data.get("permission_mode", "")),
    "source": "codex",
}

agent_id = first_non_empty(event_data.get("agent_id", ""), event_data.get("subagent_id", ""))
if isinstance(agent_id, str) and agent_id:
    payload["agent_id"] = agent_id[:80]

agent_type = first_non_empty(event_data.get("agent_type", ""), event_data.get("subagent_type", ""))
if isinstance(agent_type, str) and agent_type:
    payload["agent_type"] = agent_type[:80]

summary = first_non_empty(
    event_data.get("transcript_summary", ""),
    event_data.get("summary", ""),
    event_data.get("last_assistant_message", ""),
)
if isinstance(summary, str) and summary:
    payload["transcript_summary"] = summary[:120]

tool_name = first_non_empty(event_data.get("tool_name", ""), event_data.get("tool", ""))
if mapped_event == "PostToolUseFailure" and not tool_name:
    tool_name = "Bash"
if isinstance(tool_name, str) and tool_name:
    payload["tool_name"] = tool_name[:64]

error = first_non_empty(event_data.get("error", ""), event_data.get("message", ""))
if mapped_event == "PostToolUseFailure":
    if not error:
        error = f"Codex event: {raw_event}"
    payload["error"] = str(error)[:180]

print(json.dumps(payload))
PY
)" || MAPPED_JSON=""

if [ -n "$MAPPED_JSON" ]; then
  printf '%s' "$MAPPED_JSON" | bash "$PEON_SH"
fi
