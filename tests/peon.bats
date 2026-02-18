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

@test "SessionStart compact skips greeting" {
  run_peon '{"hook_event_name":"SessionStart","source":"compact","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "Notification permission_prompt sets tab title but no sound (PermissionRequest handles sound)" {
  run_peon '{"hook_event_name":"Notification","notification_type":"permission_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "PermissionRequest plays a permission sound (IDE support)" {
  run_peon '{"hook_event_name":"PermissionRequest","tool_name":"Bash","tool_input":{"command":"rm -rf /"},"cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "Notification idle_prompt does NOT play sound (Stop handles it)" {
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "Stop plays a complete sound" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "rapid Stop events are debounced" {
  # First Stop plays sound
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second Stop within cooldown does NOT play sound
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

@test "Stop plays sound again after cooldown expires" {
  # Set last_stop_time to 10 seconds ago (beyond 5s cooldown)
  /usr/bin/python3 -c "
import json, time
state = json.load(open('$TEST_DIR/.state.json'))
state['last_stop_time'] = time.time() - 10
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
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
  "categories": { "session.start": false }
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

@test "acceptEdits is interactive, NOT suppressed" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"acceptEdits"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "delegate mode suppresses sound (agent session)" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"agent1","permission_mode":"delegate"}'
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
  "categories": { "user.spam": false },
  "annoyed_threshold": 3, "annoyed_window_seconds": 10
}
JSON
  for i in $(seq 1 5); do
    run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  done
  ! afplay_was_called
}

# ============================================================
# Silent window (suppress short tasks)
# ============================================================

@test "silent_window suppresses sound for fast tasks" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
JSON
  # Submit prompt (records start time)
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  # Stop immediately (under 5s threshold)
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "silent_window allows sound for slow tasks" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
JSON
  # Submit prompt
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  # Backdate the prompt start to 10 seconds ago
  /usr/bin/python3 -c "
import json, time
state = json.load(open('$TEST_DIR/.state.json'))
state['prompt_start_times'] = {'s1': time.time() - 10}
state.setdefault('last_stop_time', 0)
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "silent_window=0 (default) does not suppress anything" {
  # Default config has no silent_window_seconds (defaults to 0)
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "silent_window suppresses without prior prompt (no crash)" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
JSON
  # Stop without any prior UserPromptSubmit — should NOT crash, should play sound
  # (start_time defaults to 0, which is falsy, so silent stays False)
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "silent_window does not interfere with debounce" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
JSON
  # Submit prompt and backdate to make it a "slow" task
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  /usr/bin/python3 -c "
import json, time
state = json.load(open('$TEST_DIR/.state.json'))
state['prompt_start_times'] = {'s1': time.time() - 10}
state.setdefault('last_stop_time', 0)
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  # First Stop — should play (slow task, not debounced)
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second prompt + immediate Stop — debounced regardless of silent_window
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

@test "silent_window multi-session isolation" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
JSON
  # Session A: prompt + fast Stop (silent)
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"sA","permission_mode":"default"}'
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"sA","permission_mode":"default"}'
  ! afplay_was_called

  # Session B: Stop without any prompt — should play sound (no recorded start time for sB)
  # Need to clear debounce first
  /usr/bin/python3 -c "
import json, time
state = json.load(open('$TEST_DIR/.state.json'))
state['last_stop_time'] = 0
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"sB","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
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

# ============================================================
# Sound Effects device routing (macOS peon-play)
# ============================================================

@test "peon-play is used when use_sound_effects_device is true" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  peon_play_was_called
  ! afplay_was_called
}

@test "afplay is used when use_sound_effects_device is false" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": false, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! peon_play_was_called
}

@test "use_sound_effects_device defaults to true when not in config" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  peon_play_was_called
  ! afplay_was_called
}

@test "afplay is used when peon-play is not installed" {
  # Do NOT call install_peon_play_mock — peon-play binary absent
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! peon_play_was_called
}

@test "volume is passed to peon-play" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.7, "enabled": true, "use_sound_effects_device": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  peon_play_was_called
  log_line=$(tail -1 "$TEST_DIR/peon-play.log")
  [[ "$log_line" == *"-v 0.7"* ]]
}

# ============================================================
# Pause / mute feature
# ============================================================

@test "toggle creates .paused file and prints paused message" {
  run bash "$PEON_SH" toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds paused"* ]]
  [ -f "$TEST_DIR/.paused" ]
}

@test "toggle removes .paused file when already paused" {
  touch "$TEST_DIR/.paused"
  run bash "$PEON_SH" toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds resumed"* ]]
  [ ! -f "$TEST_DIR/.paused" ]
}

@test "pause creates .paused file" {
  run bash "$PEON_SH" pause
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds paused"* ]]
  [ -f "$TEST_DIR/.paused" ]
}

@test "resume removes .paused file" {
  touch "$TEST_DIR/.paused"
  run bash "$PEON_SH" resume
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds resumed"* ]]
  [ ! -f "$TEST_DIR/.paused" ]
}

@test "status reports paused when .paused exists" {
  touch "$TEST_DIR/.paused"
  run bash "$PEON_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"paused"* ]]
}

@test "status reports active when not paused" {
  rm -f "$TEST_DIR/.paused"
  run bash "$PEON_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active"* ]]
}

