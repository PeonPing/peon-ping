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

# A restored Codex thread can reuse its session id while skipping SessionStart.
# Prefer the current Codex process as the activation boundary so a relaunched
# client can greet again without turning every prompt into a greeting. The env
# override keeps the boundary deterministic for tests and unusual launchers.
resolve_codex_activation_id() {
  if [ "${PEON_CODEX_ACTIVATION_ID+x}" = "x" ]; then
    printf '%s' "$PEON_CODEX_ACTIVATION_ID"
    return
  fi

  local pid="$PPID"
  local depth=0
  local comm=""
  local comm_base=""
  local args=""
  local started=""
  local parent=""
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null && [ "$depth" -lt 12 ]; do
    comm="$(ps -p "$pid" -o comm= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
    args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    comm_base="${comm##*/}"
    if [ "$comm_base" = "codex" ] || [ "$comm_base" = "codex.exe" ] || [[ "$args" == *"@openai/codex"* ]]; then
      started="$(ps -p "$pid" -o lstart= 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' || true)"
      printf '%s|%s|%s' "$pid" "$started" "$comm"
      return
    fi
    parent="$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d '[:space:]')"
    [ -n "$parent" ] || break
    pid="$parent"
    depth=$((depth + 1))
  done
}

CODEX_ACTIVATION_ID="$(resolve_codex_activation_id)"

# Map to a CESP payload. Silent events (PreToolUse, PostToolUse) print nothing,
# so peon.sh is never invoked for per-tool-call chatter.
MAPPED_JSON="$(_CODEX_EVENT="$CODEX_EVENT" \
  _CODEX_STDIN="$CODEX_STDIN" \
  _CODEX_ACTIVATION_ID="$CODEX_ACTIVATION_ID" \
  _PEON_DIR="$PEON_DIR" \
  _CODEX_ACTIVATION_TTL_SECONDS="${PEON_CODEX_ACTIVATION_TTL_SECONDS:-1800}" \
  _CODEX_START_GRACE_SECONDS="${PEON_CODEX_START_GRACE_SECONDS:-3}" \
  python3 - <<'PY'
import fcntl
import hashlib
import json
import os
import re
import sys
import tempfile
import time


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


def positive_float(value, default):
    try:
        parsed = float(value)
        return parsed if parsed > 0 else default
    except (TypeError, ValueError):
        return default


def write_json_atomic(path, value):
    directory = os.path.dirname(path)
    descriptor, temporary_path = tempfile.mkstemp(prefix=".codex-activation.", dir=directory)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            json.dump(value, handle, separators=(",", ":"))
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary_path, 0o600)
        os.replace(temporary_path, path)
    finally:
        if os.path.exists(temporary_path):
            os.unlink(temporary_path)


def update_activation_state(mapped_event, session_id):
    peon_dir = os.environ.get("_PEON_DIR", "").strip()
    if not peon_dir or not session_id:
        return "unchanged"

    activation_id = os.environ.get("_CODEX_ACTIVATION_ID", "").strip()
    activation_ttl = positive_float(
        os.environ.get("_CODEX_ACTIVATION_TTL_SECONDS", ""), 1800
    )
    grace_seconds = positive_float(
        os.environ.get("_CODEX_START_GRACE_SECONDS", ""), 3
    )
    now = time.time()
    state_path = os.path.join(peon_dir, ".codex-activation-state.json")
    lock_path = os.path.join(peon_dir, ".codex-activation-state.lock")
    os.makedirs(peon_dir, exist_ok=True)

    # When no Codex process can be found, the session id falls back to an
    # inactivity lease instead of becoming a permanent lifetime marker.
    boundary = activation_id or "inactivity-lease"
    key = hashlib.sha256(f"{session_id}\0{boundary}".encode("utf-8")).hexdigest()

    with open(lock_path, "a+", encoding="utf-8") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        try:
            try:
                with open(state_path, encoding="utf-8") as handle:
                    state = json.load(handle)
            except (FileNotFoundError, json.JSONDecodeError, OSError):
                state = {}
            if not isinstance(state, dict):
                state = {}
            activations = state.get("activations", {})
            if not isinstance(activations, dict):
                activations = {}

            # Keep the adapter-specific state bounded independently of peon.sh.
            prune_before = now - 7 * 86400
            activations = {
                item_key: item
                for item_key, item in activations.items()
                if isinstance(item, dict)
                and isinstance(item.get("last_seen"), (int, float))
                and item["last_seen"] >= prune_before
            }
            record = activations.get(key)
            if record and now - record.get("last_seen", 0) >= activation_ttl:
                activations.pop(key, None)
                record = None

            action = "unchanged"
            if mapped_event == "SessionStart":
                greeted_at = record.get("greeted_at", 0) if record else 0
                if record and now - greeted_at < grace_seconds:
                    record["last_seen"] = now
                    action = "suppress-start"
                else:
                    activations[key] = {
                        "session_id": session_id,
                        "activation_id": activation_id,
                        "source": "SessionStart",
                        "greeted_at": now,
                        "last_seen": now,
                    }
                    action = "emit-start"
            elif mapped_event == "UserPromptSubmit":
                if record:
                    record["last_seen"] = now
                    action = "emit-prompt"
                else:
                    activations[key] = {
                        "session_id": session_id,
                        "activation_id": activation_id,
                        "source": "UserPromptSubmit",
                        "greeted_at": now,
                        "last_seen": now,
                    }
                    action = "fallback-start"
            elif mapped_event == "SessionEnd":
                activations.pop(key, None)
            elif record:
                record["last_seen"] = now

            state["version"] = 1
            state["activations"] = activations
            write_json_atomic(state_path, state)
            return action
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)


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

try:
    activation_action = update_activation_state(mapped_event, session_id)
except Exception:
    # Sound integration state must never block a Codex hook.
    activation_action = "unchanged"

if mapped_event == "SessionStart" and activation_action == "suppress-start":
    sys.exit(0)

payloads = [payload]
if mapped_event == "UserPromptSubmit" and activation_action == "fallback-start":
    fallback = dict(payload)
    fallback["hook_event_name"] = "SessionStart"
    payloads.insert(0, fallback)

for item in payloads:
    print(json.dumps(item))
PY
)" || MAPPED_JSON=""

if [ -n "$MAPPED_JSON" ]; then
  while IFS= read -r mapped_json; do
    [ -n "$mapped_json" ] || continue
    printf '%s' "$mapped_json" | bash "$PEON_SH"
  done <<< "$MAPPED_JSON"
fi
