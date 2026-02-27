#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  export PLATFORM=mac

  # Enable desktop notifications in config
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": true,
  "categories": {
    "session.start": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10
}
JSON

  # Create scripts dir and copy overlay script (use PEON_SH parent for source location)
  mkdir -p "$TEST_DIR/scripts"
  _src_dir="$(cd "$(dirname "$PEON_SH")" && pwd)"
  cp "$_src_dir/scripts/mac-overlay.js" "$TEST_DIR/scripts/mac-overlay.js"
}

teardown() {
  teardown_test_env
}

# Helper: check if overlay was called
overlay_was_called() {
  [ -f "$TEST_DIR/overlay.log" ] && [ -s "$TEST_DIR/overlay.log" ]
}

# Helper: get overlay log content
overlay_log() {
  cat "$TEST_DIR/overlay.log" 2>/dev/null
}

# ============================================================
# Default behavior (overlay)
# ============================================================

@test "macOS overlay notification enabled by default" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"-l JavaScript"* ]]
  [[ "$(overlay_log)" == *"mac-overlay.js"* ]]
}

@test "macOS overlay passes message argument" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject"* ]]
}

@test "macOS overlay passes color argument" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  # Stop events use blue color (task complete)
  [[ "$(overlay_log)" == *"blue"* ]]
}

@test "macOS overlay works without icon file" {
  rm -f "$TEST_DIR/docs/peon-icon.png" 2>/dev/null
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
}

@test "macOS overlay passes icon path when icon exists" {
  mkdir -p "$TEST_DIR/docs"
  echo "fake-png" > "$TEST_DIR/docs/peon-icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"peon-icon.png"* ]]
}

@test "macOS overlay passes pack-specific icon when set" {
  # Set pack-level icon in manifest
  python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['icon'] = 'pack-icon.png'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  echo "fake-png" > "$TEST_DIR/packs/peon/pack-icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"pack-icon.png"* ]]
}

@test "macOS overlay passes bundle ID for Ghostty click-to-focus" {
  TERM_PROGRAM=ghostty run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"com.mitchellh.ghostty"* ]]
}

@test "macOS overlay passes bundle ID for Warp click-to-focus" {
  TERM_PROGRAM=WarpTerminal run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"dev.warp.Warp-Stable"* ]]
}

@test "macOS overlay passes bundle ID for Zed click-to-focus" {
  TERM_PROGRAM=zed run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"dev.zed.Zed"* ]]
}

@test "macOS overlay passes empty bundle ID for unknown terminal" {
  # Unknown terminal — bundle ID should be empty (no -activate)
  TERM_PROGRAM=unknown_terminal run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  # Should not contain any bundle ID patterns
  ! [[ "$(overlay_log)" == *"com.mitchellh"* ]]
  ! [[ "$(overlay_log)" == *"com.apple.Terminal"* ]]
}

# ============================================================
# IDE embedded terminal click-to-focus (lsappinfo fallback)
# ============================================================

@test "overlay: _mac_bundle_id_from_pid returns bundle ID via lsappinfo" {
  echo "com.todesktop.230313mzl4w4u92" > "$TEST_DIR/.mock_ide_bundle_id"
  # Call lsappinfo directly (mocked) to verify the mock works
  # CLAUDE_PEON_DIR must be set for the mock to find the fixture file
  result=$(CLAUDE_PEON_DIR="$TEST_DIR" "$MOCK_BIN/lsappinfo" info -only bundleid -app pid:12345 2>/dev/null | sed -n 's/.*="\([^"]*\)".*/\1/p')
  [ "$result" = "com.todesktop.230313mzl4w4u92" ]
}

@test "overlay: _mac_bundle_id_from_pid returns empty when lsappinfo has no data" {
  # No .mock_ide_bundle_id file — lsappinfo exits 1
  result=$("$MOCK_BIN/lsappinfo" info -only bundleid -app pid=99999 2>/dev/null | grep -o '"[^"]*"' | tr -d '"' || true)
  [ -z "$result" ]
}

@test "overlay: IDE bundle ID passed to overlay via notify.sh env" {
  # Directly call notify.sh with PEON_BUNDLE_ID set (simulates the fallback path)
  local notify_script="$TEST_DIR/scripts/notify.sh"
  PEON_PLATFORM=mac PEON_NOTIF_STYLE=overlay PEON_SYNC=1 \
    PEON_BUNDLE_ID="com.todesktop.230313mzl4w4u92" PEON_IDE_PID="12345" \
    bash "$notify_script" "test msg" "test title" "blue" ""
  overlay_was_called
  [[ "$(overlay_log)" == *"com.todesktop.230313mzl4w4u92"* ]]
}