@test "paused file suppresses sound on SessionStart" {
  touch "$TEST_DIR/.paused"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "paused SessionStart shows stderr status line" {
  touch "$TEST_DIR/.paused"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [[ "$PEON_STDERR" == *"sounds paused"* ]]
}

@test "paused file suppresses notification on permission_prompt" {
  touch "$TEST_DIR/.paused"
  run_peon '{"hook_event_name":"Notification","notification_type":"permission_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# desktop_notifications config
# ============================================================

@test "desktop_notifications false suppresses notification but plays sound" {
  # Set desktop_notifications to false
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['desktop_notifications'] = False
json.dump(c, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Sound should still play even with notifications disabled
  afplay_was_called
  # Verify config still has desktop_notifications=false (wasn't reset)
  val=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('desktop_notifications', True))")
  [ "$val" = "False" ]
}

@test "notifications off updates config" {
  run bash "$PEON_SH" notifications off
  [ "$status" -eq 0 ]
  [[ "$output" == *"desktop notifications off"* ]]
  # Verify config was updated
  val=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('desktop_notifications', True))")
  [ "$val" = "False" ]
}

@test "notifications on updates config" {
  # First turn off
  bash "$PEON_SH" notifications off
  # Then turn on
  run bash "$PEON_SH" notifications on
  [ "$status" -eq 0 ]
  [[ "$output" == *"desktop notifications on"* ]]
  val=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('desktop_notifications', True))")
  [ "$val" = "True" ]
}

# ============================================================
# packs list
# ============================================================

@test "packs list shows all available packs" {
  run bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"peon"* ]]
  [[ "$output" == *"sc_kerrigan"* ]]
}

@test "packs list marks the active pack with *" {
  run bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orc Peon *"* ]]
  # sc_kerrigan should NOT be marked
  line=$(echo "$output" | grep "sc_kerrigan")
  [[ "$line" != *"*"* ]]
}

@test "packs list marks correct pack after switch" {
  bash "$PEON_SH" packs use sc_kerrigan
  run bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sarah Kerrigan (StarCraft) *"* ]]
}

@test "packs list works when script is not in hooks dir (Homebrew install)" {
  # Simulate Homebrew: script runs from a dir without packs, but hooks dir has them
  FAKE_HOME="$(mktemp -d)"
  HOOKS_DIR="$FAKE_HOME/.claude/hooks/peon-ping"
  mkdir -p "$HOOKS_DIR/packs"
  cp -R "$TEST_DIR/packs/peon" "$HOOKS_DIR/packs/"
  cp "$TEST_DIR/config.json" "$HOOKS_DIR/config.json"
  echo '{}' > "$HOOKS_DIR/.state.json"

  # Unset CLAUDE_PEON_DIR so it falls back to BASH_SOURCE dirname → script dir (no packs)
  # Set HOME to fake home so the fallback finds the hooks dir
  unset CLAUDE_PEON_DIR
  run env HOME="$FAKE_HOME" bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"peon"* ]]
  [[ "$output" == *"Orc Peon"* ]]

  rm -rf "$FAKE_HOME"
  export CLAUDE_PEON_DIR="$TEST_DIR"
}

@test "packs list finds CESP shared packs at ~/.openpeon/packs" {
  # Simulate Homebrew with CESP setup: script in Cellar, packs at ~/.openpeon/packs
  FAKE_HOME="$(mktemp -d)"
  CESP_DIR="$FAKE_HOME/.openpeon"
  mkdir -p "$CESP_DIR/packs"
  cp -R "$TEST_DIR/packs/peon" "$CESP_DIR/packs/"
  echo '{}' > "$CESP_DIR/config.json"

  # No Claude hooks dir — CESP path should be found
  unset CLAUDE_PEON_DIR
  run env HOME="$FAKE_HOME" bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"peon"* ]]
  [[ "$output" == *"Orc Peon"* ]]

  rm -rf "$FAKE_HOME"
  export CLAUDE_PEON_DIR="$TEST_DIR"
}

@test "CESP shared path takes priority over Claude hooks dir" {
  # Both paths exist — CESP should win
  FAKE_HOME="$(mktemp -d)"
  CESP_DIR="$FAKE_HOME/.openpeon"
  HOOKS_DIR="$FAKE_HOME/.claude/hooks/peon-ping"
  mkdir -p "$CESP_DIR/packs"
  mkdir -p "$HOOKS_DIR/packs"

  # Put different packs in each location
  cp -R "$TEST_DIR/packs/peon" "$CESP_DIR/packs/"
  cp -R "$TEST_DIR/packs/sc_kerrigan" "$HOOKS_DIR/packs/"
  echo '{}' > "$CESP_DIR/config.json"
  echo '{}' > "$HOOKS_DIR/config.json"

  unset CLAUDE_PEON_DIR
  run env HOME="$FAKE_HOME" bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  # Should find peon (from CESP), not sc_kerrigan (from hooks)
  [[ "$output" == *"peon"* ]]
  [[ "$output" == *"Orc Peon"* ]]
  [[ "$output" != *"sc_kerrigan"* ]]

  rm -rf "$FAKE_HOME"
  export CLAUDE_PEON_DIR="$TEST_DIR"
}

# ============================================================
# packs use <name> (set specific pack)
# ============================================================

@test "packs use <name> switches to valid pack" {
  run bash "$PEON_SH" packs use sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to sc_kerrigan"* ]]
  [[ "$output" == *"Sarah Kerrigan"* ]]
  # Verify config was updated
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "sc_kerrigan" ]
}

@test "packs use <name> preserves other config fields" {
  bash "$PEON_SH" packs use sc_kerrigan
  volume=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['volume'])")
  [ "$volume" = "0.5" ]
}

@test "packs use <name> errors on nonexistent pack" {
  run bash "$PEON_SH" packs use nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
  [[ "$output" == *"Available packs"* ]]
}

@test "packs use <name> does not modify config on invalid pack" {
  bash "$PEON_SH" packs use nonexistent || true
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "peon" ]
}

# ============================================================
# packs use --install
# ============================================================

@test "packs use --install downloads and switches to absent pack" {
  setup_pack_download_env
  run bash "$PEON_SH" packs use --install test_pack_a
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [ -f "$TEST_DIR/packs/test_pack_a/openpeon.json" ]
  [[ "$output" == *"switched to test_pack_a"* ]]
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "test_pack_a" ]
}

@test "packs use --install re-downloads already-installed pack" {
  setup_pack_download_env
  run bash "$PEON_SH" packs use --install sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to sc_kerrigan"* ]]
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "sc_kerrigan" ]
}

@test "packs use <name> --install works (flag after name)" {
  setup_pack_download_env
  run bash "$PEON_SH" packs use test_pack_a --install
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [[ "$output" == *"switched to test_pack_a"* ]]
}

