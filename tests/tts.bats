#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  install_mock_tts_backend
}

teardown() {
  teardown_test_env
}

# ============================================================
# speak() function — backend invocation
# ============================================================

@test "TTS: speak() invokes backend with correct arg order (voice, rate, volume)" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Hello world"
  [ "$PEON_EXIT" -eq 0 ]
  tts_was_called
  local call
  call=$(tts_last_call)
  [[ "$call" == *"voice=default"* ]]
  [[ "$call" == *"rate=1.0"* ]]
  [[ "$call" == *"vol=0.5"* ]]
}

@test "TTS: speak() passes text on stdin to backend" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Task completed successfully"
  [ "$PEON_EXIT" -eq 0 ]
  tts_was_called
  local call
  call=$(tts_last_call)
  [[ "$call" == *"text=Task completed successfully"* ]]
}

# ============================================================
# Mode sequencing in _run_sound_and_notify
# ============================================================

@test "TTS: sound-then-speak mode plays sound before TTS" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Done" "sound-then-speak"
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  tts_was_called
  # Verify ordering: afplay must appear before tts in the combined log
  local order
  order="$(call_order)"
  local afplay_line tts_line
  afplay_line=$(echo "$order" | grep -n "afplay" | head -1 | cut -d: -f1)
  tts_line=$(echo "$order" | grep -n "tts" | head -1 | cut -d: -f1)
  [ "$afplay_line" -lt "$tts_line" ]
}

@test "TTS: speak-only mode skips play_sound entirely" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Done" "speak-only"
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  tts_was_called
}

@test "TTS: speak-then-sound mode invokes TTS then sound" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Done" "speak-then-sound"
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  tts_was_called
  # Verify ordering: tts must appear before afplay in the combined log
  local order
  order="$(call_order)"
  local afplay_line tts_line
  afplay_line=$(echo "$order" | grep -n "afplay" | head -1 | cut -d: -f1)
  tts_line=$(echo "$order" | grep -n "tts" | head -1 | cut -d: -f1)
  [ "$tts_line" -lt "$afplay_line" ]
}

# ============================================================
# TTS suppression
# ============================================================

@test "TTS: empty speech_text skips TTS invocation" {
  # Use em-dash as speech_text — the Python block treats bare "—" as empty
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "—" "sound-then-speak"
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! tts_was_called
}

@test "TTS: TTS_ENABLED=false skips TTS invocation" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Hello" "sound-then-speak" "false"
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! tts_was_called
}