@test "overlay: IDE PID passed to overlay when bundle ID empty" {
  # When bundle_id is empty but ide_pid is set, overlay still gets the PID
  local notify_script="$TEST_DIR/scripts/notify.sh"
  PEON_PLATFORM=mac PEON_NOTIF_STYLE=overlay PEON_SYNC=1 \
    PEON_BUNDLE_ID="" PEON_IDE_PID="12345" \
    bash "$notify_script" "test msg" "test title" "blue" ""
  overlay_was_called
  # The overlay receives ide_pid as argv[6]
  [[ "$(overlay_log)" == *"12345"* ]]
}

@test "standard: IDE bundle ID used for terminal-notifier -activate via notify.sh" {
  local notify_script="$TEST_DIR/scripts/notify.sh"
  PEON_PLATFORM=mac PEON_NOTIF_STYLE=standard PEON_SYNC=1 \
    PEON_BUNDLE_ID="com.microsoft.VSCode" PEON_IDE_PID="12345" \
    bash "$notify_script" "test msg" "test title" "blue" ""
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  [[ "$(terminal_notifier_log)" == *"-activate"* ]]
  [[ "$(terminal_notifier_log)" == *"com.microsoft.VSCode"* ]]
}

@test "standard: no -activate when both bundle ID and IDE PID empty" {
  local notify_script="$TEST_DIR/scripts/notify.sh"
  PEON_PLATFORM=mac PEON_NOTIF_STYLE=standard PEON_SYNC=1 \
    PEON_BUNDLE_ID="" PEON_IDE_PID="" \
    bash "$notify_script" "test msg" "test title" "blue" ""
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  ! [[ "$(terminal_notifier_log)" == *"-activate"* ]]
}

# ============================================================
# Standard mode fallback
# ============================================================

@test "macOS standard notification uses terminal-notifier when available" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": true,
  "notification_style": "standard",
  "categories": {
    "session.start": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Overlay should NOT be called
  ! overlay_was_called
  # terminal-notifier should be used (falls back to osascript only when unavailable)
  [ -f "$TEST_DIR/terminal_notifier.log" ]
}

@test "macOS standard notification falls back to osascript when terminal-notifier unavailable" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": true,
  "notification_style": "standard",
  "categories": { "task.complete": true }
}
JSON
  # Remove terminal-notifier from PATH by restricting to system binaries only
  OLD_PATH="$PATH"
  export PATH="$MOCK_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
  # Ensure no terminal-notifier in this restricted PATH
  rm -f "$MOCK_BIN/terminal-notifier"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  export PATH="$OLD_PATH"
  [ "$PEON_EXIT" -eq 0 ]
  ! overlay_was_called
  [ -f "$TEST_DIR/osascript.log" ]
  ! [ -f "$TEST_DIR/terminal_notifier.log" ]
}

# ============================================================
# CLI toggle
# ============================================================

@test "peon notifications overlay sets notification_style in config" {
  bash "$PEON_SH" notifications overlay
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_style'] == 'overlay', f'Expected overlay, got {cfg[\"notification_style\"]}'
"
}

@test "peon notifications standard sets notification_style in config" {
  bash "$PEON_SH" notifications standard
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_style'] == 'standard', f'Expected standard, got {cfg[\"notification_style\"]}'
"
}

@test "peon notifications overlay then standard toggles correctly" {
  bash "$PEON_SH" notifications overlay
  bash "$PEON_SH" notifications standard
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_style'] == 'standard', f'Expected standard, got {cfg[\"notification_style\"]}'
"
}

# ============================================================
# Status display
# ============================================================

@test "peon status shows notification style" {
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"notification style overlay"* ]]
}

# ============================================================
# Notification test command
# ============================================================

@test "peon notifications test sends overlay notification" {
  output=$(PEON_TEST=1 bash "$PEON_SH" notifications test 2>/dev/null)
  [[ "$output" == *"sending test notification"* ]]
  overlay_was_called
  [[ "$(overlay_log)" == *"test notification"* ]]
}

@test "peon notifications test sends standard notification" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": true,
  "notification_style": "standard",
  "categories": {}
}
JSON
  output=$(PEON_TEST=1 bash "$PEON_SH" notifications test 2>/dev/null)
  [[ "$output" == *"sending test notification"* ]]
  ! overlay_was_called
  # terminal-notifier is used when available (mocked in test env)
  [ -f "$TEST_DIR/terminal_notifier.log" ]
}

@test "peon notifications test errors when notifications are off" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": false,
  "categories": {}
}
JSON
  run bash "$PEON_SH" notifications test
  [ "$status" -eq 1 ]
  [[ "$output" == *"desktop notifications are off"* ]]
}

# ============================================================
# Status display
# ============================================================

