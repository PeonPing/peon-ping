#!/bin/bash
# peon-ping: Platform-aware desktop notification (shared by peon.sh and relay.sh)
#
# Usage: notify.sh <message> <title> <color> [icon_path]
#
# Environment variables (optional, auto-detected if absent):
#   PEON_PLATFORM       mac|wsl|linux (auto-detects via uname if unset)
#   PEON_NOTIF_STYLE    overlay|standard (reads config.json if unset)
#   PEON_DIR            peon-ping install dir (defaults to dirname of this script/..)
#   PEON_SYNC           1 = synchronous (for tests), 0 = async (default)
#   PEON_BUNDLE_ID      macOS terminal bundle ID for click-to-focus (empty = skip)
#   PEON_IDE_PID        macOS IDE ancestor PID for click-to-focus (empty = skip)
#   PEON_CMUX_*         cmux workspace/surface/socket/CLI for exact click-to-focus
#   PEON_NOTIF_POSITION notification position: top-center|top-right|top-left|bottom-right|bottom-left|bottom-center
#   PEON_NOTIF_DISMISS  dismiss time in seconds (0 = persistent until clicked)
#   TERM_PROGRAM        Terminal emulator name (for iTerm2/Kitty escape sequences)
set -uo pipefail

msg="${1:-}" title="${2:-}" color="${3:-red}" icon_path="${4:-}"

[ -z "$msg" ] && [ -z "$title" ] && exit 0

# --- Resolve PEON_DIR ---
if [ -z "${PEON_DIR:-}" ]; then
  PEON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

_notify_debug() {
  [ "${PEON_DEBUG:-0}" = "1" ] || return 0
  [ -n "${PEON_DIR:-}" ] || return 0
  local log_dir log_file ts
  log_dir="$PEON_DIR/logs"
  mkdir -p "$log_dir" 2>/dev/null || return 0
  log_file="$log_dir/peon-ping-$(date +%Y-%m-%d).log"
  if date '+%Y-%m-%dT%H:%M:%S.%3N' 2>/dev/null | grep -qE '\.[0-9]{3}$'; then
    ts=$(date '+%Y-%m-%dT%H:%M:%S.%3N')
  else
    ts=$(python3 -c "import datetime as d;n=d.datetime.now();print(n.strftime('%Y-%m-%dT%H:%M:%S.')+f'{n.microsecond//1000:03d}')" 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S.000')
  fi
  printf '%s [notify] %s\n' "$ts" "$*" >> "$log_file" 2>/dev/null || true
}

# --- Resolve platform ---
if [ -z "${PEON_PLATFORM:-}" ]; then
  case "$(uname -s)" in
    Darwin) PEON_PLATFORM="mac" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        PEON_PLATFORM="wsl"
      else
        PEON_PLATFORM="linux"
      fi ;;
    MSYS_NT*|MINGW*) PEON_PLATFORM="msys2" ;;
    *) PEON_PLATFORM="unknown" ;;
  esac
fi

# --- Resolve notification style ---
# MSYS2: convert path for Windows Python
_PEON_DIR_PY="$PEON_DIR"
[ "$PEON_PLATFORM" = "msys2" ] && _PEON_DIR_PY="$(cygpath -m "$PEON_DIR")"

