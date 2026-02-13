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

@test "help shows packs remove command" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"packs remove"* ]]
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