@test "packs use --install errors when pack-download.sh missing" {
  # Don't call setup_pack_download_env — no scripts/ dir
  run bash "$PEON_SH" packs use --install test_pack_a
  [ "$status" -ne 0 ]
  [[ "$output" == *"pack-download.sh not found"* ]]
}

# ============================================================
# packs next (cycle, no argument)
# ============================================================

@test "packs next cycles to next pack alphabetically" {
  # Active is peon, next alphabetically is sc_kerrigan
  run bash "$PEON_SH" packs next
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to sc_kerrigan"* ]]
}

@test "packs next wraps around from last to first" {
  # Set to sc_kerrigan (last alphabetically), should wrap to peon
  bash "$PEON_SH" packs use sc_kerrigan
  run bash "$PEON_SH" packs next
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to peon"* ]]
}

@test "packs next updates config correctly" {
  bash "$PEON_SH" packs next
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "sc_kerrigan" ]
}

# ============================================================
# help
# ============================================================

@test "help shows pack commands" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"packs list"* ]]
  [[ "$output" == *"packs use"* ]]
}

@test "unknown option shows helpful error" {
  run bash "$PEON_SH" --foobar
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]
  [[ "$output" == *"peon help"* ]]
}

@test "unknown command shows helpful error" {
  run bash "$PEON_SH" foobar
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown command"* ]]
  [[ "$output" == *"peon help"* ]]
}

@test "no arguments on a TTY shows usage hint and exits" {
  # 'script' allocates a pseudo-TTY so stdin is not a pipe
  if [[ "$(uname)" == "Darwin" ]]; then
    run script -q /dev/null bash "$PEON_SH"
  else
    run script -qc "bash '$PEON_SH'" /dev/null
  fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"help"* ]]
}

# ============================================================
# packs remove (non-interactive pack removal)
# ============================================================

@test "packs remove <name> removes pack directory" {
  [ -d "$TEST_DIR/packs/sc_kerrigan" ]
  echo "y" | bash "$PEON_SH" packs remove sc_kerrigan
  [ ! -d "$TEST_DIR/packs/sc_kerrigan" ]
}

@test "packs remove <name> prints confirmation" {
  run bash -c 'echo "y" | bash "$0" packs remove sc_kerrigan' "$PEON_SH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed sc_kerrigan"* ]]
}

@test "packs remove <name> cleans pack_rotation in config" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon", "sc_kerrigan"]
}
JSON
  echo "y" | bash "$PEON_SH" packs remove sc_kerrigan
  rotation=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('pack_rotation', []))")
  [[ "$rotation" == *"peon"* ]]
  [[ "$rotation" != *"sc_kerrigan"* ]]
}

@test "packs remove active pack errors" {
  run bash "$PEON_SH" packs remove peon
  [ "$status" -ne 0 ]
  [[ "$output" == *"active pack"* ]]
  # Pack should still exist
  [ -d "$TEST_DIR/packs/peon" ]
}

@test "packs remove nonexistent pack errors" {
  run bash "$PEON_SH" packs remove nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "packs remove last remaining pack errors" {
  # Remove sc_kerrigan first so only peon remains
  rm -rf "$TEST_DIR/packs/sc_kerrigan"
  run bash "$PEON_SH" packs remove peon
  [ "$status" -ne 0 ]
  # Should error either because it's active or because it's the last one
  [ -d "$TEST_DIR/packs/peon" ]
}

@test "packs remove multiple packs at once" {
  # Add a third pack so we can remove two and still have one left
  mkdir -p "$TEST_DIR/packs/glados/sounds"
  cat > "$TEST_DIR/packs/glados/manifest.json" <<'JSON'
{
  "name": "glados",
  "display_name": "GLaDOS",
  "categories": {
    "session.start": { "sounds": [{ "file": "Hello1.wav", "label": "Hello" }] }
  }
}
JSON
  touch "$TEST_DIR/packs/glados/sounds/Hello1.wav"

  echo "y" | bash "$PEON_SH" packs remove sc_kerrigan,glados
  [ ! -d "$TEST_DIR/packs/sc_kerrigan" ]
  [ ! -d "$TEST_DIR/packs/glados" ]
  # Active pack still present
  [ -d "$TEST_DIR/packs/peon" ]
}

@test "packs remove --all removes all non-active packs" {
  # Add a third pack
  mkdir -p "$TEST_DIR/packs/glados/sounds"
  cat > "$TEST_DIR/packs/glados/manifest.json" <<'JSON'
{
  "name": "glados",
  "display_name": "GLaDOS",
  "categories": {
    "session.start": { "sounds": [{ "file": "Hello1.wav", "label": "Hello" }] }
  }
}
JSON
  touch "$TEST_DIR/packs/glados/sounds/Hello1.wav"

  echo "y" | bash "$PEON_SH" packs remove --all
  [ ! -d "$TEST_DIR/packs/sc_kerrigan" ]
  [ ! -d "$TEST_DIR/packs/glados" ]
  # Active pack remains
  [ -d "$TEST_DIR/packs/peon" ]
}

@test "packs remove --all with only active pack errors" {
  # Remove all non-active packs first
  rm -rf "$TEST_DIR/packs/sc_kerrigan"

  run bash "$PEON_SH" packs remove --all
  [ "$status" -ne 0 ]
  [[ "$output" == *"No packs to remove"* ]]
  # Active pack still present
  [ -d "$TEST_DIR/packs/peon" ]
}

@test "packs remove --all cleans pack_rotation" {
  # Add a third pack
  mkdir -p "$TEST_DIR/packs/glados/sounds"
  cat > "$TEST_DIR/packs/glados/manifest.json" <<'JSON'
{
  "name": "glados",
  "display_name": "GLaDOS",
  "categories": {
    "session.start": { "sounds": [{ "file": "Hello1.wav", "label": "Hello" }] }
  }
}
JSON
  touch "$TEST_DIR/packs/glados/sounds/Hello1.wav"

  # Set up pack_rotation including non-active packs
  python3 -c "
import json
cfg = json.load(open('${TEST_DIR}/config.json'))
cfg['pack_rotation'] = ['peon', 'sc_kerrigan', 'glados']
json.dump(cfg, open('${TEST_DIR}/config.json', 'w'), indent=2)
"

  echo "y" | bash "$PEON_SH" packs remove --all

  # Verify rotation only has active pack
  run python3 -c "
import json
cfg = json.load(open('${TEST_DIR}/config.json'))
rotation = cfg.get('pack_rotation', [])
print(','.join(rotation))
"
  [[ "$output" == "peon" ]]
}

@test "help shows packs remove --all" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"packs remove --all"* ]]
}