@test "TTS: headphones_only suppresses TTS when no headphones" {
  # Set headphones_only in config (run_peon_tts writes TTS section separately)
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['headphones_only'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  touch "$TEST_DIR/.mock_speakers_only"
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Hello" "sound-then-speak"
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! tts_was_called
}

@test "TTS: meeting_detect suppresses TTS when in meeting" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['meeting_detect'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Signal that a meeting is active (mock meeting-detect returns MIC_IN_USE)
  touch "$TEST_DIR/.mock_mic_in_use"
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Hello" "sound-then-speak"
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! tts_was_called
}

@test "TTS: suppress_sound_when_tab_focused suppresses TTS when terminal is focused" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['suppress_sound_when_tab_focused'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Mock terminal as focused (Terminal.app — a recognized terminal)
  echo "Terminal" > "$TEST_DIR/.mock_terminal_focused"
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Hello" "sound-then-speak"
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! tts_was_called
}

# ============================================================
# PID tracking
# ============================================================

@test "TTS: kill_previous_tts kills old .tts.pid before new speak" {
  # Plant a fake .tts.pid — it should be cleaned up
  echo "99999" > "$TEST_DIR/.tts.pid"
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Hello"
  [ "$PEON_EXIT" -eq 0 ]
  tts_was_called
  # Old PID file should have been removed (or replaced)
  if [ -f "$TEST_DIR/.tts.pid" ]; then
    local pid_content
    pid_content=$(cat "$TEST_DIR/.tts.pid")
    [ "$pid_content" != "99999" ]
  fi
}

# ============================================================
# Missing backend — graceful skip
# ============================================================

@test "TTS: missing backend script causes graceful skip, sound still plays" {
  # Remove the mock backend
  rm -f "$TEST_DIR/scripts/tts-native.sh"
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Hello" "sound-then-speak"
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! tts_was_called
}

# ============================================================
# Speak-only debug log emission (PEON_DEBUG gated)
# ============================================================

@test "TTS: speak-only with TTS unavailable emits debug log when PEON_DEBUG=1" {
  export PEON_DEBUG=1
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Done" "speak-only" "false"
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! tts_was_called
  [[ "$PEON_STDERR" == *"[tts] speak-only mode but TTS unavailable"* ]]
}

@test "TTS: speak-only with TTS unavailable does NOT emit debug log when PEON_DEBUG unset" {
  unset PEON_DEBUG
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Done" "speak-only" "false"
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! tts_was_called
  [[ "$PEON_STDERR" != *"[tts] speak-only mode but TTS unavailable"* ]]
}

@test "TTS: auto backend resolution with no scripts installed returns gracefully" {
  rm -f "$TEST_DIR/scripts/tts-native.sh"
  # Write TTS config with backend=auto directly (no run_peon_tts indirection)
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True, 'backend': 'auto', 'voice': 'default', 'rate': 1.0, 'volume': 0.5, 'mode': 'sound-then-speak'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Add speech_text to manifest so Python resolves TTS_TEXT
  /usr/bin/python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
for cat in m.get('categories', {}).values():
    for entry in cat.get('sounds', []):
        entry['speech_text'] = 'Hello'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  export PEON_TEST=1
  echo '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' | bash "$PEON_SH" 2>"$TEST_DIR/stderr.log"
  PEON_EXIT=$?
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! tts_was_called
}

# ============================================================
# Trainer TTS
# ============================================================

@test "TTS: trainer speaks TRAINER_TTS_TEXT after trainer sound when TTS enabled" {
  # Enable trainer and set up trainer state so a reminder fires
  bash "$PEON_SH" trainer on

  # Create trainer sounds directory and manifest
  # Include both trainer.remind and trainer.slacking so the test passes
  # regardless of time of day (Python picks trainer.slacking when hour >= 12
  # and reps < 25% of goal).
  mkdir -p "$TEST_DIR/trainer/sounds/remind"
  cat > "$TEST_DIR/trainer/manifest.json" <<'JSON'
{
  "trainer.remind": [
    { "file": "sounds/remind/reminder.mp3", "label": "Time for reps!" }
  ],
  "trainer.slacking": [
    { "file": "sounds/remind/reminder.mp3", "label": "Get moving!" }
  ]
}
JSON
  touch "$TEST_DIR/trainer/sounds/remind/reminder.mp3"

  # Set trainer state: last reminder was long ago so it fires
  /usr/bin/python3 -c "
import json, time
s = json.load(open('$TEST_DIR/.state.json'))
s['trainer'] = {'date': '$(date +%Y-%m-%d)', 'reps': {'pushups': 0, 'squats': 0}, 'last_reminder_ts': int(time.time()) - 3600}
json.dump(s, open('$TEST_DIR/.state.json', 'w'))
"

  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Task done"
  [ "$PEON_EXIT" -eq 0 ]
  tts_was_called
  # Should have 2 TTS calls: one for main event, one for trainer
  local count
  count=$(tts_call_count)
  [ "$count" -eq 2 ]
  # Last TTS call should contain trainer exercise progress (computed by Python block)
  local last
  last=$(tts_last_call)
  [[ "$last" == *"pushups"* ]]
}

# ============================================================
# Integration: full hook invocation with both sound and TTS
# ============================================================

@test "TTS: integration — full hook with TTS enabled fires both sound and TTS" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' "Build succeeded"
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  tts_was_called
  local call
  call=$(tts_last_call)
  [[ "$call" == *"text=Build succeeded"* ]]
  [[ "$call" == *"voice=default"* ]]
}

# ============================================================
# Text safety — shell metacharacters
# ============================================================

@test "TTS: text with shell metacharacters delivered safely via stdin" {
  run_peon_tts '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s1","permission_mode":"default"}' 'Hello $USER `whoami` $(date)'
  [ "$PEON_EXIT" -eq 0 ]
  tts_was_called
  local call
  call=$(tts_last_call)
  # Text should be passed literally, not interpreted
  [[ "$call" == *'$USER'* ]]
}
