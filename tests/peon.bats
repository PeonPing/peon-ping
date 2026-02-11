#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
}

teardown() {
  teardown_test_env
}

# ============================================================
# Event routing
# ============================================================

@test "SessionStart plays a greeting sound" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "Notification permission_prompt plays a permission sound" {
  run_peon '{"hook_event_name":"Notification","notification_type":"permission_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "Notification idle_prompt plays a complete sound" {
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "Stop does NOT play any sound" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "UserPromptSubmit does NOT play sound normally" {
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "Unknown event exits cleanly with no sound" {
  run_peon '{"hook_event_name":"SomeOtherEvent","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "Notification with unknown type exits cleanly" {
  run_peon '{"hook_event_name":"Notification","notification_type":"something_else","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Disabled config
# ============================================================

@test "enabled=false skips everything" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "active_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "category disabled skips sound but still exits 0" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": { "greeting": false }
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Missing config (defaults)
# ============================================================

@test "missing config file uses defaults and still works" {
  rm -f "$TEST_DIR/config.json"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

# ============================================================
# Agent/teammate detection
# ============================================================

@test "agent session (permission_mode=acceptEdits) suppresses sound" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"agent1","permission_mode":"acceptEdits"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "agent session is remembered across events" {
  # First event marks it as agent
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"agent2","permission_mode":"delegate"}'
  ! afplay_was_called

  # Second event from same session_id (even with empty perm_mode) is still suppressed
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"agent2","permission_mode":""}'
  ! afplay_was_called
}

@test "default permission_mode is NOT treated as agent" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

# ============================================================
# Sound picking (no-repeat)
# ============================================================

@test "sound picker avoids immediate repeats" {
  # Run greeting multiple times and collect sounds
  sounds=()
  for i in $(seq 1 10); do
    run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
    sounds+=("$(afplay_sound)")
  done

  # Check that consecutive sounds differ (greeting has 2 options: Hello1 and Hello2)
  had_different=false
  for i in $(seq 1 9); do
    if [ "${sounds[$i]}" != "${sounds[$((i-1))]}" ]; then
      had_different=true
      break
    fi
  done
  [ "$had_different" = true ]
}

@test "single-sound category still works (no infinite loop)" {
  # Error category has only 1 sound — should still work
  # We need an event that maps to error... there isn't one in peon.sh currently.
  # But acknowledge has 1 sound in our test manifest, so let's test via a direct approach.
  # Actually, let's test with annoyed which has 1 sound and can be triggered.

  # Set up rapid prompts to trigger annoyed
  for i in $(seq 1 3); do
    run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  done
  # The 3rd should trigger annoyed (threshold=3)
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"Angry1.wav" ]]
}

# ============================================================
# Annoyed easter egg
# ============================================================

@test "annoyed triggers after rapid prompts" {
  # Send 3 prompts quickly (within annoyed_window_seconds)
  for i in $(seq 1 3); do
    run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  done
  afplay_was_called
}

@test "annoyed does NOT trigger below threshold" {
  # Send only 2 prompts (threshold is 3)
  for i in $(seq 1 2); do
    run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  done
  ! afplay_was_called
}

@test "annoyed disabled in config suppresses easter egg" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": { "annoyed": false },
  "annoyed_threshold": 3, "annoyed_window_seconds": 10
}
JSON
  for i in $(seq 1 5); do
    run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  done
  ! afplay_was_called
}

# ============================================================
# Update check
# ============================================================

@test "update notice shown when .update_available exists" {
  echo "1.1.0" > "$TEST_DIR/.update_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [[ "$PEON_STDERR" == *"update available"* ]]
  [[ "$PEON_STDERR" == *"1.0.0"* ]]
  [[ "$PEON_STDERR" == *"1.1.0"* ]]
}

@test "no update notice when versions match" {
  # No .update_available file = no notice
  rm -f "$TEST_DIR/.update_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [[ "$PEON_STDERR" != *"update available"* ]]
}

@test "update notice only on SessionStart, not other events" {
  echo "1.1.0" > "$TEST_DIR/.update_available"
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [[ "$PEON_STDERR" != *"update available"* ]]
}

# ============================================================
# Project name / tab title
# ============================================================

@test "project name extracted from cwd" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/Users/dev/my-cool-project","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Can't easily check printf escape output, but at least it didn't crash
}

@test "empty cwd falls back to 'claude'" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
}

# ============================================================
# Volume passthrough
# ============================================================

@test "volume from config is passed to afplay" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}
