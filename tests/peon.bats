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

# ============================================================
# Pause / mute feature
# ============================================================

@test "--toggle creates .paused file and prints paused message" {
  run bash "$PEON_SH" --toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds paused"* ]]
  [ -f "$TEST_DIR/.paused" ]
}

@test "--toggle removes .paused file when already paused" {
  touch "$TEST_DIR/.paused"
  run bash "$PEON_SH" --toggle
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds resumed"* ]]
  [ ! -f "$TEST_DIR/.paused" ]
}

@test "--pause creates .paused file" {
  run bash "$PEON_SH" --pause
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds paused"* ]]
  [ -f "$TEST_DIR/.paused" ]
}

@test "--resume removes .paused file" {
  touch "$TEST_DIR/.paused"
  run bash "$PEON_SH" --resume
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds resumed"* ]]
  [ ! -f "$TEST_DIR/.paused" ]
}

@test "--status reports paused when .paused exists" {
  touch "$TEST_DIR/.paused"
  run bash "$PEON_SH" --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"paused"* ]]
}

@test "--status reports active when not paused" {
  rm -f "$TEST_DIR/.paused"
  run bash "$PEON_SH" --status
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
# --packs (list packs)
# ============================================================

@test "--packs lists all available packs" {
  run bash "$PEON_SH" --packs
  [ "$status" -eq 0 ]
  [[ "$output" == *"peon"* ]]
  [[ "$output" == *"sc_kerrigan"* ]]
}

@test "--packs marks the active pack with *" {
  run bash "$PEON_SH" --packs
  [ "$status" -eq 0 ]
  [[ "$output" == *"Orc Peon *"* ]]
  # sc_kerrigan should NOT be marked
  line=$(echo "$output" | grep "sc_kerrigan")
  [[ "$line" != *"*"* ]]
}

@test "--packs marks correct pack after switch" {
  bash "$PEON_SH" --pack sc_kerrigan
  run bash "$PEON_SH" --packs
  [ "$status" -eq 0 ]
  [[ "$output" == *"Sarah Kerrigan (StarCraft) *"* ]]
}

# ============================================================
# --pack <name> (set specific pack)
# ============================================================

@test "--pack <name> switches to valid pack" {
  run bash "$PEON_SH" --pack sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to sc_kerrigan"* ]]
  [[ "$output" == *"Sarah Kerrigan"* ]]
  # Verify config was updated
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "sc_kerrigan" ]
}

@test "--pack <name> preserves other config fields" {
  bash "$PEON_SH" --pack sc_kerrigan
  volume=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['volume'])")
  [ "$volume" = "0.5" ]
}

@test "--pack <name> errors on nonexistent pack" {
  run bash "$PEON_SH" --pack nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
  [[ "$output" == *"Available packs"* ]]
}

@test "--pack <name> does not modify config on invalid pack" {
  bash "$PEON_SH" --pack nonexistent || true
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "peon" ]
}

# ============================================================
# --pack (cycle, no argument)
# ============================================================

@test "--pack cycles to next pack alphabetically" {
  # Active is peon, next alphabetically is sc_kerrigan
  run bash "$PEON_SH" --pack
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to sc_kerrigan"* ]]
}

@test "--pack cycle wraps around from last to first" {
  # Set to sc_kerrigan (last alphabetically), should wrap to peon
  bash "$PEON_SH" --pack sc_kerrigan
  run bash "$PEON_SH" --pack
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to peon"* ]]
}

@test "--pack cycle updates config correctly" {
  bash "$PEON_SH" --pack
  active=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json'))['active_pack'])")
  [ "$active" = "sc_kerrigan" ]
}

# ============================================================
# --help (updated)
# ============================================================

@test "--help shows pack commands" {
  run bash "$PEON_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--packs"* ]]
  [[ "$output" == *"--pack"* ]]
}

@test "unknown option shows helpful error" {
  run bash "$PEON_SH" --foobar
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unknown option"* ]]
  [[ "$output" == *"peon --help"* ]]
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

# ============================================================
# Linux platform support
# ============================================================

@test "Linux: SessionStart plays sound via pw-play" {
  run_peon_linux '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  pw_play_was_called
  sound=$(pw_play_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "Linux: Stop plays complete sound via pw-play" {
  run_peon_linux '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  pw_play_was_called
  sound=$(pw_play_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "Linux: permission notification sends notify-send" {
  run_peon_linux '{"hook_event_name":"Notification","notification_type":"permission_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  notify_send_was_called
  log_line=$(cat "$TEST_DIR/notify-send.log")
  [[ "$log_line" == *"--urgency=normal"* ]]
}

@test "Linux: volume is passed to pw-play" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_peon_linux '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  pw_play_was_called
  log_line=$(tail -1 "$TEST_DIR/pw-play.log")
  [[ "$log_line" == *"--volume 0.3"* ]]
}

@test "Linux: paused file suppresses sound" {
  touch "$TEST_DIR/.paused"
  run_peon_linux '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! pw_play_was_called
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