@test "peon status shows standard when configured" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard" }
JSON
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"notification style standard"* ]]
}

# ============================================================
# Click-to-focus: terminal-notifier -activate (standard style)
# ============================================================

terminal_notifier_log() {
  cat "$TEST_DIR/terminal_notifier.log" 2>/dev/null
}

@test "standard: terminal-notifier used when available (no icon)" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "desktop_notifications": true, "notification_style": "standard", "categories": { "task.complete": true } }
JSON
  TERM_PROGRAM= run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! overlay_was_called
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  ! [ -f "$TEST_DIR/osascript.log" ]
}

@test "standard: terminal-notifier includes -activate for Ghostty" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "desktop_notifications": true, "notification_style": "standard", "categories": { "task.complete": true } }
JSON
  TERM_PROGRAM=ghostty run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  [[ "$(terminal_notifier_log)" == *"-activate"* ]]
  [[ "$(terminal_notifier_log)" == *"com.mitchellh.ghostty"* ]]
}

@test "standard: terminal-notifier includes -activate for Warp" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "desktop_notifications": true, "notification_style": "standard", "categories": { "task.complete": true } }
JSON
  TERM_PROGRAM=WarpTerminal run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  [[ "$(terminal_notifier_log)" == *"-activate"* ]]
  [[ "$(terminal_notifier_log)" == *"dev.warp.Warp-Stable"* ]]
}

@test "standard: terminal-notifier includes -activate for Zed" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "desktop_notifications": true, "notification_style": "standard", "categories": { "task.complete": true } }
JSON
  TERM_PROGRAM=zed run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  [[ "$(terminal_notifier_log)" == *"-activate"* ]]
  [[ "$(terminal_notifier_log)" == *"dev.zed.Zed"* ]]
}

@test "standard: terminal-notifier no -activate for unknown terminal" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "desktop_notifications": true, "notification_style": "standard", "categories": { "task.complete": true } }
JSON
  TERM_PROGRAM=some_unknown_term run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  ! [[ "$(terminal_notifier_log)" == *"-activate"* ]]
}

@test "standard: terminal-notifier includes -appIcon when icon exists" {
  mkdir -p "$TEST_DIR/docs"
  echo "fake-png" > "$TEST_DIR/docs/peon-icon.png"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "desktop_notifications": true, "notification_style": "standard", "categories": { "task.complete": true } }
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  [[ "$(terminal_notifier_log)" == *"-appIcon"* ]]
  [[ "$(terminal_notifier_log)" == *"peon-icon.png"* ]]
}

# ============================================================
# Configurable notification position (CLI)
# ============================================================

@test "peon notifications position shows current position" {
  output=$(bash "$PEON_SH" notifications position 2>/dev/null)
  [[ "$output" == *"notification position top-center"* ]]
}

@test "peon notifications position top-right sets config" {
  bash "$PEON_SH" notifications position top-right
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_position'] == 'top-right', f'Expected top-right, got {cfg[\"notification_position\"]}'
"
}

@test "peon notifications position rejects invalid value" {
  run bash "$PEON_SH" notifications position middle
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid position"* ]]
}

@test "peon notifications position bottom-left sets config" {
  bash "$PEON_SH" notifications position bottom-left
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_position'] == 'bottom-left'
"
}

@test "peon status shows notification position" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_position'] = 'top-right'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"notification position top-right"* ]]
}

@test "overlay passes position to mac-overlay.js" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_position'] = 'bottom-right'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"bottom-right"* ]]
}

# ============================================================
# Configurable dismiss time (CLI)
# ============================================================

@test "peon notifications dismiss shows current value" {
  output=$(bash "$PEON_SH" notifications dismiss 2>/dev/null)
  [[ "$output" == *"dismiss time"* ]]
}

@test "peon notifications dismiss 0 sets persistent mode" {
  bash "$PEON_SH" notifications dismiss 0
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_dismiss_seconds'] == 0, f'Expected 0, got {cfg[\"notification_dismiss_seconds\"]}'
"
}

@test "peon notifications dismiss 10 sets config" {
  bash "$PEON_SH" notifications dismiss 10
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_dismiss_seconds'] == 10
"
}

@test "peon notifications dismiss rejects negative" {
  run bash "$PEON_SH" notifications dismiss -1
  [ "$status" -eq 1 ]
  [[ "$output" == *"cannot be negative"* ]]
}

@test "peon notifications dismiss rejects non-numeric" {
  run bash "$PEON_SH" notifications dismiss abc
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid dismiss time"* ]]
}

@test "peon status shows dismiss time" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_dismiss_seconds'] = 8
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"dismiss time 8s"* ]]
}

@test "peon status shows persistent when dismiss is 0" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_dismiss_seconds'] = 0
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"persistent"* ]]
}