@test "help shows packs remove command" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"packs remove"* ]]
}

# ============================================================
# packs install
# ============================================================

@test "packs install with no args shows usage" {
  setup_pack_download_env
  run bash "$PEON_SH" packs install
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
  [[ "$output" == *"packs install"* ]]
}

@test "packs install downloads pack via pack-download.sh" {
  setup_pack_download_env
  run bash "$PEON_SH" packs install test_pack_a
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [ -f "$TEST_DIR/packs/test_pack_a/openpeon.json" ]
}

@test "packs install --all downloads all packs" {
  setup_pack_download_env
  run bash "$PEON_SH" packs install --all
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [ -d "$TEST_DIR/packs/test_pack_b" ]
}

@test "packs install errors when pack-download.sh missing" {
  # Don't call setup_pack_download_env — no scripts/ dir
  run bash "$PEON_SH" packs install test_pack_a
  [ "$status" -ne 0 ]
  [[ "$output" == *"pack-download.sh not found"* ]]
}

@test "packs list --registry shows registry packs" {
  setup_pack_download_env
  run bash "$PEON_SH" packs list --registry
  [ "$status" -eq 0 ]
  [[ "$output" == *"test_pack_a"* ]]
  [[ "$output" == *"Test Pack A"* ]]
}

@test "packs list --registry errors when pack-download.sh missing" {
  # Don't call setup_pack_download_env — no scripts/ dir
  run bash "$PEON_SH" packs list --registry
  [ "$status" -ne 0 ]
  [[ "$output" == *"pack-download.sh not found"* ]]
}

@test "help shows packs install command" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"packs install"* ]]
}

@test "help shows packs list --registry" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--registry"* ]]
}

# ============================================================
# Pack rotation
# ============================================================

@test "pack_rotation picks a pack from the list" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["sc_kerrigan"]
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"rot1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # Should use sc_kerrigan pack, not peon
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "pack_rotation keeps same pack within a session" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["sc_kerrigan"]
}
JSON
  # First event pins the pack
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"rot2","permission_mode":"default"}'
  sound1=$(afplay_sound)
  [[ "$sound1" == *"/packs/sc_kerrigan/sounds/"* ]]

  # Second event with same session_id uses same pack
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"rot2","permission_mode":"default"}'
  sound2=$(afplay_sound)
  [[ "$sound2" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "empty pack_rotation falls back to active_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": []
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"rot3","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "agentskill mode uses assigned pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "agentskill"
}
JSON
  # Inject state with session assignment using Python
  python3 <<'PYTHON'
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
now = int(time.time())
state = {'session_packs': {'ask1': {'pack': 'sc_kerrigan', 'last_used': now}}}
with open(state_file, 'w') as f:
    json.dump(state, f)
PYTHON
  
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"ask1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # Should use sc_kerrigan pack from session assignment
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "agentskill mode uses default pack when no assignment" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "agentskill"
}
JSON
  
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"ask2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # Should use peon (active_pack) since ask2 has no assignment
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "agentskill mode falls back when assigned pack missing" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "agentskill"
}
JSON
  # Inject state with invalid pack assignment
  python3 <<'PYTHON'
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
now = int(time.time())
state = {'session_packs': {'ask3': {'pack': 'nonexistent_pack', 'last_used': now}}}
with open(state_file, 'w') as f:
    json.dump(state, f)
PYTHON
  
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"ask3","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # Should fallback to peon (active_pack)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
  
  # Verify ask3 was removed from session_packs
  python3 <<'PYTHON'
import json, os
state_file = os.environ['TEST_DIR'] + '/.state.json'
with open(state_file, 'r') as f:
    state = json.load(f)
if 'ask3' in state.get('session_packs', {}):
    exit(1)  # Fail if ask3 still exists
PYTHON
}

@test "old sessions expire after TTL" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "session_ttl_days": 7
}
JSON
  # Inject state with old and active sessions
  python3 <<'PYTHON'
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
now = int(time.time())
eight_days_ago = now - (8 * 86400)
state = {
    'session_packs': {
        'old_session': {'pack': 'peon', 'last_used': eight_days_ago},
        'active_session': {'pack': 'sc_kerrigan', 'last_used': now}
    }
}
with open(state_file, 'w') as f:
    json.dump(state, f)
PYTHON
  
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"active_session","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  
  # Verify old_session was removed, active_session remains
  python3 <<'PYTHON'
import json, os
state_file = os.environ['TEST_DIR'] + '/.state.json'
with open(state_file, 'r') as f:
    state = json.load(f)
session_packs = state.get('session_packs', {})
if 'old_session' in session_packs:
    exit(1)  # Fail if old_session still exists
if 'active_session' not in session_packs:
    exit(2)  # Fail if active_session was removed
PYTHON
}

# ============================================================
# Linux audio backend detection (order of preference)
# ============================================================

@test "Linux detects pw-play first" {
  export PLATFORM=linux
  # Disable all other players to ensure pw-play is selected
  for player in paplay ffplay mpv play aplay; do
    touch "$TEST_DIR/.disabled_${player}"
  done
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"--volume"* ]]
}

@test "Linux detects paplay when pw-play not available" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"--volume"* ]]
}

@test "Linux detects ffplay when pw-play and paplay not available" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-volume"* ]]
}

