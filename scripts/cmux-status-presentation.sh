#!/bin/bash
# cmux-status-presentation.sh - cmux sidebar status policy, display, and update.
# Usage:
#   cmux-status-presentation.sh update <event> <status> <ide-label> <session-id>
set -uo pipefail

cmd="${1:-}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

cmux_cli_path() {
  if [ -n "${CMUX_BUNDLED_CLI_PATH:-}" ] && [ -x "${CMUX_BUNDLED_CLI_PATH:-}" ]; then
    printf '%s\n' "$CMUX_BUNDLED_CLI_PATH"
    return
  fi
  command -v cmux 2>/dev/null || true
}

cmux_workspace_ref() {
  cmux_cli="$1"
  cmux_workspace_id="${2:-}"
  [ -n "$cmux_cli" ] || return 1
  [ -n "$cmux_workspace_id" ] || return 1

  cmux_workspace_field_helper="$script_dir/cmux-workspace-field.sh"
  [ -x "$cmux_workspace_field_helper" ] || return 1
  "$cmux_workspace_field_helper" ref "$cmux_cli" "" "$cmux_workspace_id" 2>/dev/null
}

cmux_status_call() {
  cmux_cli="$1"
  shift

  attempt=1
  while [ "$attempt" -le 4 ]; do
    out=$("$cmux_cli" "$@" 2>&1)
    rc=$?
    if [ "$rc" -eq 0 ]; then
      return 0
    fi

    case "$out" in
      *"Broken pipe"*|*"errno 32"*)
        [ "$attempt" -lt 4 ] || return "$rc"
        sleep 0.2
        ;;
      *)
        return "$rc"
        ;;
    esac
    attempt=$((attempt + 1))
  done

  return 1
}

can_manage_status() {
  session_id="${1:-${SESSION_ID:-}}"

  { [ -n "${CMUX_SURFACE_ID:-}" ] || [ -n "${CMUX_PANEL_ID:-}" ]; } || return 1
  { [ -n "${CMUX_SOCKET_PATH:-}" ] || [ -n "${CMUX_SOCKET:-}" ]; } || return 1

  # cmux already owns Claude Code's native sidebar state. Peon only fills the
  # gap for other adapters, plus Codex sessions where Claude env can leak in.
  case "$session_id" in
    codex-*) return 0 ;;
  esac
  [ -z "${CLAUDE_CODE_ENTRYPOINT:-}" ]
}

present_status_fields() {
  value="${1:-}"

  # These human labels belong only to cmux's status pill; notification text keeps
  # the upstream status/message wording.
  case "$value" in
    ready|working)
      printf '%s\t%s\t%s\n' "Running" "bolt.fill" "#4C8DFF"
      ;;
    done)
      printf '%s\t%s\t%s\n' "Idle" "pause.circle.fill" ""
      ;;
    "needs approval"|question)
      printf '%s\t%s\t%s\n' "Needs input" "bell.fill" "#4C8DFF"
      ;;
    error)
      printf '%s\t%s\t%s\n' "Error" "exclamationmark.triangle.fill" ""
      ;;
    compacting)
      printf '%s\t%s\t%s\n' "Running" "archivebox.fill" "#AC8D00"
      ;;
    *)
      return 1
      ;;
  esac
}

status_plan() {
  event="${1:-}"
  value="${2:-}"
  session_id="${3:-}"

  can_manage_status "$session_id" || return 1

  if [ "$event" = "SessionEnd" ]; then
    printf '%s\n' "clear"
    return 0
  fi

  fields="$(present_status_fields "$value")" || return 1
  IFS="$(printf '\t')" read -r display_value icon color <<EOF
$fields
EOF
  [ -n "$display_value" ] || return 1
  printf '%s\t%s\t%s\t%s\n' "set" "$display_value" "$icon" "$color"
}

update_status() {
  event="${1:-}"
  value="${2:-}"
  ide_label="${3:-}"
  session_id="${4:-}"

  plan="$(status_plan "$event" "$value" "$session_id")" || return 0
  IFS="$(printf '\t')" read -r action display_value icon color <<EOF
$plan
EOF

  case "$action" in
    clear|set) ;;
    *) return 0 ;;
  esac

  cmux_cli="$(cmux_cli_path)"
  [ -n "$cmux_cli" ] || return 0

  key="peon"
  cmux_workspace_arg=""
  if [ -n "${CMUX_WORKSPACE_ID:-}" ]; then
    cmux_workspace_arg="$(cmux_workspace_ref "$cmux_cli" "$CMUX_WORKSPACE_ID" 2>/dev/null || true)"
    [ -z "$cmux_workspace_arg" ] && cmux_workspace_arg="$CMUX_WORKSPACE_ID"
  fi

  if [ "$action" = "clear" ]; then
    set -- clear-status "$key"
    [ -n "$cmux_workspace_arg" ] && set -- "$@" --workspace "$cmux_workspace_arg"
    cmux_status_call "$cmux_cli" "$@" >/dev/null 2>&1
    return 0
  fi

  [ -n "$display_value" ] || return 0
  if [ -n "$ide_label" ]; then
    display_value="${ide_label}: ${display_value}"
  fi

  set -- set-status "$key" "$display_value"
  [ -n "$icon" ] && set -- "$@" --icon "$icon"
  [ -n "$color" ] && set -- "$@" --color "$color"
  [ -n "$cmux_workspace_arg" ] && set -- "$@" --workspace "$cmux_workspace_arg"
  cmux_status_call "$cmux_cli" "$@" >/dev/null 2>&1
}

case "$cmd" in
  update)
    update_status "${2:-}" "${3:-}" "${4:-}" "${5:-}"
    ;;
  *)
    exit 1
    ;;
esac
