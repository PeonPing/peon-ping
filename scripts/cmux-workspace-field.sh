#!/bin/bash
# cmux-workspace-field.sh - print a workspace field for a given cmux workspace ID.
# Usage: cmux-workspace-field.sh <field> <cmux_cli> <socket_path> <workspace_id>
set -uo pipefail

field="${1:-}"
cmux_cli="${2:-}"
cmux_socket_path="${3:-}"
cmux_workspace_id="${4:-}"

case "$field" in
  ref|title) ;;
  *) exit 1 ;;
esac
[ -n "$cmux_workspace_id" ] || exit 1

if [ -z "$cmux_cli" ]; then
  cmux_cli="$(command -v cmux 2>/dev/null || true)"
fi
[ -n "$cmux_cli" ] || exit 1

cmux_args=()
[ -n "$cmux_socket_path" ] && cmux_args+=(--socket "$cmux_socket_path")
cmux_args+=(--json --id-format both list-workspaces)

cmux_out=$("$cmux_cli" "${cmux_args[@]}" 2>/dev/null) || exit 1
[ -n "$cmux_out" ] || exit 1

CMUX_LIST_JSON="$cmux_out" \
CMUX_WORKSPACE_ID_LOOKUP="$cmux_workspace_id" \
CMUX_WORKSPACE_FIELD="$field" \
python3 - <<'PY' 2>/dev/null
import json
import os

field = os.environ.get("CMUX_WORKSPACE_FIELD", "")
workspace_id = os.environ.get("CMUX_WORKSPACE_ID_LOOKUP", "")

try:
    payload = json.loads(os.environ.get("CMUX_LIST_JSON", ""))
except Exception:
    raise SystemExit(1)

for workspace in payload.get("workspaces", []) or []:
    if workspace.get("id") != workspace_id and workspace.get("ref") != workspace_id:
        continue
    value = str(workspace.get(field, "") or "").strip()
    if field == "title":
        value = value[:50]
    if value:
        print(value)
        raise SystemExit(0)
    break

raise SystemExit(1)
PY