@test "Linux detects mpv when pw-play, paplay, and ffplay not available" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"--volume"* ]]
}

@test "Linux detects play (SoX) when pw-play through mpv not available" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay" "$TEST_DIR/.disabled_mpv"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-v"* ]]
}

@test "Linux falls back to aplay when no other backend available" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay" "$TEST_DIR/.disabled_mpv" "$TEST_DIR/.disabled_play"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-q"* ]]
}

@test "Linux continues gracefully when no audio backend available" {
  export PLATFORM=linux
  for player in pw-play paplay ffplay mpv play aplay; do
    touch "$TEST_DIR/.disabled_${player}"
  done
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! linux_audio_was_called
  [[ "$PEON_STDERR" == *"WARNING: No audio backend found"* ]]
}

# ============================================================
# Linux volume handling per backend
# ============================================================

@test "Linux pw-play uses --volume with decimal" {
  export PLATFORM=linux
  for player in paplay ffplay mpv play aplay; do
    touch "$TEST_DIR/.disabled_${player}"
  done
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"--volume 0.3"* ]]
}

@test "Linux paplay scales volume to PulseAudio range" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  # 0.5 * 65536 = 32768
  [[ "$cmdline" == *"--volume=32768"* ]]
}

@test "Linux ffplay scales volume to 0-100" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  # 0.5 * 100 = 50
  [[ "$cmdline" == *"-volume 50"* ]]
}

@test "Linux mpv scales volume to 0-100" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  # 0.5 * 100 = 50
  [[ "$cmdline" == *"--volume=50"* ]]
}

@test "Linux play (SoX) uses -v with decimal" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay" "$TEST_DIR/.disabled_mpv"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-v 0.3"* ]]
}

@test "Linux aplay does not support volume control" {
  export PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay" "$TEST_DIR/.disabled_mpv" "$TEST_DIR/.disabled_play"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  # aplay is used and no volume flags are passed
  [[ "$cmdline" != *"volume"* ]]
  [[ "$cmdline" != *"-v "* ]]
}

# ============================================================
# Devcontainer detection and relay playback
# ============================================================

@test "devcontainer plays sound via relay curl" {
  export PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"/play?"* ]]
  [[ "$cmdline" == *"X-Volume"* ]]
}

@test "devcontainer does not call afplay or linux audio" {
  export PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! linux_audio_was_called
}

@test "devcontainer exits cleanly when relay unavailable" {
  export PLATFORM=devcontainer
  # .relay_available NOT created, so mock curl returns exit 7
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
}

@test "devcontainer SessionStart shows relay guidance when relay unavailable" {
  export PLATFORM=devcontainer
  rm -f "$TEST_DIR/.relay_available"  # Remove to simulate relay unavailable
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" == *"relay not reachable"* ]]
  [[ "$PEON_STDERR" == *"peon relay"* ]]
}

@test "devcontainer SessionStart does NOT show relay guidance when relay available" {
  export PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" != *"relay not reachable"* ]]
}

@test "devcontainer relay respects PEON_RELAY_HOST override" {
  export PLATFORM=devcontainer
  export PEON_RELAY_HOST="custom.host.local"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"custom.host.local"* ]]
}

@test "devcontainer relay respects PEON_RELAY_PORT override" {
  export PLATFORM=devcontainer
  export PEON_RELAY_PORT="12345"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"12345"* ]]
}

@test "devcontainer volume passed in X-Volume header" {
  export PLATFORM=devcontainer
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.7, "enabled": true, "categories": {} }
JSON
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"X-Volume: 0.7"* ]]
}

@test "devcontainer Stop event plays via relay" {
  export PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  relay_was_called
  # Check that /play? appears somewhere in the log (not just last line, since /notify comes after)
  grep -q "/play?" "$TEST_DIR/relay_curl.log"
}

@test "devcontainer notification sent via relay POST" {
  export PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  # PermissionRequest triggers notification
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Should have both /play and /notify relay calls
  relay_was_called
  grep -q "/notify" "$TEST_DIR/relay_curl.log"
}

# ============================================================
# SSH detection and relay playback
# ============================================================

@test "ssh plays sound via relay curl" {
  export PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"/play?"* ]]
  [[ "$cmdline" == *"X-Volume"* ]]
}

@test "ssh does not call afplay or linux audio" {
  export PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! linux_audio_was_called
}

@test "ssh exits cleanly when relay unavailable" {
  export PLATFORM=ssh
  # .relay_available NOT created, so mock curl returns exit 7
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
}

@test "ssh SessionStart shows relay guidance when relay unavailable" {
  export PLATFORM=ssh
  rm -f "$TEST_DIR/.relay_available"  # Remove to simulate relay unavailable
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" == *"SSH session detected"* ]]
  [[ "$PEON_STDERR" == *"relay not reachable"* ]]
  [[ "$PEON_STDERR" == *"ssh -R"* ]]
}

@test "ssh SessionStart does NOT show relay guidance when relay available" {
  export PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" != *"relay not reachable"* ]]
}

@test "ssh relay uses localhost as default host" {
  export PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"localhost"* ]]
}

@test "ssh relay respects PEON_RELAY_HOST override" {
  export PLATFORM=ssh
  export PEON_RELAY_HOST="custom.host.local"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"custom.host.local"* ]]
}

@test "ssh relay respects PEON_RELAY_PORT override" {
  export PLATFORM=ssh
  export PEON_RELAY_PORT="12345"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"12345"* ]]
}

@test "ssh notification sent via relay POST" {
  export PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  # PermissionRequest triggers notification
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  relay_was_called
  grep -q "/notify" "$TEST_DIR/relay_curl.log"
}

# ============================================================
# Mobile push notifications
# ============================================================

@test "mobile ntfy sends push notification on Stop" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "mobile_notify": { "enabled": true, "service": "ntfy", "topic": "test-topic", "server": "https://ntfy.sh" }
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  mobile_was_called
  cmdline=$(mobile_cmdline)
  [[ "$cmdline" == *"MOBILE_NTFY"* ]]
  [[ "$cmdline" == *"ntfy.sh/test-topic"* ]]
}

