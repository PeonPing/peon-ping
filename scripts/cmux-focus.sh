#!/bin/bash
set -uo pipefail

cmux_cli="${1:-}"
cmux_socket_path="${2:-}"
cmux_workspace_id="${3:-}"
cmux_surface_id="${4:-}"

[ -n "$cmux_surface_id" ] || exit 1

if [ -z "$cmux_cli" ]; then
  cmux_cli="$(command -v cmux 2>/dev/null || true)"
fi
[ -n "$cmux_cli" ] || exit 1

workspace_field_helper="$(
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
)/cmux-workspace-field.sh"

cmux_args=()
[ -n "$cmux_socket_path" ] && cmux_args+=(--socket "$cmux_socket_path")
cmux_args+=(focus-panel)
if [ -n "$cmux_workspace_id" ]; then
  cmux_workspace_arg="$("$workspace_field_helper" ref "$cmux_cli" "$cmux_socket_path" "$cmux_workspace_id" 2>/dev/null || true)"
  [ -z "$cmux_workspace_arg" ] && cmux_workspace_arg="$cmux_workspace_id"
  cmux_args+=(--workspace "$cmux_workspace_arg")
fi
cmux_args+=(--panel "$cmux_surface_id")

"$cmux_cli" "${cmux_args[@]}"