if [ -z "${PEON_NOTIF_STYLE:-}" ]; then
  PEON_NOTIF_STYLE=$(python3 -c "
import json, sys
try:
    with open('${_PEON_DIR_PY}/config.json') as f:
        print(json.load(f).get('notification_style', 'overlay'))
except Exception:
    print('overlay')
" 2>/dev/null || echo "overlay")
fi

# --- Sync/async mode ---
use_bg=true
[ "${PEON_SYNC:-0}" = "1" ] && use_bg=false

# --- Resolve overlay theme ---
_resolve_overlay_theme() {
  local theme
  theme=$(python3 -c "
import json, sys
try:
    with open('${PEON_DIR}/config.json') as f:
        print(json.load(f).get('overlay_theme', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")
  case "$theme" in
    jarvis|glass|sakura) echo "$theme" ;;
    *) echo "" ;;
  esac
}

# --- Resolve overlay script path ---
_find_overlay() {
  local theme
  theme="$(_resolve_overlay_theme)"
  if [ -n "$theme" ]; then
    local p="$PEON_DIR/scripts/mac-overlay-${theme}.js"
    [ -f "$p" ] && { echo "$p"; return 0; }
    p="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mac-overlay-${theme}.js"
    [ -f "$p" ] && { echo "$p"; return 0; }
  fi
  # Fallback to default overlay
  local p="$PEON_DIR/scripts/mac-overlay.js"
  [ -f "$p" ] && { echo "$p"; return 0; }
  p="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mac-overlay.js"
  [ -f "$p" ] && { echo "$p"; return 0; }
  return 1
}

_find_cmux_focus_helper() {
  local p="$PEON_DIR/scripts/cmux-focus.sh"
  [ -f "$p" ] && { echo "$p"; return 0; }
  p="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cmux-focus.sh"
  [ -f "$p" ] && { echo "$p"; return 0; }
  return 1
}

_find_cmux_workspace_field_helper() {
  local p="$PEON_DIR/scripts/cmux-workspace-field.sh"
  [ -f "$p" ] && { echo "$p"; return 0; }
  p="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cmux-workspace-field.sh"
  [ -f "$p" ] && { echo "$p"; return 0; }
  return 1
}

_cmux_click_command() {
  local cmux_focus_helper="$1"
  local cmux_cli="$2"
  local cmux_socket_path="$3"
  local cmux_workspace_id="$4"
  local cmux_surface_id="$5"
  local click_args click_command

  [ -n "$cmux_focus_helper" ] || return 1
  [ -n "$cmux_cli" ] || return 1
  [ -n "$cmux_surface_id" ] || return 1

  click_args=("$cmux_focus_helper" "$cmux_cli" "$cmux_socket_path" "$cmux_workspace_id" "$cmux_surface_id")
  printf -v click_command '%q ' "${click_args[@]}"
  printf '%s\n' "${click_command% }"
}

_cmux_notify() {
  local cmux_cli="$1"
  local cmux_workspace_id="$2"
  local cmux_surface_id="$3"
  local title="$4"
  local subtitle="$5"
  local body="$6"
  local -a cmux_args=()

  [ -n "$cmux_cli" ] || return 1

  cmux_args+=(notify --title "$title")
  [ -n "$subtitle" ] && cmux_args+=(--subtitle "$subtitle")
  [ -n "$body" ] && cmux_args+=(--body "$body")
  [ -n "$cmux_workspace_id" ] && cmux_args+=(--workspace "$cmux_workspace_id")
  [ -n "$cmux_surface_id" ] && cmux_args+=(--surface "$cmux_surface_id")

  "$cmux_cli" "${cmux_args[@]}" >/dev/null 2>&1
}

_cmux_workspace_title() {
  local cmux_cli="$1"
  local cmux_workspace_id="$2"
  local workspace_field_helper

  [ -n "$cmux_cli" ] || return 1
  [ -n "$cmux_workspace_id" ] || return 1

  workspace_field_helper="$(_find_cmux_workspace_field_helper)" 2>/dev/null || return 1
  "$workspace_field_helper" title "$cmux_cli" "" "$cmux_workspace_id" 2>/dev/null
}

# --- Resolve pack icon from active pack's openpeon.json ---
_resolve_pack_icon() {
  [ -z "${PEON_DIR:-}" ] && return 1
  local active_pack
  active_pack=$(python3 -c "
import json, sys
try:
    with open('${_PEON_DIR_PY}/config.json') as f:
        d = json.load(f)
    print(d.get('default_pack', d.get('active_pack', '')))
except Exception:
    print('')
" 2>/dev/null) || return 1
  [ -z "$active_pack" ] && return 1
  local pack_dir="$PEON_DIR/packs/$active_pack"
  [ -d "$pack_dir" ] || return 1
  local pack_dir_py="$pack_dir"
  [ "$PEON_PLATFORM" = "msys2" ] && pack_dir_py="$(cygpath -m "$pack_dir" 2>/dev/null || echo "$pack_dir")"
  local icon_candidate
  icon_candidate=$(python3 -c "
import json, os, sys
pack_dir = '${pack_dir_py}'
for mname in ('openpeon.json', 'manifest.json'):
    mpath = os.path.join(pack_dir, mname)
    if os.path.exists(mpath):
        try:
            d = json.load(open(mpath))
            print(d.get('icon', ''))
        except Exception:
            print('')
        break
else:
    print('')
" 2>/dev/null) || return 1
  # Fallback: icon.png in pack directory
  if [ -z "$icon_candidate" ] && [ -f "$pack_dir/icon.png" ]; then
    echo "$pack_dir/icon.png"; return 0
  fi
  [ -z "$icon_candidate" ] && return 1
  # URL icon: download to .icon_cache/
  if [[ "$icon_candidate" == http://* ]] || [[ "$icon_candidate" == https://* ]]; then
    local cache_dir="$PEON_DIR/.icon_cache"
    mkdir -p "$cache_dir" 2>/dev/null || return 1
    local url_hash
    url_hash=$(python3 -c "import hashlib, sys; print(hashlib.md5(sys.argv[1].encode()).hexdigest())" "$icon_candidate" 2>/dev/null) || return 1
    local ext="${icon_candidate%%\?*}"; ext="${ext##*.}"
    [ "${#ext}" -gt 5 ] && ext="png"
    local cached="$cache_dir/${url_hash}.${ext}"
    if [ ! -f "$cached" ] && command -v curl &>/dev/null; then
      curl -sf --max-time 5 -L -o "$cached" "$icon_candidate" 2>/dev/null || rm -f "$cached" 2>/dev/null
    fi
    [ -f "$cached" ] && { echo "$cached"; return 0; }
    return 1
  fi
  # Local path: resolve and validate within pack directory
  local icon_resolved pack_root
  icon_resolved=$(python3 -c "import os, sys; print(os.path.realpath(os.path.join(sys.argv[1], sys.argv[2])))" "$pack_dir" "$icon_candidate" 2>/dev/null) || return 1
  pack_root=$(python3 -c "import os, sys; print(os.path.realpath(sys.argv[1]) + os.sep)" "$pack_dir" 2>/dev/null) || return 1
  if [ -n "$icon_resolved" ] && [ "${icon_resolved#"$pack_root"}" != "$icon_resolved" ] && [ -f "$icon_resolved" ]; then
    echo "$icon_resolved"; return 0
  fi
  return 1
}

# --- Default icon (pack icon from openpeon.json, fallback to peon-icon.png) ---
if [ -z "$icon_path" ]; then
  icon_path="$(_resolve_pack_icon 2>/dev/null || echo "")"
  [ -z "$icon_path" ] && icon_path="$PEON_DIR/docs/peon-icon.png"
fi

# ── Platform dispatch ────────────────────────────────────────────────────────
case "$PEON_PLATFORM" in
  mac)
    _notify_debug "dispatch style=${PEON_NOTIF_STYLE:-overlay} title=$(printf '%q' "$title") msg=$(printf '%q' "$msg")"
    overlay_script=""
    [ "${PEON_NOTIF_STYLE:-overlay}" = "overlay" ] && \
      overlay_script="$(_find_overlay)" 2>/dev/null || true
    bundle_id="${PEON_BUNDLE_ID:-}"
    ide_pid="${PEON_IDE_PID:-}"
    cmux_workspace_id="${PEON_CMUX_WORKSPACE_ID:-}"
    cmux_surface_id="${PEON_CMUX_SURFACE_ID:-}"
    cmux_socket_path="${PEON_CMUX_SOCKET_PATH:-}"
    cmux_cli="${PEON_CMUX_CLI:-}"
    cmux_target_ready=false
    [ -n "$cmux_cli" ] && [ -n "$cmux_workspace_id" ] && [ -n "$cmux_surface_id" ] && cmux_target_ready=true
    click_command="${PEON_CLICK_COMMAND:-}"
    cmux_focus_helper="$(_find_cmux_focus_helper)" 2>/dev/null || true
    if [ -z "$click_command" ]; then
      click_command="$(_cmux_click_command "$cmux_focus_helper" "$cmux_cli" "$cmux_socket_path" "$cmux_workspace_id" "$cmux_surface_id")" || true
    fi
    _notify_debug "mac overlay_script=$(printf '%q' "$overlay_script") bundle=$(printf '%q' "$bundle_id") click_command=$(printf '%q' "$click_command") workspace=$(printf '%q' "$cmux_workspace_id") surface=$(printf '%q' "$cmux_surface_id")"
    if [ -n "$overlay_script" ]; then
      # JXA Cocoa overlay — large, visible banner on all screens
      local_icon_arg=""
      [ -f "$icon_path" ] && local_icon_arg="$icon_path"
      overlay_msg="$msg"
      if [ "$cmux_target_ready" = "true" ] && [ -n "$title" ]; then
        overlay_msg="$title"
      fi
      _run_overlay() (
        # Kill stale overlay processes from prior invocations (older than 30s)
        # This prevents accumulation if NSTimer or watchdog failed to terminate them
        if command -v pgrep &>/dev/null; then
          local _stale_pids
          _stale_pids=$(pgrep -f "mac-overlay" 2>/dev/null || true)
          if [ -n "$_stale_pids" ]; then
            for _sp in $_stale_pids; do
              # ps etime format: [[dd-]hh:]mm:ss
              local _etime
              _etime=$(ps -o etime= -p "$_sp" 2>/dev/null | sed 's/^[[:space:]]*//' ) || continue
              case "$_etime" in
                *-*|*:*:*) kill "$_sp" 2>/dev/null || true ;;  # days or hours — definitely stale
                *:*)  # MM:SS format
                  local _mins="${_etime%%:*}"
                  [ "${_mins:-0}" -gt 0 ] && kill "$_sp" 2>/dev/null || true
                  ;;
              esac
            done
          fi
        fi
        slot_dir="/tmp/peon-ping-popups"; mkdir -p "$slot_dir"
        local session_id="${PEON_SESSION_ID:-}"
        local session_file=""
        local count=1
        local reuse_slot=-1

        # --- Session stacking: group notifications from the same Claude session ---
        local stacking_enabled="${PEON_NOTIF_STACKING:-true}"
        if [ "$stacking_enabled" = "true" ] && [ -n "$session_id" ]; then
          session_file="$slot_dir/.session-${session_id}"
          if [ -f "$session_file" ]; then
            local old_slot old_pid old_count
            IFS='|' read -r old_slot old_pid old_count < "$session_file" 2>/dev/null || true
            old_count="${old_count:-1}"
            count=$((old_count + 1))
            if [ -n "$old_pid" ]; then
              for _kp in $old_pid; do
                kill "$_kp" 2>/dev/null || true
              done
              local _w=0
              while [ "$_w" -lt 10 ] && [ -d "$slot_dir/slot-${old_slot}" ]; do
                sleep 0.05; _w=$((_w + 1))
              done
            fi
            if mkdir "$slot_dir/slot-${old_slot}" 2>/dev/null; then
              reuse_slot=$old_slot
            fi
          fi
        fi

        if [ "$reuse_slot" -ge 0 ]; then
          slot=$reuse_slot
        else
          slot=0
          while [ "$slot" -lt 5 ] && ! mkdir "$slot_dir/slot-$slot" 2>/dev/null; do
            slot=$((slot + 1))
          done
          if [ "$slot" -ge 5 ]; then
            find "$slot_dir" -maxdepth 1 -name 'slot-*' -mmin +1 -exec rm -rf {} + 2>/dev/null
            slot=0; mkdir -p "$slot_dir/slot-0"
          fi
        fi

        # Prepend count badge if stacked
        if [ "$count" -gt 1 ]; then
          msg="($count) $msg"
        fi

        local session_tty="${PEON_SESSION_TTY:-}"
        local overlay_msg="$msg"
        local subtitle="${PEON_MSG_SUBTITLE:-}"
        if [ -n "$title" ]; then
          overlay_msg="$title"
          [ -n "$msg" ] && [ -z "$subtitle" ] && subtitle="$msg"
        fi
        local dismiss_secs="${PEON_NOTIF_DISMISS:-4}"
        local notif_position="${PEON_NOTIF_POSITION:-top-center}"
        local notify_type="${PEON_NOTIFY_TYPE:-}"
        local all_screens="${PEON_NOTIF_ALL_SCREENS:-true}"
        local close_button="${PEON_NOTIF_CLOSE_BUTTON:-true}"

        # Prepend count badge if stacked
        if [ "$count" -gt 1 ]; then
          overlay_msg="($count) $overlay_msg"
        fi

        # argv[5]=bundle_id, argv[6]=ide_pid, argv[7]=session_tty, argv[8]=subtitle, argv[9]=position, argv[10]=notify_type, argv[11]=all_screens, argv[12]=screen_index, argv[13]=close_button
        local _overlay_pids=""
        if [ "$all_screens" = "true" ]; then
          local screen_count
          screen_count=$(osascript -l JavaScript -e 'ObjC.import("Cocoa"); $.NSScreen.screens.count' 2>/dev/null || echo 1)
          # Fall back to 1 if probe returned empty or non-numeric output
          # (e.g. restricted Macs, test environments with mock osascript).
          # Without this, `seq 0 -1` runs the overlay loop zero times and
          # no notification displays.
          if ! [[ "$screen_count" =~ ^[0-9]+$ ]] || [ "$screen_count" -lt 1 ]; then
            screen_count=1
          fi
          _notify_debug "overlay spawn mode=all-screens count=$screen_count dismiss=$dismiss_secs script=$(printf '%q' "$overlay_script")"
          for _si in $(seq 0 $((screen_count - 1))); do
            _notify_debug "overlay spawn screen=$_si"
            PEON_CLICK_COMMAND="$click_command" \
            PEON_CMUX_FOCUS_HELPER="$cmux_focus_helper" \
            PEON_CMUX_FOCUS_CLI="$cmux_cli" \
            PEON_CMUX_FOCUS_SOCKET="$cmux_socket_path" \
            PEON_CMUX_FOCUS_WORKSPACE="$cmux_workspace_id" \
            PEON_CMUX_FOCUS_SURFACE="$cmux_surface_id" \
            osascript -l JavaScript "$overlay_script" "$overlay_msg" "$color" "$local_icon_arg" "$slot" "$dismiss_secs" "$bundle_id" "$ide_pid" "$session_tty" "$subtitle" "$notif_position" "$notify_type" "$all_screens" "$_si" "$close_button" >/dev/null 2>&1 &
            _overlay_pids="$_overlay_pids $!"
          done
        else
          _notify_debug "overlay spawn mode=single dismiss=$dismiss_secs script=$(printf '%q' "$overlay_script")"
          PEON_CLICK_COMMAND="$click_command" \
          PEON_CMUX_FOCUS_HELPER="$cmux_focus_helper" \
          PEON_CMUX_FOCUS_CLI="$cmux_cli" \
          PEON_CMUX_FOCUS_SOCKET="$cmux_socket_path" \
          PEON_CMUX_FOCUS_WORKSPACE="$cmux_workspace_id" \
          PEON_CMUX_FOCUS_SURFACE="$cmux_surface_id" \
          osascript -l JavaScript "$overlay_script" "$overlay_msg" "$color" "$local_icon_arg" "$slot" "$dismiss_secs" "$bundle_id" "$ide_pid" "$session_tty" "$subtitle" "$notif_position" "$notify_type" "$all_screens" "" "$close_button" >/dev/null 2>&1 &
          _overlay_pids="$!"
        fi
        # Save session state for stacking
        if [ -n "$session_file" ]; then
          echo "${slot}|${_overlay_pids## }|${count}" > "$session_file"
        fi

        # Shell-level watchdog: kill if JXA terminate timer doesn't fire (macOS regression)
        # When dismiss_secs=0 (persistent), skip the watchdog — overlay stays until clicked.
        local _max_wait
        if [ "${dismiss_secs}" = "0" ]; then
          _max_wait=86400
        else
          _max_wait=$(python3 -c "print(int(float('${dismiss_secs}'))+5)" 2>/dev/null || echo '9')
        fi
        local _watchdog_pids=""
        for _pid in $_overlay_pids; do
          ( sleep "$_max_wait" && kill "$_pid" 2>/dev/null ) &
          _watchdog_pids="$_watchdog_pids $!"
          wait "$_pid" 2>/dev/null || true
          # Kill the watchdog now that the overlay has exited normally
          # This prevents orphaned sleep subshells from accumulating
          local _last_wd="${_watchdog_pids##* }"
          kill "$_last_wd" 2>/dev/null || true
          wait "$_last_wd" 2>/dev/null || true
        done
        rm -rf "$slot_dir/slot-$slot"
        # Use `if` instead of `&&` so the subshell's exit code is 0 even
        # when session_file is empty (the `[ -n "" ]` test returns 1,
        # which would propagate as notify.sh's exit code).
        if [ -n "$session_file" ]; then
          rm -f "$session_file"
        fi
      )
      if [ "$use_bg" = true ]; then _run_overlay & else _run_overlay; fi
    else
      # Standard notifications: terminal-native escape sequences or system notifications
      case "${TERM_PROGRAM:-}" in
        iTerm.app)
          # iTerm2 OSC 9 — notification with iTerm2 icon
          printf '\e]9;%s\007' "$title: $msg" > /dev/tty 2>/dev/null || true
          ;;
        kitty)
          # Kitty OSC 99
          printf '\e]99;i=peon:d=0;%s\e\\' "$title: $msg" > /dev/tty 2>/dev/null || true
          ;;
        *)
          notif_subtitle="${PEON_MSG_SUBTITLE:-}"
          if [ "$cmux_target_ready" = "true" ]; then
            if [ "$use_bg" = true ]; then
              cmux_notify_args=()
              cmux_notify_args+=(notify --title "$title")
              [ -n "$notif_subtitle" ] && cmux_notify_args+=(--subtitle "$notif_subtitle")
              cmux_notify_args+=(--body "$msg" --workspace "$cmux_workspace_id" --surface "$cmux_surface_id")
              nohup "$cmux_cli" "${cmux_notify_args[@]}" >/dev/null 2>&1 &
            else
              _cmux_notify "$cmux_cli" "$cmux_workspace_id" "$cmux_surface_id" "$title" "$notif_subtitle" "$msg" || true
            fi
          else
            # Native macOS Notification Center (grouped by session, rich subtitle)
            notif_group="peon-ping-${PEON_SESSION_ID:-default}"
            if command -v terminal-notifier &>/dev/null; then
              tn_args=(-title "$title" -message "$msg")
              [ -n "$notif_subtitle" ] && tn_args+=(-subtitle "$notif_subtitle")
              [ -f "$icon_path" ] && tn_args+=(-appIcon "$icon_path")
              [ -n "$bundle_id" ] && tn_args+=(-activate "$bundle_id")

              if [ -n "$click_command" ]; then
                printf -v cmux_focus_cmd '/bin/bash -lc %q' "$click_command"
                tn_args+=(-execute "$cmux_focus_cmd")
              fi
              _notify_debug "standard terminal-notifier group=$(printf '%q' "$notif_group") activate=$(printf '%q' "$bundle_id") execute=$(printf '%q' "${cmux_focus_cmd:-}")"

              tn_args+=(-group "$notif_group")
              # -group makes consecutive notifications from the same session replace each other in Notification Center
              if [ "$use_bg" = true ]; then
                nohup terminal-notifier "${tn_args[@]}" >/dev/null 2>&1 &
              else
                terminal-notifier "${tn_args[@]}" >/dev/null 2>&1
              fi
            else
              # Fallback: osascript `display notification` — supports subtitle since 10.9
              if [ "$use_bg" = true ]; then
                nohup osascript - "$msg" "$title" "$notif_subtitle" >/dev/null 2>&1 <<'APPLESCRIPT' &