@test "mobile ntfy sends push on PermissionRequest" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "mobile_notify": { "enabled": true, "service": "ntfy", "topic": "test-topic", "server": "https://ntfy.sh" }
}
JSON
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  mobile_was_called
  cmdline=$(mobile_cmdline)
  [[ "$cmdline" == *"Priority: high"* ]]
}

@test "mobile disabled does not send push" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "mobile_notify": { "enabled": false, "service": "ntfy", "topic": "test-topic" }
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! mobile_was_called
}

@test "mobile not configured does not send push" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! mobile_was_called
}

@test "mobile paused does not send push" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "mobile_notify": { "enabled": true, "service": "ntfy", "topic": "test-topic" }
}
JSON
  touch "$TEST_DIR/.paused"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! mobile_was_called
}

@test "mobile does not send on SessionStart (no NOTIFY)" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "mobile_notify": { "enabled": true, "service": "ntfy", "topic": "test-topic" }
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! mobile_was_called
}

@test "mobile pushover sends notification" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "mobile_notify": { "enabled": true, "service": "pushover", "user_key": "ukey123", "app_token": "atoken456" }
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  mobile_was_called
  cmdline=$(mobile_cmdline)
  [[ "$cmdline" == *"MOBILE_PUSHOVER"* ]]
  [[ "$cmdline" == *"api.pushover.net"* ]]
}

@test "mobile telegram sends notification" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "mobile_notify": { "enabled": true, "service": "telegram", "bot_token": "bot123", "chat_id": "456" }
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  mobile_was_called
  cmdline=$(mobile_cmdline)
  [[ "$cmdline" == *"MOBILE_TELEGRAM"* ]]
  [[ "$cmdline" == *"api.telegram.org"* ]]
}

@test "peon mobile ntfy configures mobile_notify" {
  bash "$PEON_SH" mobile ntfy my-test-topic
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
mn = cfg['mobile_notify']
assert mn['service'] == 'ntfy', f'expected ntfy, got {mn[\"service\"]}'
assert mn['topic'] == 'my-test-topic', f'expected my-test-topic, got {mn[\"topic\"]}'
assert mn['enabled'] == True
"
}

@test "peon mobile off disables mobile" {
  # First configure
  bash "$PEON_SH" mobile ntfy some-topic
  # Then disable
  bash "$PEON_SH" mobile off
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
mn = cfg['mobile_notify']
assert mn['enabled'] == False, 'expected disabled'
assert mn['service'] == 'ntfy', 'service should be preserved'
"
}

@test "peon mobile status shows config" {
  bash "$PEON_SH" mobile ntfy status-topic
  output=$(bash "$PEON_SH" mobile status)
  [[ "$output" == *"on"* ]]
  [[ "$output" == *"ntfy"* ]]
  [[ "$output" == *"status-topic"* ]]
}

@test "help shows mobile commands" {
  output=$(bash "$PEON_SH" help)
  [[ "$output" == *"mobile"* ]]
  [[ "$output" == *"ntfy"* ]]
}

# ============================================================
# Preview command
# ============================================================

@test "preview with no arg plays all session.start sounds" {
  run bash "$PEON_SH" preview
  [ "$status" -eq 0 ]
  [[ "$output" == *"previewing [session.start]"* ]]
  [[ "$output" == *"Ready to work?"* ]]
  [[ "$output" == *"Yes?"* ]]
  afplay_was_called
  # session.start has 2 sounds in the test manifest
  [ "$(afplay_call_count)" -eq 2 ]
}

@test "preview with explicit category plays those sounds" {
  run bash "$PEON_SH" preview task.complete
  [ "$status" -eq 0 ]
  [[ "$output" == *"previewing [task.complete]"* ]]
  afplay_was_called
  # task.complete has 2 sounds in the test manifest
  [ "$(afplay_call_count)" -eq 2 ]
}

@test "preview with single-sound category plays one sound" {
  run bash "$PEON_SH" preview user.spam
  [ "$status" -eq 0 ]
  [[ "$output" == *"Me busy, leave me alone!"* ]]
  afplay_was_called
  [ "$(afplay_call_count)" -eq 1 ]
}

@test "preview with invalid category shows error and available categories" {
  run bash "$PEON_SH" preview nonexistent.category
  [ "$status" -eq 1 ]
  [[ "$output" == *"not found"* ]]
  [[ "$output" == *"Available categories"* ]]
}

@test "help shows preview command" {
  output=$(bash "$PEON_SH" help)
  [[ "$output" == *"preview"* ]]
}

@test "preview --list shows all categories with sound counts" {
  run bash "$PEON_SH" preview --list
  [ "$status" -eq 0 ]
  [[ "$output" == *"categories in"* ]]
  [[ "$output" == *"session.start"* ]]
  [[ "$output" == *"task.complete"* ]]
  [[ "$output" == *"user.spam"* ]]
  [[ "$output" == *"sounds"* ]]
}

# ============================================================
# Adapter config sync (OpenCode / Kilo)
# ============================================================

# Helper: set up a fake OpenCode adapter config dir for sync tests
setup_adapter_sync() {
  export XDG_CONFIG_HOME="$TEST_DIR/xdg_config"
  mkdir -p "$XDG_CONFIG_HOME/opencode/peon-ping"
  # Create a config with adapter-specific keys that should be preserved
  cat > "$XDG_CONFIG_HOME/opencode/peon-ping/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "session.end": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "task.progress": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "spam_threshold": 3,
  "spam_window_seconds": 10,
  "debounce_ms": 500
}
JSON
}

@test "packs use syncs active_pack to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" packs use sc_kerrigan
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
assert cfg['active_pack'] == 'sc_kerrigan', f'expected sc_kerrigan, got {cfg[\"active_pack\"]}'
"
}