@test "overlay passes dismiss time to notify.sh" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_dismiss_seconds'] = 7
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  # Dismiss time is passed as argv[4] to mac-overlay.js (5th argument after script name)
  [[ "$(overlay_log)" == *" 7 "* ]]
}

# ============================================================
# Custom project label (CLI)
# ============================================================

@test "peon notifications label shows no override by default" {
  output=$(bash "$PEON_SH" notifications label 2>/dev/null)
  [[ "$output" == *"no label override"* ]]
}

@test "peon notifications label sets title override" {
  bash "$PEON_SH" notifications label "My Vault"
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_title_override'] == 'My Vault', f'Got: {cfg[\"notification_title_override\"]}'
"
}

@test "peon notifications label reset clears override" {
  bash "$PEON_SH" notifications label "My Vault"
  bash "$PEON_SH" notifications label reset
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert cfg['notification_title_override'] == '', f'Expected empty, got: {cfg[\"notification_title_override\"]}'
"
}

@test "peon notifications label shows override when set" {
  bash "$PEON_SH" notifications label "Test Label"
  output=$(bash "$PEON_SH" notifications label 2>/dev/null)
  [[ "$output" == *"label override: Test Label"* ]]
}

@test "peon status shows label override when set" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_title_override'] = 'Custom Name'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"label override: Custom Name"* ]]
}

# ============================================================
# Label priority chain (project name derivation)
# ============================================================

@test "label: .peon-label file takes highest priority" {
  mkdir -p /tmp/testproj
  echo "Label From File" > /tmp/testproj/.peon-label
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_title_override'] = 'Static Override'
cfg['project_name_map'] = {'*/testproj': 'Map Label'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/testproj","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"Label From File"* ]]
  rm -f /tmp/testproj/.peon-label
}

@test "label: project_name_map overrides static and folder" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_title_override'] = 'Static Override'
cfg['project_name_map'] = {'*/myproject': 'Mapped Name'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"Mapped Name"* ]]
}

@test "label: notification_title_override used when no file or map match" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_title_override'] = 'Global Label'
cfg['project_name_map'] = {}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"Global Label"* ]]
}

@test "label: falls back to folder name when no overrides" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_title_override'] = ''
cfg['project_name_map'] = {}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject"* ]]
}

# ============================================================
# Notification message templates
# ============================================================

@test "peon notifications template shows no templates by default" {
  output=$(bash "$PEON_SH" notifications template 2>/dev/null)
  [[ "$output" == *"no notification templates"* ]]
}

@test "peon notifications template stop sets config" {
  bash "$PEON_SH" notifications template stop '{project}: {summary}'
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
tpls = cfg.get('notification_templates', {})
assert tpls.get('stop') == '{project}: {summary}', f'Got: {tpls}'
"
}

@test "peon notifications template stop shows current value" {
  bash "$PEON_SH" notifications template stop '{project}: {summary}'
  output=$(bash "$PEON_SH" notifications template stop 2>/dev/null)
  [[ "$output" == *'{project}: {summary}'* ]]
}

@test "peon notifications template rejects invalid key" {
  run bash "$PEON_SH" notifications template bogus '{project}'
  [ "$status" -ne 0 ]
}

@test "peon notifications template --reset clears all templates" {
  bash "$PEON_SH" notifications template stop '{project}: {summary}'
  bash "$PEON_SH" notifications template permission '{project}: {tool_name}'
  bash "$PEON_SH" notifications template --reset
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
assert 'notification_templates' not in cfg, f'Templates still present: {cfg}'
"
}

@test "template: Stop with {summary} renders transcript_summary" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project}: {summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default","transcript_summary":"Fixed the login bug"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject: Fixed the login bug"* ]]
}

@test "template: Stop without transcript_summary renders empty summary" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project}: {summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject: "* ]]
}

@test "template: PermissionRequest with {tool_name}" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'permission': '{project}: {tool_name} needs approval'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default","tool_name":"Bash"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject: Bash needs approval"* ]]
}

@test "template: no template configured falls back to project name" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default","transcript_summary":"Some work done"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  local log
  log="$(overlay_log)"
  [[ "$log" == *"myproject"* ]]
  [[ "$log" != *"Some work done"* ]]
}

@test "template: unknown variable renders as empty string" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project} - {nonexistent}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  overlay_was_called
  [[ "$(overlay_log)" == *"myproject - "* ]]
}

@test "peon status shows templates when configured" {
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_templates'] = {'stop': '{project}: {summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  output=$(bash "$PEON_SH" status 2>/dev/null)
  [[ "$output" == *"notification templates"* ]]
  [[ "$output" == *"{project}: {summary}"* ]]
}
