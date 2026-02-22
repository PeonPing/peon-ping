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
#   TERM_PROGRAM        Terminal emulator name (for iTerm2/Kitty escape sequences)
set -uo pipefail

msg="${1:-}" title="${2:-}" color="${3:-red}" icon_path="${4:-}"

[ -z "$msg" ] && exit 0

# --- Resolve PEON_DIR ---
if [ -z "${PEON_DIR:-}" ]; then
  PEON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

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

# --- Default icon ---
[ -z "$icon_path" ] && icon_path="$PEON_DIR/docs/peon-icon.png"

# --- Sync/async mode ---
use_bg=true
[ "${PEON_SYNC:-0}" = "1" ] && use_bg=false

# --- Resolve overlay script path ---
_find_overlay() {
  local p="$PEON_DIR/scripts/mac-overlay.js"
  [ -f "$p" ] && { echo "$p"; return 0; }
  p="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mac-overlay.js"
  [ -f "$p" ] && { echo "$p"; return 0; }
  return 1
}

# ── Platform dispatch ────────────────────────────────────────────────────────
case "$PEON_PLATFORM" in
  mac)
    overlay_script=""
    [ "${PEON_NOTIF_STYLE:-overlay}" = "overlay" ] && \
      overlay_script="$(_find_overlay)" 2>/dev/null || true
    bundle_id="${PEON_BUNDLE_ID:-}"
    ide_pid="${PEON_IDE_PID:-}"
    if [ -n "$overlay_script" ]; then
      # JXA Cocoa overlay — large, visible banner on all screens
      local_icon_arg=""
      [ -f "$icon_path" ] && local_icon_arg="$icon_path"
      _run_overlay() (
        slot_dir="/tmp/peon-ping-popups"; mkdir -p "$slot_dir"
        slot=0
        while [ "$slot" -lt 5 ] && ! mkdir "$slot_dir/slot-$slot" 2>/dev/null; do
          slot=$((slot + 1))
        done
        if [ "$slot" -ge 5 ]; then
          find "$slot_dir" -maxdepth 1 -name 'slot-*' -mmin +1 -exec rm -rf {} + 2>/dev/null
          slot=0; mkdir -p "$slot_dir/slot-0"
        fi
        # argv[5]=bundle_id (terminal click-to-focus), argv[6]=ide_pid (IDE click-to-focus)
        osascript -l JavaScript "$overlay_script" "$msg" "$color" "$local_icon_arg" "$slot" "4" "$bundle_id" "$ide_pid" >/dev/null 2>&1 || true
        rm -rf "$slot_dir/slot-$slot"
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
          if command -v terminal-notifier &>/dev/null; then
            # terminal-notifier: custom icon + click-to-focus via -activate
            tn_icon_flag=""
            [ -f "$icon_path" ] && tn_icon_flag="-appIcon $icon_path"
            tn_activate_flag=""
            [ -n "$bundle_id" ] && tn_activate_flag="-activate $bundle_id"
            if [ "$use_bg" = true ]; then
              # shellcheck disable=SC2086
              nohup terminal-notifier \
                -title "$title" \
                -message "$msg" \
                $tn_icon_flag \
                $tn_activate_flag \
                -group "peon-ping" >/dev/null 2>&1 &
            else
              # shellcheck disable=SC2086
              terminal-notifier \
                -title "$title" \
                -message "$msg" \
                $tn_icon_flag \
                $tn_activate_flag \
                -group "peon-ping" >/dev/null 2>&1
            fi
          else
            # Terminal.app, Warp, Ghostty, etc. — no native escape; use osascript
            if [ "$use_bg" = true ]; then
              nohup osascript - "$msg" "$title" >/dev/null 2>&1 <<'APPLESCRIPT' &
on run argv
  display notification (item 1 of argv) with title (item 2 of argv)
end run
APPLESCRIPT
            else
              osascript - "$msg" "$title" >/dev/null 2>&1 <<'APPLESCRIPT'
on run argv
  display notification (item 1 of argv) with title (item 2 of argv)
end run
APPLESCRIPT
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
      cat > "${tmpdir_wsl}peon-toast.xml" <<TOASTEOF
<toast duration="short"><visual><binding template="ToastGeneric"><text>${toast_body}</text><text>${toast_title}</text>${icon_xml}</binding></visual><audio silent="true" /></toast>
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
        y_offset=$((40 + slot * 90))
        # Security: pass message via temp file to avoid PowerShell injection from untrusted $msg
        tmpmsg=$(mktemp) && printf '%s' "$msg" > "$tmpmsg"
        powershell.exe -NoProfile -NonInteractive -Command "
          Add-Type -AssemblyName System.Windows.Forms
          Add-Type -AssemblyName System.Drawing
          \$msgPath = '$tmpmsg'
          \$msgText = if (Test-Path \$msgPath) { (Get-Content -Raw \$msgPath) } else { '' }
          foreach (\$screen in [System.Windows.Forms.Screen]::AllScreens) {
            \$form = New-Object System.Windows.Forms.Form
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
          Start-Sleep -Seconds 4
          [System.Windows.Forms.Application]::Exit()
          if (Test-Path \$msgPath) { Remove-Item -Force \$msgPath }
        " &>/dev/null
        rm -rf "$slot_dir/slot-$slot"
      }
      if [ "$use_bg" = true ]; then _run_forms_popup & else _run_forms_popup; fi
    fi
    ;;
  linux)
    if command -v notify-send &>/dev/null; then
      urgency="normal"
      case "$color" in
        red) urgency="critical" ;;
      esac
      icon_flag=""
      if [ -f "$icon_path" ]; then
        icon_flag="--icon=$icon_path"
      fi
      if [ "$use_bg" = true ]; then
        nohup notify-send --urgency="$urgency" --expire-time=5000 $icon_flag "$title" "$msg" >/dev/null 2>&1 &
      else
        notify-send --urgency="$urgency" --expire-time=5000 $icon_flag "$title" "$msg" >/dev/null 2>&1
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
      cat > "$toast_xml_file" <<TOASTEOF
<toast duration="short"><visual><binding template="ToastGeneric"><text>${toast_body}</text><text>${toast_title}</text>${icon_xml}</binding></visual><audio silent="true" /></toast>
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
        y_offset=$((40 + slot * 90))
        tmpmsg=$(mktemp) && printf '%s' "$msg" > "$tmpmsg"
        tmpmsg_win=$(cygpath -w "$tmpmsg")
        powershell.exe -NoProfile -NonInteractive -Command "
          Add-Type -AssemblyName System.Windows.Forms
          Add-Type -AssemblyName System.Drawing
          \$msgText = if (Test-Path '$tmpmsg_win') { (Get-Content -Raw '$tmpmsg_win') } else { '' }
          foreach (\$screen in [System.Windows.Forms.Screen]::AllScreens) {
            \$form = New-Object System.Windows.Forms.Form
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
          Start-Sleep -Seconds 4
          [System.Windows.Forms.Application]::Exit()
          if (Test-Path '$tmpmsg_win') { Remove-Item -Force '$tmpmsg_win' }
        " &>/dev/null
        rm -rf "$slot_dir/slot-$slot"
      }
      if [ "$use_bg" = true ]; then _run_forms_popup & else _run_forms_popup; fi
    fi
    ;;
esac