on run argv
  set msg to item 1 of argv
  set tit to item 2 of argv
  set sub to item 3 of argv
  if sub is "" then
    display notification msg with title tit
  else
    display notification msg with title tit subtitle sub
  end if
end run
APPLESCRIPT
              else
                osascript - "$msg" "$title" "$notif_subtitle" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  set msg to item 1 of argv
  set tit to item 2 of argv
  set sub to item 3 of argv
  if sub is "" then
    display notification msg with title tit
  else
    display notification msg with title tit subtitle sub
  end if
end run
APPLESCRIPT
              fi
            fi
          fi
          ;;
      esac
    fi
    ;;
  wsl)
    if [ "${PEON_NOTIF_STYLE:-overlay}" = "standard" ]; then
      # Windows toast notification (no focus stealing, appears in Action Center)
      tmpdir=$(powershell.exe -NoProfile -NonInteractive -Command '[System.IO.Path]::GetTempPath()' 2>/dev/null | tr -d '\r')
      tmpdir_wsl="$(wslpath -u "$tmpdir")"
      # Copy icon to Windows temp if available
      icon_xml=""
      if [ -f "$icon_path" ]; then
        cp "$icon_path" "${tmpdir_wsl}peon-ping-icon.png" 2>/dev/null
        icon_xml="<image placement=\"appLogoOverride\" hint-crop=\"circle\" src=\"${tmpdir}peon-ping-icon.png\" />"
      fi
      # Extract just the action part from msg (remove repeated project name)
      toast_body="$msg"
      if [[ "$msg" == *" — "* ]]; then
        toast_body="${msg##* — }"
      fi
      # Strip leading marker (● ) from title for cleaner toast
      toast_title="${title#● }"
      # Escape XML special characters to prevent malformed toast XML
      _escape_xml() { printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037' | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\"/\&quot;/g; s/'/\&apos;/g"; }
      toast_title="$(_escape_xml "$toast_title")"
      toast_body="$(_escape_xml "$toast_body")"
      # Write toast XML to temp file (avoids bash/powershell escaping issues)
      # launch="parentPid=0" placeholder for forward compatibility with click-to-focus (Phase 2)
      cat > "${tmpdir_wsl}peon-toast.xml" <<TOASTEOF
<toast launch="parentPid=0" duration="short"><visual><binding template="ToastGeneric"><text>${toast_body}</text><text>${toast_title}</text>${icon_xml}</binding></visual><audio silent="true" /></toast>
TOASTEOF
      _run_toast() {
        setsid powershell.exe -NoProfile -NonInteractive -Command '
          [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
          [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
          $APP_ID = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"
          $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
          $xml.LoadXml((Get-Content ($env:TEMP + "\peon-toast.xml") -Raw -Encoding UTF8))
          $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
          [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
          Remove-Item ($env:TEMP + "\peon-toast.xml") -ErrorAction SilentlyContinue
        ' &>/dev/null
      }
      if [ "$use_bg" = true ]; then _run_toast & else _run_toast; fi
    else
      # Legacy Windows Forms popup
      rgb_r=180 rgb_g=0 rgb_b=0
      case "$color" in
        blue)   rgb_r=30  rgb_g=80  rgb_b=180 ;;
        yellow) rgb_r=200 rgb_g=160 rgb_b=0   ;;
        red)    rgb_r=180 rgb_g=0   rgb_b=0   ;;
      esac
      icon_win_path=""
      if [ -f "$icon_path" ]; then
        icon_win_path=$(wslpath -w "$icon_path" 2>/dev/null || true)
      fi
      _run_forms_popup() {
        slot_dir="/tmp/peon-ping-popups"
        mkdir -p "$slot_dir"
        slot=0
        while [ "$slot" -lt 5 ] && ! mkdir "$slot_dir/slot-$slot" 2>/dev/null; do
          slot=$((slot + 1))
        done
        if [ "$slot" -ge 5 ]; then
          find "$slot_dir" -maxdepth 1 -name 'slot-*' -mmin +1 -exec rm -rf {} + 2>/dev/null
          slot=0; mkdir -p "$slot_dir/slot-0"
        fi
        local dismiss_secs="${PEON_NOTIF_DISMISS:-4}"
        y_offset=$((40 + slot * 90))
        # Security: pass message via temp file to avoid PowerShell injection from untrusted $msg
        tmpmsg=$(mktemp) && printf '%s' "$msg" > "$tmpmsg"
        powershell.exe -NoProfile -NonInteractive -Command "
          Add-Type -AssemblyName System.Windows.Forms
          Add-Type -AssemblyName System.Drawing
          Add-Type @'
using System;
using System.Windows.Forms;
public class NoActivateForm : Form {
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000;
            return cp;
        }
    }
}
'@ -ReferencedAssemblies System.Windows.Forms
          \$msgPath = '$tmpmsg'
          \$msgText = if (Test-Path \$msgPath) { (Get-Content -Raw \$msgPath) } else { '' }
          foreach (\$screen in [System.Windows.Forms.Screen]::AllScreens) {
            \$form = New-Object NoActivateForm
            \$form.FormBorderStyle = 'None'
            \$form.BackColor = [System.Drawing.Color]::FromArgb($rgb_r, $rgb_g, $rgb_b)
            \$form.Size = New-Object System.Drawing.Size(500, 80)
            \$form.TopMost = \$true
            \$form.ShowInTaskbar = \$false
            \$form.StartPosition = 'Manual'
            \$form.Location = New-Object System.Drawing.Point(
              (\$screen.WorkingArea.X + (\$screen.WorkingArea.Width - 500) / 2),
              (\$screen.WorkingArea.Y + $y_offset)
            )
            \$iconLeft = 10
            \$iconSize = 60
            if ('$icon_win_path' -ne '' -and (Test-Path '$icon_win_path')) {
              \$pb = New-Object System.Windows.Forms.PictureBox
              \$pb.Image = [System.Drawing.Image]::FromFile('$icon_win_path')
              \$pb.SizeMode = 'Zoom'
              \$pb.Size = New-Object System.Drawing.Size(\$iconSize, \$iconSize)
              \$pb.Location = New-Object System.Drawing.Point(\$iconLeft, 10)
              \$pb.BackColor = [System.Drawing.Color]::Transparent
              \$form.Controls.Add(\$pb)
              \$label = New-Object System.Windows.Forms.Label
              \$label.Location = New-Object System.Drawing.Point((\$iconLeft + \$iconSize + 5), 0)
              \$label.Size = New-Object System.Drawing.Size((500 - \$iconLeft - \$iconSize - 15), 80)
            } else {
              \$label = New-Object System.Windows.Forms.Label
              \$label.Dock = 'Fill'
            }
            \$label.Text = \$msgText
            \$label.ForeColor = [System.Drawing.Color]::White
            \$label.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
            \$label.TextAlign = 'MiddleCenter'
            \$form.Controls.Add(\$label)
            \$form.Show()
          }
          if ($dismiss_secs -gt 0) { Start-Sleep -Seconds $dismiss_secs; [System.Windows.Forms.Application]::Exit() }
          else { [System.Windows.Forms.Application]::Run() }
          if (Test-Path \$msgPath) { Remove-Item -Force \$msgPath }
        " &>/dev/null
        rm -rf "$slot_dir/slot-$slot"
      }
      if [ "$use_bg" = true ]; then _run_forms_popup & else _run_forms_popup; fi
    fi
    ;;
  linux)
    if command -v notify-send &>/dev/null; then
      # Always use urgency=normal so notification daemons (dunst, mako) honour
      # --expire-time and do not pin the notification until manually dismissed.
      # Error sounds are already visually distinct via title/color — no need for
      # urgency=critical which overrides the user's dismiss-time setting (#378).
      urgency="normal"
      icon_flag=""
      dismiss_mili_secs=$(( ${PEON_NOTIF_DISMISS:-4} * 1000 ))
      if [ -f "$icon_path" ]; then
        icon_flag="--icon=$icon_path"
      fi
      expire_time_flag=""
      if (( dismiss_mili_secs > 0 )); then
        expire_time_flag="--expire-time=$dismiss_mili_secs"
      fi
      if [ "$use_bg" = true ]; then
        nohup notify-send --urgency="$urgency" $expire_time_flag $icon_flag "$title" "$msg" >/dev/null 2>&1 &
      else
        notify-send --urgency="$urgency" $expire_time_flag $icon_flag "$title" "$msg" >/dev/null 2>&1
      fi
    fi
    ;;
  msys2)
    if [ "${PEON_NOTIF_STYLE:-overlay}" = "standard" ]; then
      # Windows toast notification via PowerShell (same as WSL but uses cygpath)
      tmpdir="${TEMP:-/tmp}"
      # Copy icon to temp if available
      icon_xml=""
      if [ -f "$icon_path" ]; then
        cp "$icon_path" "${tmpdir}/peon-ping-icon.png" 2>/dev/null
        icon_win="${tmpdir}\\peon-ping-icon.png"
        icon_xml="<image placement=\"appLogoOverride\" hint-crop=\"circle\" src=\"${icon_win}\" />"
      fi
      # Extract just the action part from msg
      toast_body="$msg"
      if [[ "$msg" == *" — "* ]]; then
        toast_body="${msg##* — }"
      fi
      toast_title="${title#● }"
      _escape_xml() { printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037' | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\"/\&quot;/g; s/'/\&apos;/g"; }
      toast_title="$(_escape_xml "$toast_title")"
      toast_body="$(_escape_xml "$toast_body")"
      toast_xml_file="${tmpdir}/peon-toast.xml"
      # launch="parentPid=0" placeholder for forward compatibility with click-to-focus (Phase 2)
      cat > "$toast_xml_file" <<TOASTEOF
<toast launch="parentPid=0" duration="short"><visual><binding template="ToastGeneric"><text>${toast_body}</text><text>${toast_title}</text>${icon_xml}</binding></visual><audio silent="true" /></toast>
TOASTEOF
      toast_xml_win=$(cygpath -w "$toast_xml_file")
      _run_toast() {
        powershell.exe -NoProfile -NonInteractive -Command "
          [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
          [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null
          \$APP_ID = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
          \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
          \$xml.LoadXml((Get-Content '$toast_xml_win' -Raw -Encoding UTF8))
          \$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml
          [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$APP_ID).Show(\$toast)
          Remove-Item '$toast_xml_win' -ErrorAction SilentlyContinue
        " &>/dev/null
      }
      if [ "$use_bg" = true ]; then _run_toast & else _run_toast; fi
    else
      # Windows Forms overlay popup (same as WSL but uses cygpath)
      rgb_r=180 rgb_g=0 rgb_b=0
      case "$color" in
        blue)   rgb_r=30  rgb_g=80  rgb_b=180 ;;
        yellow) rgb_r=200 rgb_g=160 rgb_b=0   ;;
        red)    rgb_r=180 rgb_g=0   rgb_b=0   ;;
      esac
      icon_win_path=""
      if [ -f "$icon_path" ]; then
        icon_win_path=$(cygpath -w "$icon_path" 2>/dev/null || true)
      fi
      _run_forms_popup() {
        slot_dir="/tmp/peon-ping-popups"
        mkdir -p "$slot_dir"
        slot=0
        while [ "$slot" -lt 5 ] && ! mkdir "$slot_dir/slot-$slot" 2>/dev/null; do
          slot=$((slot + 1))
        done
        if [ "$slot" -ge 5 ]; then
          find "$slot_dir" -maxdepth 1 -name 'slot-*' -mmin +1 -exec rm -rf {} + 2>/dev/null
          slot=0; mkdir -p "$slot_dir/slot-0"
        fi
        local dismiss_secs="${PEON_NOTIF_DISMISS:-4}"
        y_offset=$((40 + slot * 90))
        tmpmsg=$(mktemp) && printf '%s' "$msg" > "$tmpmsg"
        tmpmsg_win=$(cygpath -w "$tmpmsg")
        powershell.exe -NoProfile -NonInteractive -Command "
          Add-Type -AssemblyName System.Windows.Forms
          Add-Type -AssemblyName System.Drawing
          Add-Type @'
using System;
using System.Windows.Forms;
public class NoActivateForm : Form {
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000;
            return cp;
        }
    }
}
'@ -ReferencedAssemblies System.Windows.Forms
          \$msgText = if (Test-Path '$tmpmsg_win') { (Get-Content -Raw '$tmpmsg_win') } else { '' }
          foreach (\$screen in [System.Windows.Forms.Screen]::AllScreens) {
            \$form = New-Object NoActivateForm
            \$form.FormBorderStyle = 'None'
            \$form.BackColor = [System.Drawing.Color]::FromArgb($rgb_r, $rgb_g, $rgb_b)
            \$form.Size = New-Object System.Drawing.Size(500, 80)
            \$form.TopMost = \$true
            \$form.ShowInTaskbar = \$false
            \$form.StartPosition = 'Manual'
            \$form.Location = New-Object System.Drawing.Point(
              (\$screen.WorkingArea.X + (\$screen.WorkingArea.Width - 500) / 2),
              (\$screen.WorkingArea.Y + $y_offset)
            )
            \$iconLeft = 10
            \$iconSize = 60
            if ('$icon_win_path' -ne '' -and (Test-Path '$icon_win_path')) {
              \$pb = New-Object System.Windows.Forms.PictureBox
              \$pb.Image = [System.Drawing.Image]::FromFile('$icon_win_path')
              \$pb.SizeMode = 'Zoom'
              \$pb.Size = New-Object System.Drawing.Size(\$iconSize, \$iconSize)
              \$pb.Location = New-Object System.Drawing.Point(\$iconLeft, 10)
              \$pb.BackColor = [System.Drawing.Color]::Transparent
              \$form.Controls.Add(\$pb)
              \$label = New-Object System.Windows.Forms.Label
              \$label.Location = New-Object System.Drawing.Point((\$iconLeft + \$iconSize + 5), 0)
              \$label.Size = New-Object System.Drawing.Size((500 - \$iconLeft - \$iconSize - 15), 80)
            } else {
              \$label = New-Object System.Windows.Forms.Label
              \$label.Dock = 'Fill'
            }
            \$label.Text = \$msgText
            \$label.ForeColor = [System.Drawing.Color]::White
            \$label.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
            \$label.TextAlign = 'MiddleCenter'
            \$form.Controls.Add(\$label)
            \$form.Show()
          }
          if ($dismiss_secs -gt 0) { Start-Sleep -Seconds $dismiss_secs; [System.Windows.Forms.Application]::Exit() }
          else { [System.Windows.Forms.Application]::Run() }
          if (Test-Path '$tmpmsg_win') { Remove-Item -Force '$tmpmsg_win' }
        " &>/dev/null
        rm -rf "$slot_dir/slot-$slot"
      }
      if [ "$use_bg" = true ]; then _run_forms_popup & else _run_forms_popup; fi
    fi
    ;;
esac