@test "packs use preserves adapter-specific keys during sync" {
  setup_adapter_sync
  bash "$PEON_SH" packs use sc_kerrigan
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
# Adapter-specific keys must be preserved
assert cfg['spam_threshold'] == 3, 'spam_threshold should be preserved'
assert cfg['debounce_ms'] == 500, 'debounce_ms should be preserved'
assert cfg['categories']['session.end'] == True, 'session.end category should be preserved'
"
}

@test "packs next syncs active_pack to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" packs next
  python3 -c "
import json
# The canonical config should have switched from peon to sc_kerrigan (alphabetical)
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
assert cfg['active_pack'] == 'sc_kerrigan', f'expected sc_kerrigan, got {cfg[\"active_pack\"]}'
"
}

@test "notifications off syncs desktop_notifications to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" notifications off
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
assert cfg['desktop_notifications'] == False, 'expected desktop_notifications False'
"
}

@test "notifications on syncs desktop_notifications to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" notifications off
  bash "$PEON_SH" notifications on
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
assert cfg['desktop_notifications'] == True, 'expected desktop_notifications True'
"
}

@test "pause syncs .paused to OpenCode adapter config dir" {
  setup_adapter_sync
  bash "$PEON_SH" pause
  [ -f "$XDG_CONFIG_HOME/opencode/peon-ping/.paused" ]
}

@test "resume removes .paused from OpenCode adapter config dir" {
  setup_adapter_sync
  bash "$PEON_SH" pause
  [ -f "$XDG_CONFIG_HOME/opencode/peon-ping/.paused" ]
  bash "$PEON_SH" resume
  [ ! -f "$XDG_CONFIG_HOME/opencode/peon-ping/.paused" ]
}

@test "toggle syncs .paused to OpenCode adapter config dir" {
  setup_adapter_sync
  bash "$PEON_SH" toggle
  [ -f "$XDG_CONFIG_HOME/opencode/peon-ping/.paused" ]
  bash "$PEON_SH" toggle
  [ ! -f "$XDG_CONFIG_HOME/opencode/peon-ping/.paused" ]
}

@test "mobile ntfy syncs mobile_notify to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" mobile ntfy test-topic
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
mn = cfg['mobile_notify']
assert mn['service'] == 'ntfy', f'expected ntfy, got {mn[\"service\"]}'
assert mn['topic'] == 'test-topic', f'expected test-topic, got {mn[\"topic\"]}'
"
}

@test "mobile off syncs mobile_notify to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" mobile ntfy test-topic
  bash "$PEON_SH" mobile off
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
mn = cfg['mobile_notify']
assert mn['enabled'] == False, 'expected disabled'
"
}

@test "sync skips when no adapter config dirs exist" {
  # Do NOT set up adapter config dirs — sync should be a no-op
  export XDG_CONFIG_HOME="$TEST_DIR/empty_xdg"
  mkdir -p "$XDG_CONFIG_HOME"
  # Should not error
  run bash "$PEON_SH" packs use sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to sc_kerrigan"* ]]
}

# ============================================================
# Tab color profiles
# ============================================================

@test "tab color profile: project-specific colors override defaults" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tab_color'] = {
    'color_profiles': {
        'myproject': {
            'ready': [10, 20, 30],
            'working': [40, 50, 60],
            'done': [70, 80, 90],
            'needs_approval': [100, 110, 120]
        }
    }
}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/.tab_color_rgb" ]
  tab_rgb=$(cat "$TEST_DIR/.tab_color_rgb")
  [ "$tab_rgb" = "10 20 30" ]
}

@test "tab color profile: unmatched project falls back to defaults" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tab_color'] = {
    'color_profiles': {
        'other-project': {
            'ready': [10, 20, 30]
        }
    }
}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/.tab_color_rgb" ]
  tab_rgb=$(cat "$TEST_DIR/.tab_color_rgb")
  # Default ready color: 65 115 80
  [ "$tab_rgb" = "65 115 80" ]
}

@test "tab color profile: partial override inherits remaining states from defaults" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tab_color'] = {
    'color_profiles': {
        'myproject': {
            'ready': [10, 20, 30]
        }
    }
}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # SessionStart → status 'ready' → should use profile color
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  tab_rgb=$(cat "$TEST_DIR/.tab_color_rgb")
  [ "$tab_rgb" = "10 20 30" ]

  rm -f "$TEST_DIR/.tab_color_rgb"

  # Stop → status 'done' → profile has no 'done', should fall back to default (65 100 140)
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  tab_rgb=$(cat "$TEST_DIR/.tab_color_rgb")
  [ "$tab_rgb" = "65 100 140" ]
}

@test "tab color profile: non-dict profile value is ignored gracefully" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tab_color'] = {
    'color_profiles': {
        'myproject': 'invalid'
    }
}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/.tab_color_rgb" ]
  tab_rgb=$(cat "$TEST_DIR/.tab_color_rgb")
  # Should fall back to default ready color
  [ "$tab_rgb" = "65 115 80" ]
}

# ============================================================
# New event routing: PostToolUseFailure, PreCompact, task.acknowledge
# ============================================================

@test "PostToolUseFailure with Bash error plays task.error sound" {
  run_peon '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","error":"Exit code 1","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "PostToolUseFailure with non-Bash tool exits silently" {
  run_peon '{"hook_event_name":"PostToolUseFailure","tool_name":"Read","error":"File not found","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "PostToolUseFailure with Bash but no error exits silently" {
  run_peon '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "PreCompact plays resource.limit sound" {
  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Limit"* ]]
}

@test "task.acknowledge is off by default (no sound without explicit config)" {
  # Override config to NOT include task.acknowledge in categories
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  }
}
JSON
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "task.acknowledge plays sound when explicitly enabled" {
  # Override config to enable task.acknowledge
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "task.acknowledge": true,
    "user.spam": true
  }
}
JSON
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Ack"* ]]
}

# ============================================================
# Icon resolution (CESP 5.5)
# ============================================================

