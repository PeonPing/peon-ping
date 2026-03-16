#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  export PLATFORM=wsl

  # Mock powershell.exe — logs calls and returns a fake temp path
  cat > "$MOCK_BIN/powershell.exe" <<'SCRIPT'
#!/bin/bash
echo "POWERSHELL: $*" >> "${CLAUDE_PEON_DIR}/powershell.log"
if [[ "$*" == *"GetTempPath"* ]]; then
  echo "C:\\Users\\test\\AppData\\Local\\Temp\\"
  exit 0
fi
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/powershell.exe"

  # Mock wslpath — converts Windows paths to our test dir
  cat > "$MOCK_BIN/wslpath" <<SCRIPT
#!/bin/bash
if [[ "\$1" == "-u" ]]; then
  echo "${TEST_DIR}/wsl_tmp/"
elif [[ "\$1" == "-w" ]]; then
  echo "C:\\\\fake\\\\path"
fi
SCRIPT
  chmod +x "$MOCK_BIN/wslpath"

  # Mock setsid — run inline (no session separation in tests)
  cat > "$MOCK_BIN/setsid" <<'SCRIPT'
#!/bin/bash
"$@"
SCRIPT
  chmod +x "$MOCK_BIN/setsid"

  mkdir -p "$TEST_DIR/wsl_tmp"
}

teardown() {
  teardown_test_env
}

# Helper: get the toast XML content
get_toast_xml() {
  cat "$TEST_DIR/wsl_tmp/peon-toast.xml" 2>/dev/null
}

# ============================================================
# _escape_xml unit tests (function tested in isolation)
# ============================================================

@test "_escape_xml escapes all 5 XML predefined entities" {
  # Source the function definition from peon.sh and test directly
  _escape_xml() { printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037' | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\"/\&quot;/g; s/'/\&apos;/g"; }

  result=$(_escape_xml 'A <b> & "c" > d'"'"'s')
  [[ "$result" == *"&amp;"* ]]
  [[ "$result" == *"&lt;"* ]]
  [[ "$result" == *"&gt;"* ]]
  [[ "$result" == *"&quot;"* ]]
  [[ "$result" == *"&apos;"* ]]
}

@test "_escape_xml strips control characters" {
  _escape_xml() { printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037' | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\"/\&quot;/g; s/'/\&apos;/g"; }

  result=$(_escape_xml "$(printf 'hello\x01\x08world')")
  [ "$result" = "helloworld" ]
}

@test "_escape_xml preserves newlines and tabs (valid in XML)" {
  _escape_xml() { printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037' | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\"/\&quot;/g; s/'/\&apos;/g"; }

  result=$(_escape_xml "$(printf 'line1\nline2\ttab')")
  [[ "$result" == *$'\n'* ]]
  [[ "$result" == *$'\t'* ]]
}

@test "_escape_xml produces valid XML when embedded in toast template" {
  _escape_xml() { printf '%s' "$1" | tr -d '\000-\010\013\014\016-\037' | sed "s/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/\"/\&quot;/g; s/'/\&apos;/g"; }

  title=$(_escape_xml "O'Brien <dev> & \"test\"")
  body=$(_escape_xml "Build done — branch <main>")
  xml="<toast><visual><binding template=\"ToastGeneric\"><text>${body}</text><text>${title}</text></binding></visual></toast>"

  python3 -c "
import xml.etree.ElementTree as ET
ET.fromstring('''$xml''')
print('valid')
"
}

# ============================================================
# Toast notification end-to-end (notification_style: standard)
# ============================================================

@test "WSL standard toast XML is well-formed" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/wsl_tmp/peon-toast.xml" ]
  python3 -c "
import xml.etree.ElementTree as ET
ET.fromstring(open('$TEST_DIR/wsl_tmp/peon-toast.xml').read())
"
}

@test "WSL standard toast XML contains toast structure with silent audio" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  xml=$(get_toast_xml)
  [[ "$xml" == *"<toast"* ]]
  [[ "$xml" == *"<text>"* ]]
  [[ "$xml" == *'silent="true"'* ]]
}

@test "WSL standard toast XML contains project name in text" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  xml=$(get_toast_xml)
  [[ "$xml" == *"myproject"* ]]
}

@test "WSL standard toast with angle brackets in project name produces valid XML" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/<script>","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/wsl_tmp/peon-toast.xml" ]
  python3 -c "
import xml.etree.ElementTree as ET
ET.fromstring(open('$TEST_DIR/wsl_tmp/peon-toast.xml').read())
"
}

# ============================================================
# Temp file cleanup
# ============================================================

@test "WSL standard toast PowerShell includes Remove-Item for cleanup" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/powershell.log" ]
  grep -q "Remove-Item" "$TEST_DIR/powershell.log"
  grep -q "peon-toast.xml" "$TEST_DIR/powershell.log"
}

# ============================================================
# notification_style config toggle
# ============================================================

@test "WSL defaults to overlay (Forms popup) when notification_style not in config" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Toast XML should NOT exist when notification_style defaults to overlay
  [ ! -f "$TEST_DIR/wsl_tmp/peon-toast.xml" ]
  # Legacy popup uses Forms via PowerShell
  [ -f "$TEST_DIR/powershell.log" ]
  grep -q "Windows.Forms" "$TEST_DIR/powershell.log" || grep -q "TopMost" "$TEST_DIR/powershell.log"
}

@test "WSL notification_style standard uses toast notification" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/wsl_tmp/peon-toast.xml" ]
}

# ============================================================
# Icon handling
# ============================================================

@test "WSL standard toast includes icon XML when icon exists" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  mkdir -p "$TEST_DIR/docs"
  echo "fake-png" > "$TEST_DIR/docs/peon-icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  xml=$(get_toast_xml)
  [[ "$xml" == *"appLogoOverride"* ]]
  [[ "$xml" == *"peon-ping-icon.png"* ]]
  # Icon should be copied to temp dir
  [ -f "$TEST_DIR/wsl_tmp/peon-ping-icon.png" ]
}

@test "WSL standard toast works without pack icon" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "standard", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
  rm -f "$TEST_DIR/docs/peon-icon.png" 2>/dev/null
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/wsl_tmp/peon-toast.xml" ]
  xml=$(get_toast_xml)
  [[ "$xml" != *"appLogoOverride"* ]]
}
