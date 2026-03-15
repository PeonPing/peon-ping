#!/usr/bin/env bats
# Tests for Windows PowerShell adapter (install.ps1 and peon.ps1)
# These tests verify the embedded peon.ps1 script in install.ps1
#
# Testing approach: Since CI runs on macOS but we need to test PowerShell logic,
# we extract the embedded peon.ps1 script and simulate its event-mapping behavior
# using Python. The Python code replicates the PowerShell control flow (event
# detection, state management, category mapping) and then delegates to the actual
# peon.sh for sound selection and playback. This lets us verify Windows-specific
# logic without requiring a Windows CI runner.

load setup.bash

setup() {
  setup_test_env

  # Extract the peon.ps1 script from install.ps1
  INSTALL_PS1="${PEON_SH%/peon.sh}/install.ps1"
  PEON_PS1="$TEST_DIR/peon.ps1"

  # Extract embedded PowerShell script (between @' and '@)
  # Normalize CRLF to LF so awk pattern matching works on Windows-sourced files
  tr -d '\r' < "$INSTALL_PS1" | awk '/^\$hookScript = @'"'"'$/,/^'"'"'@$/{if (!/^\$hookScript = @'"'"'$/ && !/^'"'"'@$/) print}' > "$PEON_PS1"
}

teardown() {
  teardown_test_env
}

# Helper: run Windows adapter via PowerShell emulation in bash
# (For actual testing on Windows, PowerShell would be used)
run_peon_ps1() {
  local json="$1"
  # Simulate PowerShell behavior with Python
  export PEON_TEST=1
  python3 -c "
import json, sys, os, subprocess, tempfile

# Parse the embedded PowerShell script logic
json_input = '''$json'''
event_data = json.loads(json_input)
hook_event = event_data.get('hook_event_name', '')
ntype = event_data.get('notification_type', '')

# Mock config
config = {
    'enabled': True,
    'default_pack': 'peon',
    'volume': 0.5,
    'categories': {
        'session.start': True,
        'task.acknowledge': True,
        'task.complete': True,
        'task.error': True,
        'input.required': True,
        'user.spam': True
    },
    'annoyed_threshold': 3,
    'annoyed_window_seconds': 10,
    'silent_window_seconds': 0
}

# Check for test config override
test_config = '$TEST_DIR/config.json'
if os.path.exists(test_config):
    with open(test_config) as f:
        config = json.load(f)

if not config.get('enabled', True):
    sys.exit(0)

# Map event to category (matching peon.ps1 logic)
category = None
state = {}
state_path = '$TEST_DIR/.state.json'
if os.path.exists(state_path):
    with open(state_path) as f:
        state = json.load(f)

import time
now = int(time.time())

if hook_event == 'SessionStart':
    category = 'session.start'
elif hook_event == 'Stop':
    category = 'task.complete'
    # Debounce is handled by peon.sh, not duplicated here
elif hook_event == 'Notification':
    ntype = event_data.get('notification_type')
    if ntype == 'permission_prompt':
        # PermissionRequest event handles the sound, skip here
        category = None
    elif ntype == 'idle_prompt':
        # Stop event already played the sound
        category = None
    else:
        # Other notification types (e.g., tool results) map to task.complete
        category = 'task.complete'
elif hook_event == 'PermissionRequest':
    category = 'input.required'
elif hook_event == 'UserPromptSubmit':
    session_id = event_data.get('session_id', 'default')
    threshold = config.get('annoyed_threshold', 3)
    window = config.get('annoyed_window_seconds', 10)

    all_prompts = state.get('prompt_timestamps', {})
    recent = [t for t in all_prompts.get(session_id, []) if (now - t) < window]
    recent.append(now)
    all_prompts[session_id] = recent
    state['prompt_timestamps'] = all_prompts

    if len(recent) >= threshold:
        category = 'user.spam'

# Save state
with open(state_path, 'w') as f:
    json.dump(state, f)

if not category:
    sys.exit(0)

# Check category enabled
if not config.get('categories', {}).get(category, True):
    sys.exit(0)

# Call peon.sh with mapped event
peon_json = {
    'hook_event_name': {
        'session.start': 'SessionStart',
        'task.complete': 'Stop',
        'input.required': 'PermissionRequest',
        'user.spam': 'UserPromptSubmit'
    }.get(category, 'Stop'),
    'notification_type': ntype,
    'cwd': event_data.get('cwd', '/tmp'),
    'session_id': event_data.get('session_id', 'ps1'),
    'permission_mode': event_data.get('permission_mode', 'default')
}

# Pass to peon.sh
proc = subprocess.Popen(
    ['bash', '$PEON_SH'],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    env={**os.environ, 'PEON_TEST': '1', 'CLAUDE_PEON_DIR': '$TEST_DIR'}
)
stdout, stderr = proc.communicate(json.dumps(peon_json).encode())
sys.exit(proc.returncode)
" 2>"$TEST_DIR/stderr.log"
  PS1_EXIT=$?
  # Wait for background nohup afplay to write its log
  sleep 0.3
}

# ============================================================
# Event mapping
# ============================================================

@test "Windows: SessionStart maps to session.start" {
  run_peon_ps1 '{"hook_event_name":"SessionStart","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "Windows: Stop maps to task.complete" {
  run_peon_ps1 '{"hook_event_name":"Stop","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "Windows: PermissionRequest maps to input.required" {
  run_peon_ps1 '{"hook_event_name":"PermissionRequest","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "Windows: Notification permission_prompt skips sound" {
  run_peon_ps1 '{"hook_event_name":"Notification","notification_type":"permission_prompt","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "Windows: UserPromptSubmit no sound normally" {
  run_peon_ps1 '{"hook_event_name":"UserPromptSubmit","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Stop debouncing
# ============================================================

@test "Windows: rapid Stop events are debounced" {
  run_peon_ps1 '{"hook_event_name":"Stop","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second Stop within 5s should not play
  run_peon_ps1 '{"hook_event_name":"Stop","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Spam detection
# ============================================================

@test "Windows: rapid prompts trigger user.spam" {
  for i in $(seq 1 3); do
    run_peon_ps1 '{"hook_event_name":"UserPromptSubmit","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  done
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"Angry1.wav"* ]]
}

# ============================================================
# Config handling
# ============================================================

@test "Windows: enabled=false suppresses sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "enabled": false,
  "default_pack": "peon",
  "volume": 0.5,
  "categories": {
    "session.start": true,
    "task.complete": true
  }
}
JSON
  run_peon_ps1 '{"hook_event_name":"SessionStart","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "Windows: category disabled suppresses sound" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "enabled": true,
  "default_pack": "peon",
  "volume": 0.5,
  "categories": {
    "session.start": false,
    "task.complete": true
  }
}
JSON
  run_peon_ps1 '{"hook_event_name":"SessionStart","cwd":"C:\\\\Users\\\\test\\\\project","session_id":"w1"}'
  [ "$PS1_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# CLI commands (extraction test only - full test needs Windows)
# ============================================================

@test "Windows: peon.ps1 contains CLI command handlers" {
  grep -q "\-\-status" "$PEON_PS1"
  grep -q "\-\-toggle" "$PEON_PS1"
  grep -q "\-\-packs" "$PEON_PS1"
  grep -q "\-\-volume" "$PEON_PS1"
}

@test "Windows: peon.ps1 uses CESP category format" {
  grep -q "session\\.start" "$PEON_PS1"
  grep -q "task\\.complete" "$PEON_PS1"
  grep -q "input\\.required" "$PEON_PS1"
  grep -q "user\\.spam" "$PEON_PS1"
}