@test "Icon: pack-level icon is resolved" {
  # Add icon field to pack manifest root
  python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['icon'] = 'pack-icon.png'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  echo "fake-png" > "$TEST_DIR/packs/peon/pack-icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [[ "$icon" == *"/packs/peon/pack-icon.png" ]]
}

@test "Icon: category-level icon overrides pack-level" {
  python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['icon'] = 'pack-icon.png'
m['categories']['task.complete']['icon'] = 'cat-icon.png'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  echo "fake-png" > "$TEST_DIR/packs/peon/pack-icon.png"
  echo "fake-png" > "$TEST_DIR/packs/peon/cat-icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [[ "$icon" == *"/packs/peon/cat-icon.png" ]]
}

@test "Icon: sound-level icon overrides category and pack" {
  python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['icon'] = 'pack-icon.png'
m['categories']['task.complete']['icon'] = 'cat-icon.png'
for s in m['categories']['task.complete']['sounds']:
    s['icon'] = 'snd-icon.png'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  echo "fake-png" > "$TEST_DIR/packs/peon/pack-icon.png"
  echo "fake-png" > "$TEST_DIR/packs/peon/cat-icon.png"
  echo "fake-png" > "$TEST_DIR/packs/peon/snd-icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [[ "$icon" == *"/packs/peon/snd-icon.png" ]]
}

@test "Icon: icon.png at pack root used as fallback" {
  # No icon fields in manifest, but icon.png exists at pack root
  echo "fake-png" > "$TEST_DIR/packs/peon/icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [[ "$icon" == *"/packs/peon/icon.png" ]]
}

@test "Icon: path traversal is blocked" {
  python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['icon'] = '../../etc/passwd'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [ -z "$icon" ]
}

@test "Icon: missing icon file results in empty path" {
  python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['icon'] = 'nonexistent.png'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [ -z "$icon" ]
}

@test "Icon: no icon fields uses default fallback" {
  # Standard manifest with no icon fields — .icon_path should not be written
  mkdir -p "$TEST_DIR/docs"
  echo "fake-png" > "$TEST_DIR/docs/peon-icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [ -z "$icon" ]
  # Overlay should still use default peon-icon.png
  if [ -f "$TEST_DIR/overlay.log" ]; then
    [[ "$(cat "$TEST_DIR/overlay.log")" == *"peon-icon.png"* ]]
  fi
}

@test "Icon: sound-level icon takes priority over all levels" {
  # Set all three levels, verify sound wins
  python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['icon'] = 'pack-icon.png'
m['categories']['task.complete']['icon'] = 'cat-icon.png'
for s in m['categories']['task.complete']['sounds']:
    s['icon'] = 'snd-icon.png'
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  echo "fake-png" > "$TEST_DIR/packs/peon/pack-icon.png"
  echo "fake-png" > "$TEST_DIR/packs/peon/cat-icon.png"
  echo "fake-png" > "$TEST_DIR/packs/peon/snd-icon.png"
  echo "fake-png" > "$TEST_DIR/packs/peon/icon.png"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  icon=$(resolved_icon)
  [[ "$icon" == *"/packs/peon/snd-icon.png" ]]
}

# ============================================================
# mac overlay: click-to-focus IDE PID passing
# ============================================================

@test "mac overlay call includes IDE PID as 7th argument" {
  # On mac (default platform in tests), the overlay is invoked via osascript.
  # peon.sh should append the IDE ancestor PID as the 7th positional argument.
  # In the test environment there is no Cursor ancestor, so _ide_pid=0 is expected.
  export PLATFORM=mac
  mkdir -p "$TEST_DIR/scripts"
  touch "$TEST_DIR/scripts/mac-overlay.js"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/overlay.log" ]
  # overlay.log line: -l JavaScript /path/mac-overlay.js msg color icon slot dismiss ide_pid
  args=$(tail -1 "$TEST_DIR/overlay.log")
  # Count space-separated tokens — should be at least 7 after "-l JavaScript script"
  count=$(echo "$args" | wc -w | tr -d ' ')
  [ "$count" -ge 7 ]
}

@test "mac overlay IDE PID argument is numeric" {
  export PLATFORM=mac
  mkdir -p "$TEST_DIR/scripts"
  touch "$TEST_DIR/scripts/mac-overlay.js"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/overlay.log" ]
  ide_pid=$(tail -1 "$TEST_DIR/overlay.log" | awk '{print $NF}')
  [[ "$ide_pid" =~ ^[0-9]+$ ]]
}

@test "mac overlay IDE ancestor PID detection skips Helper processes" {
  # Mock ps so the chain is: $$ → 9000 (Cursor Helper) → 8000 (Cursor) → 1
  # The walker must skip 9000 (Helper) and return 8000 (Cursor).
  cat > "$TEST_DIR/mock_bin/ps" <<'SCRIPT'
#!/bin/bash
# ps -p PID -o FIELD  ($1=-p $2=PID $3=-o $4=FIELD)
PID="$2"; FIELD="$4"
case "$FIELD" in
  ppid=) case "$PID" in 9000) echo "8000";; 8000) echo "1";; *) echo "9000";; esac ;;
  comm=) case "$PID" in 9000) echo "Cursor Helper: terminal pty-host";; 8000) echo "Cursor";; *) echo "bash";; esac ;;
esac
SCRIPT
  chmod +x "$TEST_DIR/mock_bin/ps"

  ide_pid=$(
    _check=$$
    _ide_pid=0
    for _i in 1 2 3 4 5 6 7 8 9 10; do
      _check=$(ps -p "$_check" -o ppid= 2>/dev/null | tr -d ' ')
      [ -z "$_check" ] || [ "$_check" = "1" ] || [ "$_check" = "0" ] && break
      _comm=$(ps -p "$_check" -o comm= 2>/dev/null)
      echo "$_comm" | grep -qi "helper" && continue
      if echo "$_comm" | grep -qi "cursor\|windsurf\|zed\| code"; then
        _ide_pid=$_check
        break
      fi
    done
    echo "$_ide_pid"
  )

  [ "$ide_pid" = "8000" ]
}


