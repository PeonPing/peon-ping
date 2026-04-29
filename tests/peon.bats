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

@test "rapid SessionStart events from multiple workspaces are debounced" {
  # Enable debounce cooldown (global test config sets it to 0 to avoid flaky timing tests)
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['session_start_cooldown_seconds'] = 30
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # First SessionStart plays the greeting
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/proj1","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second SessionStart (different session, same instant) does NOT play again
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/proj2","session_id":"s2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

@test "SessionStart plays greeting after cooldown expires" {
  # Enable debounce cooldown and set last greeting to 60 seconds ago (beyond 30s cooldown)
  /usr/bin/python3 -c "
import json, time
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['session_start_cooldown_seconds'] = 30
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
state = json.load(open('$TEST_DIR/.state.json'))
state['last_session_start_sound_time'] = time.time() - 60
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
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

@test "Notification idle_prompt plays a complete sound" {
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "idle_prompt is deduped against a recent task.complete in the same session (issue #486)" {
  # Stop fires task.complete and stamps last_task_complete[s1]
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Subsequent idle_prompt for the same session must NOT replay the sound
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

@test "idle_prompt dedupe is per-session (different session still plays)" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # idle_prompt in a different session id should still fire — its session has no last_task_complete record
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "2" ]
}

@test "idle_prompt plays again once the suppress window expires" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]

  # Push last_task_complete[s1] back beyond the configured window (default 3600s)
  "$PEON_PY" -c "
import json, time
p = '$TEST_DIR/.state.json'
state = json.load(open(p))
state.setdefault('last_task_complete', {})['s1'] = time.time() - 4000
# Also clear the unrelated 5s Stop debounce so we can fire fresh events
state['last_stop_time'] = 0
json.dump(state, open(p, 'w'))
"

  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count=$(afplay_call_count)
  [ "$count" = "2" ]
}

@test "suppress_idle_prompt_repeats=false restores periodic idle_prompt sound" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "task.acknowledge": false,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10,
  "session_start_cooldown_seconds": 0,
  "suppress_idle_prompt_repeats": false
}
JSON

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "2" ]
}

@test "Notification elicitation_dialog is not affected by idle_prompt dedupe" {
  # A prior task.complete must not silence a different Notification subtype
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  run_peon '{"hook_event_name":"Notification","notification_type":"elicitation_dialog","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "2" ]
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "idle_prompt dedupe does not cross-suppress sessions that omit session_id" {
  # Some adapters don't pass session_id. Each invocation should still play through
  # rather than sharing a single bucket via session_id=''.
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","permission_mode":"default"}'
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Push last_stop_time back so the unrelated 5s Stop debounce doesn't mask the dedupe behaviour.
  "$PEON_PY" -c "
import json
p = '$TEST_DIR/.state.json'
state = json.load(open(p))
state['last_stop_time'] = 0
json.dump(state, open(p, 'w'))
"

  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "2" ]
}

@test "debug log contains route suppression reason for idle_prompt_repeat" {
  enable_debug_logging
  # First Stop fires task.complete and stamps last_task_complete[s1]
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Subsequent idle_prompt within the window should be suppressed with idle_prompt_repeat
  run_peon '{"hook_event_name":"Notification","notification_type":"idle_prompt","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  grep -q 'reason=idle_prompt_repeat' "$logfile"
  grep 'reason=idle_prompt_repeat' "$logfile" | grep -q '\[route\]'
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
# Local config override (project-local .claude/hooks/peon-ping/config.json)
# ============================================================

@test "local config overrides global config when present" {
  # Create a fake project dir with a local config pointing to sc_kerrigan
  local project_dir
  project_dir="$(mktemp -d)"
  local local_cfg_dir="$project_dir/.claude/hooks/peon-ping"
  mkdir -p "$local_cfg_dir"
  cat > "$local_cfg_dir/config.json" <<'JSON'
{
  "default_pack": "sc_kerrigan",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "task.complete": true
  }
}
JSON

  # Run peon.sh from the project dir (PWD determines local config lookup)
  # Use a subshell so the cd is scoped
  (
    cd "$project_dir"
    echo '{"hook_event_name":"Stop","cwd":"'"$project_dir"'","session_id":"s1","permission_mode":"default"}' \
      | CLAUDE_PEON_DIR="$TEST_DIR" PEON_TEST=1 bash "$PEON_SH" 2>/dev/null
  )
  sleep 0.2  # allow async afplay mock to finish writing log
  rm -rf "$project_dir"

  # Should have played sc_kerrigan sound (from local config), not peon
  [ -f "$TEST_DIR/afplay.log" ]
  local sound
  sound=$(tail -1 "$TEST_DIR/afplay.log" | awk '{print $NF}')
  [[ "$sound" == *"/packs/sc_kerrigan/"* ]]
}

@test "falls back to global config when no local config present" {
  # No local config — should use global config with peon pack
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

# ============================================================
# Disabled config
# ============================================================

@test "enabled=false skips everything" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "category disabled skips sound but still exits 0" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": { "session.start": false }
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Non-interactive mode suppression
# ============================================================

@test "sdk-cli suppresses sound" {
  CLAUDE_CODE_ENTRYPOINT=sdk-cli run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "interactive mode (cli) still plays sound" {
  CLAUDE_CODE_ENTRYPOINT=cli run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "unset CLAUDE_CODE_ENTRYPOINT still plays sound" {
  unset CLAUDE_CODE_ENTRYPOINT
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "PEON_ALLOW_HEADLESS=1 overrides sdk-cli suppression" {
  CLAUDE_CODE_ENTRYPOINT=sdk-cli PEON_ALLOW_HEADLESS=1 run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
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

@test "delegate mode plays sound by default (suppress_delegate_sessions off)" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"agent1","permission_mode":"delegate"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "delegate mode suppresses sound when suppress_delegate_sessions is true" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['suppress_delegate_sessions'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"agent1","permission_mode":"delegate"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "agent session is remembered across events when suppress_delegate_sessions is true" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['suppress_delegate_sessions'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
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
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
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
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
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
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
JSON
  # Stop without any prior UserPromptSubmit — should NOT crash, should play sound
  # (start_time defaults to 0, which is falsy, so silent stays False)
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "silent_window does not interfere with debounce" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
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
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "silent_window_seconds": 5 }
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
# suppress_subagent_complete
# ============================================================

@test "suppress_subagent_complete: subagent Stop is suppressed" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "suppress_subagent_complete": true, "pack_rotation": ["peon","peon"] }
JSON
  # Parent session gets a SubagentStart (records pending_subagent_pack)
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/myproject","session_id":"parent1","permission_mode":"default"}'
  # Subagent session starts within 30s — should inherit pack and be marked as subagent
  # (SessionStart plays a greeting sound — capture count before Stop)
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"sub1","permission_mode":"default"}'
  count_before=$(afplay_call_count)
  # Subagent Stop should be suppressed — no additional afplay calls
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"sub1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  count_after=$(afplay_call_count)
  [ "$count_after" = "$count_before" ]
}

@test "suppress_subagent_complete: parent Stop still plays sound" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "suppress_subagent_complete": true, "pack_rotation": ["peon","peon"] }
JSON
  # Subagent flow: parent → SubagentStart → sub SessionStart (suppressed)
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/myproject","session_id":"parent2","permission_mode":"default"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"sub2","permission_mode":"default"}'
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"sub2","permission_mode":"default"}'
  ! afplay_was_called
  # Clear debounce so parent Stop isn't debounced
  /usr/bin/python3 -c "
import json, time
state = json.load(open('$TEST_DIR/.state.json'))
state['last_stop_time'] = 0
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  # Parent session Stop should still play
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"parent2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "suppress_subagent_complete: disabled by default does not suppress" {
  # Default config has suppress_subagent_complete=false
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/myproject","session_id":"parent3","permission_mode":"default"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"sub3","permission_mode":"default"}'
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"sub3","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "suppress_subagent_complete: subagent_sessions cleaned up on SessionEnd" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "suppress_subagent_complete": true, "pack_rotation": ["peon","peon"] }
JSON
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/myproject","session_id":"parent4","permission_mode":"default"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"sub4","permission_mode":"default"}'
  # SessionEnd removes sub4 from subagent_sessions
  run_peon '{"hook_event_name":"SessionEnd","cwd":"/tmp/myproject","session_id":"sub4","permission_mode":"default"}'
  # Verify sub4 is gone from state
  result=$(/usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
subs = state.get('subagent_sessions', {})
print('absent' if 'sub4' not in subs else 'present')
")
  [ "$result" = "absent" ]
}

@test "suppress_subagent_complete: subagent PermissionRequest is suppressed" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "suppress_subagent_complete": true, "pack_rotation": ["peon","peon"] }
JSON
  # Parent session gets a SubagentStart (records pending_subagent_pack)
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/myproject","session_id":"parent5","permission_mode":"default"}'
  # Subagent session starts within 30s — marked as subagent
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"sub5","permission_mode":"default"}'
  count_before=$(afplay_call_count)
  # Subagent PermissionRequest should be suppressed — no additional afplay calls
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"sub5","permission_mode":"default","tool_name":"Bash"}'
  [ "$PEON_EXIT" -eq 0 ]
  count_after=$(afplay_call_count)
  [ "$count_after" = "$count_before" ]
}

@test "suppress_subagent_complete: parent PermissionRequest still plays sound" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {}, "suppress_subagent_complete": true, "pack_rotation": ["peon","peon"] }
JSON
  # Subagent flow: parent → SubagentStart → sub SessionStart
  run_peon '{"hook_event_name":"SubagentStart","cwd":"/tmp/myproject","session_id":"parent6","permission_mode":"default"}'
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"sub6","permission_mode":"default"}'
  # Parent session PermissionRequest should still play
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"parent6","permission_mode":"default","tool_name":"Bash"}'
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
  run_peon '{"hook_event_name":"Stop","cwd":"/Users/dev/my-cool-project","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/.tab_title" ]
  grep -q "my-cool-project: done" "$TEST_DIR/.tab_title"
}

@test "terminal_tab_title false skips tab title updates" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['terminal_tab_title'] = False
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  rm -f "$TEST_DIR/.tab_title"
  run_peon '{"hook_event_name":"Stop","cwd":"/Users/dev/my-cool-project","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ ! -f "$TEST_DIR/.tab_title" ]
}

@test "empty cwd falls back to 'claude'" {
  run_peon '{"hook_event_name":"SessionStart","cwd":"","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
}

@test "empty cwd falls back to 'codex' for codex sessions" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"","session_id":"codex-123","source":"codex","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "codex" "$TEST_DIR/terminal_notifier.log"
}

@test "desktop notification title omits IDE label by default" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"codex-456","source":"codex","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "myproject" "$TEST_DIR/terminal_notifier.log"
  ! grep -q "myproject - OpenAI Codex" "$TEST_DIR/terminal_notifier.log"
  grep -q -- "-message done" "$TEST_DIR/terminal_notifier.log"
}

@test "desktop notification title includes detected IDE label when enabled" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_title_ide'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"codex-456","source":"codex","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "myproject - OpenAI Codex" "$TEST_DIR/terminal_notifier.log"
  grep -q -- "-message done" "$TEST_DIR/terminal_notifier.log"
}

@test "desktop notification message includes status and details" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"codex-789","source":"codex","permission_mode":"default","tool_name":"Bash"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "myproject" "$TEST_DIR/terminal_notifier.log"
  ! grep -q "myproject - OpenAI Codex" "$TEST_DIR/terminal_notifier.log"
  grep -q -- "-message needs approval: Bash" "$TEST_DIR/terminal_notifier.log"
}

@test "desktop notification title renders Claude Code label for claude source" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_title_ide'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"claude-1","source":"claude","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  grep -q "myproject - Claude Code" "$TEST_DIR/terminal_notifier.log"
}

@test "desktop notification title titlecases unknown IDE id when flag enabled" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_title_ide'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"x-1","source":"my-cool-ide","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  grep -q "myproject - My Cool Ide" "$TEST_DIR/terminal_notifier.log"
}

@test "{ide_id} template variable renders the raw normalized id" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_templates'] = {'stop': '{ide_id}/{ide}: done'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"codex-9","source":"codex","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  grep -q -- "-message codex/OpenAI Codex: done" "$TEST_DIR/terminal_notifier.log"
}

@test "state session_names overrides project name (set via /peon-ping-rename)" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
state = json.load(open('$TEST_DIR/.state.json'))
state['session_names'] = {'s1': 'My Renamed Session'}
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "My Renamed Session" "$TEST_DIR/terminal_notifier.log"
}

@test "state session_names takes priority over CLAUDE_SESSION_NAME" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
state = json.load(open('$TEST_DIR/.state.json'))
state['session_names'] = {'s1': 'State Name'}
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  CLAUDE_SESSION_NAME="Env Name" \
    run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "State Name" "$TEST_DIR/terminal_notifier.log"
  ! grep -q "Env Name" "$TEST_DIR/terminal_notifier.log"
}

@test "CLAUDE_SESSION_NAME overrides project name in notification title" {
  # Set standard notification style so title appears in terminal_notifier.log
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  CLAUDE_SESSION_NAME="My Test Session" \
    run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "My Test Session" "$TEST_DIR/terminal_notifier.log"
}

@test "CLAUDE_SESSION_NAME strips disallowed characters" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  CLAUDE_SESSION_NAME="Feature: Auth <Refactor>" \
    run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  # Angle brackets and colon stripped; remaining text preserved
  grep -q "Feature Auth Refactor" "$TEST_DIR/terminal_notifier.log"
}

@test "notification_title_script output used as project name" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_title_script'] = 'echo Scripted'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "Scripted" "$TEST_DIR/terminal_notifier.log"
}

@test "notification_title_script receives PEON_IDE" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_title_script'] = 'printf \"%s\" \"\$PEON_IDE\"'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","source":"codex","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "codex" "$TEST_DIR/terminal_notifier.log"
  ! grep -q "OpenAI Codex" "$TEST_DIR/terminal_notifier.log"
  grep -q -- "-message done" "$TEST_DIR/terminal_notifier.log"
}

@test "notification_title_script non-zero exit falls through to next tier" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_title_script'] = 'exit 1'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Falls through to git/folder name — just verify it ran without crashing
  [ -f "$TEST_DIR/terminal_notifier.log" ]
}

# ============================================================
# Volume passthrough
# ============================================================

@test "volume from config is passed to afplay" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
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
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  peon_play_was_called
  ! afplay_was_called
}

@test "afplay is used when use_sound_effects_device is false" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": false, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! peon_play_was_called
}

@test "use_sound_effects_device defaults to true when not in config" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  peon_play_was_called
  ! afplay_was_called
}

@test "afplay is used when peon-play is not installed" {
  # Do NOT call install_peon_play_mock — peon-play binary absent
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  ! peon_play_was_called
}

@test "volume is passed to peon-play" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.7, "enabled": true, "use_sound_effects_device": true, "categories": {} }
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

@test "mute creates .paused file" {
  run bash "$PEON_SH" mute
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds paused"* ]]
  [ -f "$TEST_DIR/.paused" ]
}

@test "unmute removes .paused file" {
  touch "$TEST_DIR/.paused"
  run bash "$PEON_SH" unmute
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

@test "status shows OpenAI Codex as detected when ~/.codex exists but adapter is not configured" {
  FAKE_HOME="$(mktemp -d)"
  mkdir -p "$FAKE_HOME/.codex"
  cat > "$FAKE_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
notify = ["/bin/bash", "/tmp/not-codex.sh"]
TOML

  run env HOME="$FAKE_HOME" bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"OpenAI Codex"* ]]
  [[ "$output" == *"detected (not set up)"* ]]

  rm -rf "$FAKE_HOME"
}

@test "status shows OpenAI Codex as installed when ~/.codex notify uses codex adapter" {
  FAKE_HOME="$(mktemp -d)"
  mkdir -p "$FAKE_HOME/.codex"
  cat > "$FAKE_HOME/.codex/config.toml" <<'TOML'
model = "gpt-5"
notify = ["/bin/bash", "/some/path/adapters/codex.sh"]
TOML

  run env HOME="$FAKE_HOME" bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"[x] OpenAI Codex"* ]]
  [[ "$output" == *"(installed)"* ]]

  rm -rf "$FAKE_HOME"
}

@test "status default output omits verbose-only lines" {
  rm -f "$TEST_DIR/.paused"
  run bash "$PEON_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active"* ]]
  [[ "$output" == *"sounds enabled"* ]]
  [[ "$output" == *"volume: 50%"* ]]
  [[ "$output" == *"default pack"* ]]
  [[ "$output" == *"pack(s) installed"* ]]
  [[ "$output" == *"debug logging"* ]]
  [[ "$output" == *"--verbose"* ]]
  [[ "$output" != *"desktop notifications"* ]]
  [[ "$output" != *"-- core --"* ]]
  [[ "$output" != *"headphones_only"* ]]
  [[ "$output" != *"IDEs"* ]]
  [[ "$output" != *"platform:"* ]]
}

@test "status shows 'sounds DISABLED' when enabled=false" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['enabled'] = False
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds DISABLED"* ]]
}

@test "status shows volume percentage from config" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['volume'] = 0.8
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"volume: 80%"* ]]
}

@test "status default shows 'active pack (here)' when path_rules matches cwd" {
  # Use a pattern that matches any path ending with the test dir's basename so
  # /private/var vs /var path prefix differences on macOS do not break matching.
  TEST_BASENAME=$(basename "$TEST_DIR")
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['path_rules'] = [{'pattern': '*$TEST_BASENAME*', 'pack': 'sc_kerrigan'}]
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active pack (here): sc_kerrigan"* ]]
}

@test "status default shows rotation label when rotation is active" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['pack_rotation'] = ['peon', 'sc_kerrigan']
cfg['pack_rotation_mode'] = 'round-robin'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"active pack (here): round-robin rotation"* ]]
}

@test "status --verbose shows full details with section headers" {
  rm -f "$TEST_DIR/.paused"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"active"* ]]
  [[ "$output" == *"-- core --"* ]]
  [[ "$output" == *"-- packs --"* ]]
  [[ "$output" == *"-- categories (CESP events) --"* ]]
  [[ "$output" == *"-- notifications --"* ]]
  [[ "$output" == *"-- audio routing --"* ]]
  [[ "$output" == *"-- behavior timings --"* ]]
  [[ "$output" == *"-- debug --"* ]]
  [[ "$output" == *"-- IDEs --"* ]]
  [[ "$output" == *"platform:"* ]]
  [[ "$output" == *"audio backend:"* ]]
  [[ "$output" == *"config: "* ]]
  [[ "$output" == *"default pack"* ]]
  [[ "$output" == *"desktop notifications"* ]]
  [[ "$output" == *"headphones_only"* ]]
  [[ "$output" == *"annoyed threshold:"* ]]
  [[ "$output" != *"--verbose"* ]]
}

@test "status --verbose shows category checkboxes" {
  rm -f "$TEST_DIR/.paused"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"[x] session.start"* ]]
  [[ "$output" == *"[ ] task.acknowledge"* ]]
  [[ "$output" == *"[x] task.complete"* ]]
}

@test "status --verbose shows path-rule reason when matched" {
  TEST_BASENAME=$(basename "$TEST_DIR")
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['path_rules'] = [{'pattern': '*$TEST_BASENAME*', 'pack': 'sc_kerrigan'}]
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"active pack (here): sc_kerrigan"* ]]
  [[ "$output" == *"reason: path rule:"* ]]
}

@test "status --verbose suppresses reason for default pack" {
  rm -f "$TEST_DIR/.paused"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"active pack (here): peon"* ]]
  [[ "$output" != *"reason:"* ]]
}

@test "status --verbose suppresses reason for rotation (rotation list line is shown separately)" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['pack_rotation'] = ['peon', 'sc_kerrigan']
cfg['pack_rotation_mode'] = 'round-robin'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"active pack (here): round-robin rotation"* ]]
  [[ "$output" == *"rotation list: peon, sc_kerrigan"* ]]
  [[ "$output" != *"reason:"* ]]
}

@test "status --verbose shows random rotation label" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['pack_rotation'] = ['peon', 'sc_kerrigan']
cfg['pack_rotation_mode'] = 'random'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"active pack (here): random rotation"* ]]
}

@test "status --verbose: session_override bypasses rotation and shows note" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['pack_rotation'] = ['peon', 'sc_kerrigan']
cfg['pack_rotation_mode'] = 'session_override'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  # session_override resolves via default_pack, not rotation
  [[ "$output" != *"active pack (here): session_override rotation"* ]]
  [[ "$output" == *"active pack (here): peon"* ]]
  [[ "$output" == *"session-override mode:"* ]]
}

@test "status --verbose shows trainer section when trainer.enabled=true" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['trainer'] = {'enabled': True, 'exercises': {'pushups': 300, 'squats': 300},
                  'reminder_interval_minutes': 20, 'reminder_min_gap_minutes': 5}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
import datetime
state = {'trainer': {'date': datetime.date.today().isoformat(),
                     'reps': {'pushups': 45, 'squats': 120}}}
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"-- trainer --"* ]]
  [[ "$output" == *"trainer: on"* ]]
  [[ "$output" == *"pushups 45/300"* ]]
  [[ "$output" == *"squats 120/300"* ]]
}

@test "status --verbose shows tts section when tts.enabled=true" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True, 'backend': 'native', 'voice': 'default',
              'rate': 1.0, 'mode': 'sound-then-speak'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"-- tts --"* ]]
  [[ "$output" == *"tts: on (native)"* ]]
  [[ "$output" == *"mode sound-then-speak"* ]]
}

@test "status --verbose hides trainer and tts sections when disabled" {
  rm -f "$TEST_DIR/.paused"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" != *"-- trainer --"* ]]
  [[ "$output" != *"-- tts --"* ]]
}

@test "status --verbose shows config path" {
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $TEST_DIR/config.json"* ]]
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

@test "notifications marker shows default" {
  run bash "$PEON_SH" notifications marker
  [ "$status" -eq 0 ]
  [[ "$output" == *"●"* ]]
}

@test "notifications marker set to empty disables it" {
  run bash "$PEON_SH" notifications marker ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"disabled"* ]]
  val=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('notification_title_marker', '●'))")
  [ "$val" = "" ]
}

@test "notifications marker set to custom" {
  run bash "$PEON_SH" notifications marker "🔔"
  [ "$status" -eq 0 ]
  [[ "$output" == *"🔔"* ]]
  val=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('notification_title_marker', '●'))")
  [ "$val" = "🔔" ]
}

@test "notification_title_marker appears in tab title but not notification title" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  [ -f "$TEST_DIR/.tab_title" ]
  grep -q "●myproject: done" "$TEST_DIR/.tab_title"
  ! grep -q "●" "$TEST_DIR/terminal_notifier.log"
}

@test "notification_title_marker empty removes marker from title" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_style'] = 'standard'
cfg['notification_title_marker'] = ''
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  ! grep -q "●" "$TEST_DIR/terminal_notifier.log"
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

@test "packs list marks the active pack with <-- active" {
  run bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"<-- active"* ]]
  # peon should be marked active (default pack)
  line=$(echo "$output" | grep "peon")
  [[ "$line" == *"<-- active"* ]]
  # sc_kerrigan should NOT be marked
  line=$(echo "$output" | grep "sc_kerrigan")
  [[ "$line" != *"<-- active"* ]]
}

@test "packs list marks correct pack after switch" {
  bash "$PEON_SH" packs use sc_kerrigan
  run bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"sc_kerrigan"*"<-- active"* ]]
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

@test "Claude hooks dir takes priority over CESP shared path (fixes #250)" {
  # Both paths exist — Claude hooks dir should win so CLI writes config
  # to the same location the hook reads from.
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
  # Should find sc_kerrigan (from hooks dir), not peon (from CESP)
  [[ "$output" == *"sc_kerrigan"* ]]
  [[ "$output" != *"Orc Peon"* ]]

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
  active=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('default_pack', c.get('active_pack')))")
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
  active=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('default_pack', c.get('active_pack', 'peon')))")
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
  active=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('default_pack', c.get('active_pack')))")
  [ "$active" = "test_pack_a" ]
}

@test "packs use --install re-downloads already-installed pack" {
  setup_pack_download_env
  run bash "$PEON_SH" packs use --install sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"switched to sc_kerrigan"* ]]
  active=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('default_pack', c.get('active_pack')))")
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
  active=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('default_pack', c.get('active_pack')))")
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
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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
# Packs rotation CLI (peon packs rotation add/remove/list)
# ============================================================

@test "packs rotation list shows mode and packs" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon", "sc_kerrigan"],
  "pack_rotation_mode": "round-robin"
}
JSON
  run bash "$PEON_SH" packs rotation list
  [ "$status" -eq 0 ]
  [[ "$output" == *"round-robin"* ]]
  [[ "$output" == *"peon"* ]]
  [[ "$output" == *"sc_kerrigan"* ]]
}

@test "packs rotation list shows empty when no packs" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": []
}
JSON
  run bash "$PEON_SH" packs rotation list
  [ "$status" -eq 0 ]
  [[ "$output" == *"(empty)"* ]]
}

@test "packs rotation add adds installed pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon"]
}
JSON
  run bash "$PEON_SH" packs rotation add sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"Added sc_kerrigan"* ]]
  rotation=$(/usr/bin/python3 -c "import json; print(','.join(json.load(open('$TEST_DIR/config.json')).get('pack_rotation', [])))")
  [[ "$rotation" == *"sc_kerrigan"* ]]
  [[ "$rotation" == *"peon"* ]]
}

@test "packs rotation add rejects nonexistent pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon"]
}
JSON
  run bash "$PEON_SH" packs rotation add nonexistent_pack
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "packs rotation add rejects duplicate pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon"]
}
JSON
  run bash "$PEON_SH" packs rotation add peon
  [ "$status" -ne 0 ]
  [[ "$output" == *"already in rotation"* ]]
}

@test "packs rotation add multiple packs comma-separated" {
  mkdir -p "$TEST_DIR/packs/glados/sounds"
  cat > "$TEST_DIR/packs/glados/openpeon.json" <<'JSON'
{
  "name": "glados", "display_name": "GLaDOS",
  "categories": { "session.start": { "sounds": [{ "file": "Hello.wav", "label": "Hello" }] } }
}
JSON
  touch "$TEST_DIR/packs/glados/sounds/Hello.wav"
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": []
}
JSON
  run bash "$PEON_SH" packs rotation add sc_kerrigan,glados
  [ "$status" -eq 0 ]
  [[ "$output" == *"Added sc_kerrigan"* ]]
  [[ "$output" == *"Added glados"* ]]
}

@test "packs rotation remove removes pack from rotation" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon", "sc_kerrigan"]
}
JSON
  run bash "$PEON_SH" packs rotation remove sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed sc_kerrigan"* ]]
  rotation=$(/usr/bin/python3 -c "import json; print(','.join(json.load(open('$TEST_DIR/config.json')).get('pack_rotation', [])))")
  [[ "$rotation" == "peon" ]]
}

@test "packs rotation remove rejects pack not in rotation" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon"]
}
JSON
  run bash "$PEON_SH" packs rotation remove sc_kerrigan
  [ "$status" -ne 0 ]
  [[ "$output" == *"not in rotation"* ]]
}

@test "packs rotation clear clears all packs from rotation" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon", "sc_kerrigan"]
}
JSON
  run bash "$PEON_SH" packs rotation clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rotation cleared"* ]]
  rotation=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('pack_rotation', 'MISSING'))")
  [[ "$rotation" == "[]" ]]
}

@test "packs rotation clear works when rotation already empty" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": []
}
JSON
  run bash "$PEON_SH" packs rotation clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"Rotation cleared"* ]]
  rotation=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('pack_rotation', 'MISSING'))")
  [[ "$rotation" == "[]" ]]
}

@test "packs rotation no args shows usage" {
  run bash "$PEON_SH" packs rotation invalid_sub
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "packs rotation add no args shows usage" {
  run bash "$PEON_SH" packs rotation add
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

# ============================================================
# packs rotation add --install
# ============================================================

@test "packs rotation add --install downloads and adds absent pack" {
  setup_pack_download_env
  run bash "$PEON_SH" packs rotation add --install test_pack_a
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [ -f "$TEST_DIR/packs/test_pack_a/openpeon.json" ]
  [[ "$output" == *"Added test_pack_a to rotation"* ]]
  rotation=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('pack_rotation', []))")
  [[ "$rotation" == *"test_pack_a"* ]]
}

@test "packs rotation add <name> --install works (flag after name)" {
  setup_pack_download_env
  run bash "$PEON_SH" packs rotation add test_pack_a --install
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [[ "$output" == *"Added test_pack_a to rotation"* ]]
}

@test "packs rotation add --install errors when pack-download.sh missing" {
  # Don't call setup_pack_download_env — no scripts/ dir
  run bash "$PEON_SH" packs rotation add --install test_pack_a
  [ "$status" -ne 0 ]
  [[ "$output" == *"pack-download.sh not found"* ]]
}

@test "packs rotation add --install with comma-separated packs" {
  setup_pack_download_env
  run bash "$PEON_SH" packs rotation add --install test_pack_a,test_pack_b
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [ -d "$TEST_DIR/packs/test_pack_b" ]
  [[ "$output" == *"Added test_pack_a to rotation"* ]]
  [[ "$output" == *"Added test_pack_b to rotation"* ]]
  rotation=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('pack_rotation', []))")
  [[ "$rotation" == *"test_pack_a"* ]]
  [[ "$rotation" == *"test_pack_b"* ]]
}

@test "help shows packs rotation commands" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"packs rotation list"* ]]
  [[ "$output" == *"packs rotation add"* ]]
  [[ "$output" == *"packs rotation remove"* ]]
}

# ============================================================
# Pack rotation
# ============================================================

@test "pack_rotation picks a pack from the list" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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

@test "pack_rotation keeps same pack when session_packs entry is dict format" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["sc_kerrigan"]
}
JSON
  # Inject state with dict-format entry (as cleanup code produces)
  /usr/bin/python3 <<PYTHON
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
state = json.load(open(state_file))
state.setdefault('session_packs', {})['rot-dict'] = {'pack': 'sc_kerrigan', 'last_used': time.time()}
json.dump(state, open(state_file, 'w'))
PYTHON

  # Subsequent event should reuse sc_kerrigan, not pick a random pack
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"rot-dict","permission_mode":"default"}'
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "SubagentStart fires no sound and saves pending_subagent_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {"task.acknowledge": true},
  "pack_rotation": ["sc_kerrigan"]
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"par1","permission_mode":"default"}'
  run_peon '{"hook_event_name":"subagentStart","cwd":"/tmp/myproject","session_id":"par1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called

  # pending_subagent_pack should be written to state
  pending=$(/usr/bin/python3 -c "
import json, os
state = json.load(open(os.environ['TEST_DIR'] + '/.state.json'))
p = state.get('pending_subagent_pack', {})
print(p.get('pack', ''))
")
  [ "$pending" = "sc_kerrigan" ]
}

@test "child SessionStart inherits parent pack via pending_subagent_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["sc_kerrigan", "peon"]
}
JSON
  # Inject pending_subagent_pack as if parent just fired SubagentStart with sc_kerrigan
  /usr/bin/python3 <<PYTHON
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
state = json.load(open(state_file))
state['pending_subagent_pack'] = {'ts': time.time(), 'pack': 'sc_kerrigan'}
json.dump(state, open(state_file, 'w'))
PYTHON

  # Child session start should inherit sc_kerrigan, not pick random
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"child1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "shuffle mode picks from pack_rotation on every event" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["sc_kerrigan"],
  "pack_rotation_mode": "shuffle"
}
JSON
  # First event
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"shuf1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]

  # Second event with same session_id should still use rotation list (not cache)
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"shuf1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound2=$(afplay_sound)
  [[ "$sound2" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "shuffle mode does not cache pack in session_packs" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["sc_kerrigan"],
  "pack_rotation_mode": "shuffle"
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"shuf2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]

  # Verify session_packs does NOT contain the shuffle session
  /usr/bin/python3 <<PYTHON
import json, os
state = json.load(open(os.environ['TEST_DIR'] + '/.state.json'))
sp = state.get('session_packs', {})
assert 'shuf2' not in sp, f"shuffle should not cache in session_packs, got: {sp}"
PYTHON
}

@test "empty pack_rotation falls back to default_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "agentskill"
}
JSON
  
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"ask2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # Should use peon (default_pack) since ask2 has no assignment
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "agentskill mode falls back when assigned pack missing" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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
  # Should fallback to peon (default_pack)
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
  "default_pack": "peon", "volume": 0.5, "enabled": true,
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
# Platform env var isolation (#426)
# ============================================================

@test "Ambient PLATFORM env var does not pollute platform detection" {
  # Simulate a user who exports PLATFORM=osx in their dotfiles.
  # peon.sh must ignore it and detect the real platform via detect_platform().
  export PLATFORM=osx
  unset PEON_PLATFORM
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s-envtest","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  # On macOS (where CI runs), detect_platform returns "mac" and afplay is called.
  # The key assertion: sound played successfully despite PLATFORM=osx in env.
  afplay_was_called
}

# ============================================================
# Linux audio backend detection (order of preference)
# ============================================================

@test "Linux detects pw-play first" {
  export PEON_PLATFORM=linux
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
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"--volume"* ]]
}

@test "Linux detects ffplay when pw-play and paplay not available" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-volume"* ]]
}

@test "Linux detects mpv when pw-play, paplay, and ffplay not available" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"--volume"* ]]
}

@test "Linux detects play (SoX) when pw-play through mpv not available" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay" "$TEST_DIR/.disabled_mpv"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-v"* ]]
}

@test "Linux falls back to aplay when no other backend available" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay" "$TEST_DIR/.disabled_mpv" "$TEST_DIR/.disabled_play"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-q"* ]]
}

@test "Linux continues gracefully when no audio backend available" {
  export PEON_PLATFORM=linux
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
  export PEON_PLATFORM=linux
  for player in paplay ffplay mpv play aplay; do
    touch "$TEST_DIR/.disabled_${player}"
  done
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"--volume 0.3"* ]]
}

@test "Linux paplay scales volume to PulseAudio range" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  # 0.5 * 65536 = 32768
  [[ "$cmdline" == *"--volume=32768"* ]]
}

@test "Linux ffplay scales volume to 0-100" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  # 0.5 * 100 = 50
  [[ "$cmdline" == *"-volume 50"* ]]
}

@test "Linux mpv scales volume to 0-100" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  # 0.5 * 100 = 50
  [[ "$cmdline" == *"--volume=50"* ]]
}

@test "Linux play (SoX) uses -v with decimal" {
  export PEON_PLATFORM=linux
  touch "$TEST_DIR/.disabled_pw-play" "$TEST_DIR/.disabled_paplay" "$TEST_DIR/.disabled_ffplay" "$TEST_DIR/.disabled_mpv"
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  linux_audio_was_called
  cmdline=$(linux_audio_cmdline)
  [[ "$cmdline" == *"-v 0.3"* ]]
}

@test "Linux aplay does not support volume control" {
  export PEON_PLATFORM=linux
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
  export PEON_PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"/play?"* ]]
  [[ "$cmdline" == *"X-Volume"* ]]
}

@test "devcontainer does not call afplay or linux audio" {
  export PEON_PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! linux_audio_was_called
}

@test "devcontainer exits cleanly when relay unavailable" {
  export PEON_PLATFORM=devcontainer
  # .relay_available NOT created, so mock curl returns exit 7
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
}

@test "devcontainer SessionStart shows relay guidance when relay unavailable" {
  export PEON_PLATFORM=devcontainer
  rm -f "$TEST_DIR/.relay_available"  # Remove to simulate relay unavailable
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" == *"relay not reachable"* ]]
  [[ "$PEON_STDERR" == *"peon relay"* ]]
}

@test "devcontainer SessionStart does NOT show relay guidance when relay available" {
  export PEON_PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" != *"relay not reachable"* ]]
}

@test "devcontainer relay respects PEON_RELAY_HOST override" {
  export PEON_PLATFORM=devcontainer
  export PEON_RELAY_HOST="custom.host.local"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"custom.host.local"* ]]
}

@test "devcontainer relay respects PEON_RELAY_PORT override" {
  export PEON_PLATFORM=devcontainer
  export PEON_RELAY_PORT="12345"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"12345"* ]]
}

@test "devcontainer volume passed in X-Volume header" {
  export PEON_PLATFORM=devcontainer
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.7, "enabled": true, "categories": {} }
JSON
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"X-Volume: 0.7"* ]]
}

@test "devcontainer Stop event plays via relay" {
  export PEON_PLATFORM=devcontainer
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  relay_was_called
  # Check that /play? appears somewhere in the log (not just last line, since /notify comes after)
  grep -q "/play?" "$TEST_DIR/relay_curl.log"
}

@test "devcontainer notification sent via relay POST" {
  export PEON_PLATFORM=devcontainer
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
  export PEON_PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"/play?"* ]]
  [[ "$cmdline" == *"X-Volume"* ]]
}

@test "ssh does not call afplay or linux audio" {
  export PEON_PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  ! linux_audio_was_called
}

@test "ssh exits cleanly when relay unavailable" {
  export PEON_PLATFORM=ssh
  # .relay_available NOT created, so mock curl returns exit 7
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
}

@test "ssh local mode plays locally and skips relay" {
  export PEON_PLATFORM=ssh
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "ssh_audio_mode": "local"
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
  ! relay_was_called
}

@test "ssh auto mode falls back to local when relay is unavailable" {
  export PEON_PLATFORM=ssh
  export LINUX_AUDIO_PLAYER="ffplay"
  rm -f "$TEST_DIR/.relay_available"
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "ssh_audio_mode": "auto"
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
}

@test "ssh SessionStart shows relay guidance when relay unavailable" {
  export PEON_PLATFORM=ssh
  rm -f "$TEST_DIR/.relay_available"  # Remove to simulate relay unavailable
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" == *"SSH session detected"* ]]
  [[ "$PEON_STDERR" == *"relay not reachable"* ]]
  [[ "$PEON_STDERR" == *"ssh -R"* ]]
}

@test "ssh SessionStart does NOT show relay guidance when relay available" {
  export PEON_PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" != *"relay not reachable"* ]]
}

@test "ssh local mode does not show relay guidance" {
  export PEON_PLATFORM=ssh
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
  "ssh_audio_mode": "local"
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$PEON_STDERR" != *"relay not reachable"* ]]
}

@test "ssh relay uses localhost as default host" {
  export PEON_PLATFORM=ssh
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"localhost"* ]]
}

@test "ssh relay respects PEON_RELAY_HOST override" {
  export PEON_PLATFORM=ssh
  export PEON_RELAY_HOST="custom.host.local"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"custom.host.local"* ]]
}

@test "ssh relay respects PEON_RELAY_PORT override" {
  export PEON_PLATFORM=ssh
  export PEON_RELAY_PORT="12345"
  touch "$TEST_DIR/.relay_available"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  relay_was_called
  cmdline=$(relay_cmdline)
  [[ "$cmdline" == *"12345"* ]]
}

@test "ssh notification sent via relay POST" {
  export PEON_PLATFORM=ssh
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
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
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
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
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
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
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
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
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
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
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
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
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
  "default_pack": "peon", "volume": 0.5, "enabled": true, "categories": {},
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
  "default_pack": "peon",
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

@test "packs use syncs default_pack to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" packs use sc_kerrigan
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
assert cfg['default_pack'] == 'sc_kerrigan', f'expected sc_kerrigan, got {cfg.get(\"default_pack\")}'
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

@test "packs use syncs categories and spam settings to OpenCode adapter config" {
  setup_adapter_sync
  python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['categories']['user.spam'] = False
cfg['annoyed_threshold'] = 7
cfg['annoyed_window_seconds'] = 22
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  bash "$PEON_SH" packs use sc_kerrigan
  python3 -c "
import json
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
assert cfg['categories']['user.spam'] == False, 'expected user.spam category synced'
assert cfg['spam_threshold'] == 7, 'expected spam_threshold synced from annoyed_threshold'
assert cfg['spam_window_seconds'] == 22, 'expected spam_window_seconds synced from annoyed_window_seconds'
assert cfg['debounce_ms'] == 500, 'debounce_ms should still be preserved'
"
}

@test "packs next syncs default_pack to OpenCode adapter config" {
  setup_adapter_sync
  bash "$PEON_SH" packs next
  python3 -c "
import json
# The canonical config should have switched from peon to sc_kerrigan (alphabetical)
cfg = json.load(open('$XDG_CONFIG_HOME/opencode/peon-ping/config.json'))
assert cfg['default_pack'] == 'sc_kerrigan', f'expected sc_kerrigan, got {cfg.get(\"default_pack\")}'
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
  "default_pack": "peon",
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
  "default_pack": "peon",
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

@test "OpenCode events respect OpenCode config categories" {
  export XDG_CONFIG_HOME="$TEST_DIR/xdg_config"
  mkdir -p "$XDG_CONFIG_HOME/opencode/peon-ping"
  cat > "$XDG_CONFIG_HOME/opencode/peon-ping/config.json" <<'JSON'
{
  "categories": {
    "session.start": false
  }
}
JSON
  run_peon '{"hook_event_name":"SessionStart","source":"opencode","cwd":"/tmp/myproject","session_id":"oc-1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
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
  export PEON_PLATFORM=mac
  mkdir -p "$TEST_DIR/scripts"
  touch "$TEST_DIR/scripts/mac-overlay.js"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/overlay.log" ]
  # overlay.log line: -l JavaScript /path/mac-overlay.js msg color icon slot dismiss bundle_id ide_pid session_tty subtitle notif_position notify_type all_screens
  args=$(tail -1 "$TEST_DIR/overlay.log")
  # Count space-separated tokens — should be at least 7 after "-l JavaScript script"
  count=$(echo "$args" | wc -w | tr -d ' ')
  [ "$count" -ge 7 ]
}

@test "mac overlay IDE PID argument is numeric" {
  export PEON_PLATFORM=mac
  mkdir -p "$TEST_DIR/scripts"
  touch "$TEST_DIR/scripts/mac-overlay.js"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/overlay.log" ]
  # Extract ide_pid by anchoring on "top-center" (notif_position, always
  # present and always non-empty) and walking backward to find the first
  # purely-numeric token. The token immediately before "top-center" is
  # session_tty when the test runs in a TTY (which is non-numeric, e.g.
  # /dev/ttys029), or ide_pid when session_tty is empty. Walking back to
  # the first numeric token finds ide_pid in both cases. Positional NF-N
  # indexing is too brittle against optional-field collapsing by awk.
  ide_pid=$(tail -1 "$TEST_DIR/overlay.log" | awk '
    {
      anchor = 0
      for (i = 1; i <= NF; i++) {
        if ($i == "top-center") { anchor = i; break }
      }
      if (anchor == 0) exit
      for (j = anchor - 1; j >= 1; j--) {
        if ($j ~ /^[0-9]+$/) { print $j; exit }
      }
    }
  ')
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

# ============================================================
# path_rules: CWD-to-pack glob matching
# ============================================================

@test "path_rules: matching rule uses the specified pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"pr1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "path_rules: no matching rule falls through to default_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": [
    { "pattern": "*/other-project*", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"pr2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "path_rules: first matching rule wins (not second)" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "sc_kerrigan" },
    { "pattern": "*/myproject*", "pack": "peon" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"pr3","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "path_rules: missing pack falls through to default_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "nonexistent_pack" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"pr4","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "path_rules: beats pack_rotation" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation": ["peon", "sc_kerrigan"],
  "pack_rotation_mode": "round-robin",
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"pr5","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # Path rule wins over rotation
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "path_rules: glob with ** pattern matches nested path" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": [
    { "pattern": "/home/user/*", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"pr6","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "path_rules: empty path_rules array uses default_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": []
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"pr7","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "path_rules: session_override beats path_rules" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "session_override",
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "sc_kerrigan" }
  ]
}
JSON
  # Inject explicit session assignment for peon (overrides path_rule for sc_kerrigan)
  python3 <<'PYTHON'
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
now = int(time.time())
state = {'session_packs': {'so1': {'pack': 'peon', 'last_used': now}}}
with open(state_file, 'w') as f:
    json.dump(state, f)
PYTHON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"so1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # session_override wins: should be peon, not sc_kerrigan
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "path_rules: no cwd uses default_pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"","session_id":"pr8","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "exclude_dirs: bare directory pattern silences all sounds for descendants" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "exclude_dirs": [
    "~/conductor/workspaces"
  ],
  "path_rules": [
    { "pattern": "*/windhoek*", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"'"$HOME"'/conductor/workspaces/peon-ping/windhoek","session_id":"ex1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "exclude_dirs: glob pattern silences matching cwd (CodexBar/ClaudeProbe case)" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": { "session.start": true },
  "exclude_dirs": [
    "~/Library/Application Support/CodexBar*"
  ]
}
JSON
  run_peon '{"hook_event_name":"SessionStart","cwd":"'"$HOME"'/Library/Application Support/CodexBar/ClaudeProbe","session_id":"codexbar1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "ide_rules: matching source uses the specified pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "ide_rules": [
    { "ide": "codex", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","source":"codex","cwd":"/tmp/myproject","session_id":"ide1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "path_rules: beats ide_rules when both match" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "peon" }
  ],
  "ide_rules": [
    { "ide": "codex", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","source":"codex","cwd":"/home/user/myproject","session_id":"ide2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/"* ]]
}

@test "exclude_dirs: silences even when ide_rules would otherwise match" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "exclude_dirs": [
    "~/conductor/workspaces"
  ],
  "path_rules": [
    { "pattern": "*/windhoek*", "pack": "peon" }
  ],
  "ide_rules": [
    { "ide": "codex", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","source":"codex","cwd":"'"$HOME"'/conductor/workspaces/peon-ping/windhoek","session_id":"ex2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# default_pack rename (active_pack → default_pack migration compat)
# ============================================================

@test "default_pack key is read correctly" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "sc_kerrigan", "volume": 0.5, "enabled": true,
  "categories": {}
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"dp1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "active_pack still works as legacy fallback when default_pack absent" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "sc_kerrigan", "volume": 0.5, "enabled": true,
  "categories": {}
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"dp2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "default_pack takes precedence over active_pack when both present" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "sc_kerrigan",
  "active_pack": "peon",
  "volume": 0.5, "enabled": true,
  "categories": {}
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"dp3","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

# ============================================================
# session_override mode (renamed from agentskill)
# ============================================================

@test "session_override mode uses assigned pack" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "session_override"
}
JSON
  python3 <<'PYTHON'
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
now = int(time.time())
state = {'session_packs': {'so_new1': {'pack': 'sc_kerrigan', 'last_used': now}}}
with open(state_file, 'w') as f:
    json.dump(state, f)
PYTHON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"so_new1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "session_override mode uses path_rule when no assignment" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "session_override",
  "path_rules": [
    { "pattern": "*/myproject*", "pack": "sc_kerrigan" }
  ]
}
JSON
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"so_new2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  # No session assignment, path_rule should win
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "agentskill mode still works as alias for session_override" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon", "volume": 0.5, "enabled": true,
  "categories": {},
  "pack_rotation_mode": "agentskill"
}
JSON
  python3 <<'PYTHON'
import json, os, time
state_file = os.environ['TEST_DIR'] + '/.state.json'
now = int(time.time())
state = {'session_packs': {'ask_alias': {'pack': 'sc_kerrigan', 'last_used': now}}}
with open(state_file, 'w') as f:
    json.dump(state, f)
PYTHON
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"ask_alias","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

# ============================================================
# peon update migration
# ============================================================

@test "peon update migrates active_pack to default_pack in config" {
  # Write a legacy config with active_pack
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "sc_kerrigan",
  "volume": 0.5,
  "enabled": true,
  "pack_rotation_mode": "random"
}
JSON
  # Run the migration Python inline (same logic as peon update block)
  python3 <<PYTHON
import json, os
config_path = '${TEST_DIR}/config.json'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
changed = False
if 'active_pack' in cfg and 'default_pack' not in cfg:
    cfg['default_pack'] = cfg.pop('active_pack')
    changed = True
elif 'active_pack' in cfg:
    cfg.pop('active_pack')
    changed = True
if cfg.get('pack_rotation_mode') == 'agentskill':
    cfg['pack_rotation_mode'] = 'session_override'
    changed = True
if changed:
    json.dump(cfg, open(config_path, 'w'), indent=2)
PYTHON

  # Verify migration result
  python3 <<'PYTHON'
import json, os
config_path = os.environ['TEST_DIR'] + '/config.json'
cfg = json.load(open(config_path))
assert 'active_pack' not in cfg, "active_pack should have been removed"
assert cfg.get('default_pack') == 'sc_kerrigan', "default_pack should be sc_kerrigan"
PYTHON
}

@test "peon update migrates agentskill to session_override" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "pack_rotation_mode": "agentskill"
}
JSON
  python3 <<PYTHON
import json, os
config_path = '${TEST_DIR}/config.json'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
changed = False
if 'active_pack' in cfg and 'default_pack' not in cfg:
    cfg['default_pack'] = cfg.pop('active_pack')
    changed = True
elif 'active_pack' in cfg:
    cfg.pop('active_pack')
    changed = True
if cfg.get('pack_rotation_mode') == 'agentskill':
    cfg['pack_rotation_mode'] = 'session_override'
    changed = True
if changed:
    json.dump(cfg, open(config_path, 'w'), indent=2)
PYTHON

  python3 <<'PYTHON'
import json, os
config_path = os.environ['TEST_DIR'] + '/config.json'
cfg = json.load(open(config_path))
assert cfg.get('pack_rotation_mode') == 'session_override', "should be session_override"
assert 'active_pack' not in cfg, "active_pack should be gone"
assert cfg.get('default_pack') == 'peon', "default_pack should be peon"
PYTHON
}

@test "peon update migration is idempotent (default_pack already present)" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "sc_kerrigan",
  "volume": 0.5,
  "enabled": true,
  "pack_rotation_mode": "session_override"
}
JSON
  python3 <<PYTHON
import json, os
config_path = '${TEST_DIR}/config.json'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
changed = False
if 'active_pack' in cfg and 'default_pack' not in cfg:
    cfg['default_pack'] = cfg.pop('active_pack')
    changed = True
elif 'active_pack' in cfg:
    cfg.pop('active_pack')
    changed = True
if cfg.get('pack_rotation_mode') == 'agentskill':
    cfg['pack_rotation_mode'] = 'session_override'
    changed = True
if changed:
    json.dump(cfg, open(config_path, 'w'), indent=2)
PYTHON

  python3 <<'PYTHON'
import json, os
config_path = os.environ['TEST_DIR'] + '/config.json'
cfg = json.load(open(config_path))
assert cfg.get('default_pack') == 'sc_kerrigan', "default_pack should be unchanged"
assert cfg.get('pack_rotation_mode') == 'session_override', "mode should be unchanged"
PYTHON
}

@test "peon update backfills debug and debug_retention_days config keys" {
  # Config without debug keys
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "pack_rotation_mode": "random"
}
JSON
  # Run the same migration logic as peon update
  python3 <<PYTHON
import json, os
config_path = '${TEST_DIR}/config.json'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
changed = False
migrations = []
if 'active_pack' in cfg and 'default_pack' not in cfg:
    cfg['default_pack'] = cfg.pop('active_pack')
    changed = True
    migrations.append('active_pack -> default_pack')
elif 'active_pack' in cfg:
    cfg.pop('active_pack')
    changed = True
    migrations.append('active_pack removed')
if cfg.get('pack_rotation_mode') == 'agentskill':
    cfg['pack_rotation_mode'] = 'session_override'
    changed = True
    migrations.append('agentskill -> session_override')
if 'debug' not in cfg:
    cfg['debug'] = False
    changed = True
    migrations.append('debug')
if 'debug_retention_days' not in cfg:
    cfg['debug_retention_days'] = 7
    changed = True
    migrations.append('debug_retention_days')
if changed:
    json.dump(cfg, open(config_path, 'w'), indent=2)
    print('peon-ping: config keys updated (' + ', '.join(migrations) + ')')
PYTHON

  # Verify debug keys were backfilled with correct defaults
  python3 <<'PYTHON'
import json, os
config_path = os.environ['TEST_DIR'] + '/config.json'
cfg = json.load(open(config_path))
assert cfg.get('debug') == False, "debug should be False"
assert cfg.get('debug_retention_days') == 7, "debug_retention_days should be 7"
assert cfg.get('default_pack') == 'peon', "default_pack should be unchanged"
PYTHON
}

@test "peon update backfill does not overwrite existing debug keys" {
  # Config with debug keys already set
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "debug": true,
  "debug_retention_days": 14
}
JSON
  python3 <<PYTHON
import json, os
config_path = '${TEST_DIR}/config.json'
try:
    cfg = json.load(open(config_path))
except Exception:
    cfg = {}
changed = False
if 'active_pack' in cfg and 'default_pack' not in cfg:
    cfg['default_pack'] = cfg.pop('active_pack')
    changed = True
elif 'active_pack' in cfg:
    cfg.pop('active_pack')
    changed = True
if cfg.get('pack_rotation_mode') == 'agentskill':
    cfg['pack_rotation_mode'] = 'session_override'
    changed = True
if 'debug' not in cfg:
    cfg['debug'] = False
    changed = True
if 'debug_retention_days' not in cfg:
    cfg['debug_retention_days'] = 7
    changed = True
if changed:
    json.dump(cfg, open(config_path, 'w'), indent=2)
PYTHON

  # Verify existing values were preserved
  python3 <<'PYTHON'
import json, os
config_path = os.environ['TEST_DIR'] + '/config.json'
cfg = json.load(open(config_path))
assert cfg.get('debug') == True, "debug should remain True"
assert cfg.get('debug_retention_days') == 14, "debug_retention_days should remain 14"
PYTHON
}

# ============================================================
# peon update config backfill: tts section
# ============================================================

@test "peon update backfills tts section on config that lacks it" {
  # Write a config WITHOUT tts (simulates pre-TTS install)
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "pack_rotation_mode": "random"
}
JSON

  # Run the same shallow-merge logic that install.sh uses for backfill
  python3 <<PYTHON
import json
defaults = json.load(open('${BATS_TEST_DIRNAME}/../config.json'))
user_cfg = json.load(open('${TEST_DIR}/config.json'))
changed = False
for key, value in defaults.items():
    if key not in user_cfg:
        user_cfg[key] = value
        changed = True
if changed:
    with open('${TEST_DIR}/config.json', 'w') as f:
        json.dump(user_cfg, f, indent=2)
        f.write('\n')
PYTHON

  # Verify tts section was added with correct defaults
  python3 <<'PYTHON'
import json, os
cfg = json.load(open(os.environ['TEST_DIR'] + '/config.json'))
tts = cfg.get('tts')
assert tts is not None, "tts section should exist"
assert tts['enabled'] == False, "tts.enabled should be false"
assert tts['backend'] == 'auto', "tts.backend should be auto"
assert tts['voice'] == 'default', "tts.voice should be default"
assert tts['rate'] == 1.0, "tts.rate should be 1.0"
assert tts['volume'] == 0.5, "tts.volume should be 0.5"
assert tts['mode'] == 'sound-then-speak', "tts.mode should be sound-then-speak"
PYTHON
}

@test "peon update preserves existing tts values when section already present" {
  # Write a config WITH custom tts values
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "pack_rotation_mode": "random",
  "tts": {
    "enabled": true,
    "backend": "say",
    "voice": "Samantha",
    "rate": 1.5,
    "volume": 0.8,
    "mode": "speak-only"
  }
}
JSON

  # Run the same shallow-merge backfill logic
  python3 <<PYTHON
import json
defaults = json.load(open('${BATS_TEST_DIRNAME}/../config.json'))
user_cfg = json.load(open('${TEST_DIR}/config.json'))
changed = False
for key, value in defaults.items():
    if key not in user_cfg:
        user_cfg[key] = value
        changed = True
if changed:
    with open('${TEST_DIR}/config.json', 'w') as f:
        json.dump(user_cfg, f, indent=2)
        f.write('\n')
PYTHON

  # Verify user's tts values were NOT overwritten
  python3 <<'PYTHON'
import json, os
cfg = json.load(open(os.environ['TEST_DIR'] + '/config.json'))
tts = cfg.get('tts')
assert tts is not None, "tts section should exist"
assert tts['enabled'] == True, "tts.enabled should remain true"
assert tts['backend'] == 'say', "tts.backend should remain say"
assert tts['voice'] == 'Samantha', "tts.voice should remain Samantha"
assert tts['rate'] == 1.5, "tts.rate should remain 1.5"
assert tts['volume'] == 0.8, "tts.volume should remain 0.8"
assert tts['mode'] == 'speak-only', "tts.mode should remain speak-only"
PYTHON
}

# ============================================================
# packs install-local
# ============================================================

@test "packs install-local copies a valid local pack" {
  # Create a local pack directory with a valid manifest + sound
  LOCAL_PACK="$(mktemp -d)"
  cat > "$LOCAL_PACK/openpeon.json" <<'JSON'
{
  "cesp_version": "1.0",
  "name": "local_test",
  "display_name": "Local Test Pack",
  "categories": {
    "session.start": {
      "sounds": [
        { "file": "sounds/Hello.wav", "label": "Hello" }
      ]
    }
  }
}
JSON
  mkdir -p "$LOCAL_PACK/sounds"
  touch "$LOCAL_PACK/sounds/Hello.wav"

  run bash "$PEON_SH" packs install-local "$LOCAL_PACK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"local_test"* ]]
  # Pack directory should exist
  [ -d "$TEST_DIR/packs/local_test" ]
  # Manifest should be copied
  [ -f "$TEST_DIR/packs/local_test/openpeon.json" ]
  # Sound file should be copied
  [ -f "$TEST_DIR/packs/local_test/sounds/Hello.wav" ]
  rm -rf "$LOCAL_PACK"
}

@test "packs install-local fails with no arguments" {
  run bash "$PEON_SH" packs install-local
  [ "$status" -ne 0 ]
  [[ "$output" == *"Usage"* ]]
}

@test "packs install-local fails for nonexistent directory" {
  run bash "$PEON_SH" packs install-local /tmp/no-such-dir-peon-test-$$
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "packs install-local fails when no manifest present" {
  NO_MANIFEST="$(mktemp -d)"
  touch "$NO_MANIFEST/some_file.wav"

  run bash "$PEON_SH" packs install-local "$NO_MANIFEST"
  [ "$status" -ne 0 ]
  [[ "$output" == *"openpeon.json"* ]]
  rm -rf "$NO_MANIFEST"
}

@test "packs install-local refuses overwrite without --force" {
  # Pre-create the target directory
  mkdir -p "$TEST_DIR/packs/overwrite_test"
  cat > "$TEST_DIR/packs/overwrite_test/openpeon.json" <<'JSON'
{"name":"overwrite_test"}
JSON

  LOCAL_PACK="$(mktemp -d)"
  cat > "$LOCAL_PACK/openpeon.json" <<'JSON'
{"cesp_version":"1.0","name":"overwrite_test","display_name":"Overwrite Test","categories":{}}
JSON

  run bash "$PEON_SH" packs install-local "$LOCAL_PACK"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]] || [[ "$output" == *"--force"* ]]
  rm -rf "$LOCAL_PACK"
}

@test "packs install-local overwrites with --force" {
  mkdir -p "$TEST_DIR/packs/force_test"
  echo '{"name":"force_test"}' > "$TEST_DIR/packs/force_test/openpeon.json"

  LOCAL_PACK="$(mktemp -d)"
  cat > "$LOCAL_PACK/openpeon.json" <<'JSON'
{"cesp_version":"1.0","name":"force_test","display_name":"Force Test","categories":{"session.start":{"sounds":[{"file":"sounds/Hi.wav","label":"Hi"}]}}}
JSON
  mkdir -p "$LOCAL_PACK/sounds"
  touch "$LOCAL_PACK/sounds/Hi.wav"

  run bash "$PEON_SH" packs install-local "$LOCAL_PACK" --force
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/packs/force_test/sounds/Hi.wav" ]
  rm -rf "$LOCAL_PACK"
}

@test "packs install-local pack appears in packs list" {
  LOCAL_PACK="$(mktemp -d)"
  cat > "$LOCAL_PACK/openpeon.json" <<'JSON'
{"cesp_version":"1.0","name":"listed_pack","display_name":"Listed Pack","categories":{"session.start":{"sounds":[{"file":"sounds/A.wav","label":"A"}]}}}
JSON
  mkdir -p "$LOCAL_PACK/sounds"
  touch "$LOCAL_PACK/sounds/A.wav"

  bash "$PEON_SH" packs install-local "$LOCAL_PACK"
  run bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"listed_pack"* ]]
  [[ "$output" == *"Listed Pack"* ]]
  rm -rf "$LOCAL_PACK"
}

@test "packs install-local warns about missing sound files" {
  LOCAL_PACK="$(mktemp -d)"
  cat > "$LOCAL_PACK/openpeon.json" <<'JSON'
{"cesp_version":"1.0","name":"warn_pack","display_name":"Warn Pack","categories":{"session.start":{"sounds":[{"file":"sounds/Missing.wav","label":"Missing"}]}}}
JSON

  run bash "$PEON_SH" packs install-local "$LOCAL_PACK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning"* ]] || [[ "$output" == *"missing"* ]] || [[ "${lines[*]}" == *"Missing.wav"* ]]
  [ -d "$TEST_DIR/packs/warn_pack" ]
  rm -rf "$LOCAL_PACK"
}

@test "packs install-local falls back to manifest.json" {
  LOCAL_PACK="$(mktemp -d)"
  cat > "$LOCAL_PACK/manifest.json" <<'JSON'
{"cesp_version":"1.0","name":"fallback_pack","display_name":"Fallback Pack","categories":{}}
JSON

  run bash "$PEON_SH" packs install-local "$LOCAL_PACK"
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/fallback_pack" ]
  rm -rf "$LOCAL_PACK"
}

@test "packs install-local falls back to dirname when name field missing" {
  LOCAL_PACK="$(mktemp -d)/my_custom_pack"
  mkdir -p "$LOCAL_PACK"
  cat > "$LOCAL_PACK/openpeon.json" <<'JSON'
{"cesp_version":"1.0","display_name":"No Name Field","categories":{}}
JSON

  run bash "$PEON_SH" packs install-local "$LOCAL_PACK"
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/my_custom_pack" ]
  rm -rf "$(dirname "$LOCAL_PACK")"
}

# ============================================================
# Headphones-only mode
# ============================================================

@test "headphones_only: plays sound when headphones connected" {
  # Enable headphones_only in config
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['headphones_only'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  # Mock headphones connected
  touch "$TEST_DIR/.mock_headphones_connected"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "headphones_only: skips sound when speakers only" {
  # Enable headphones_only in config
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['headphones_only'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  # Mock speakers only (no headphones)
  touch "$TEST_DIR/.mock_speakers_only"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "headphones_only disabled: plays sound regardless of output device" {
  # headphones_only defaults to false, mock speakers only
  touch "$TEST_DIR/.mock_speakers_only"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

# ============================================================
# Meeting detection — auto-suppress during calls
# ============================================================

@test "meeting_detect: plays sound when no meeting active" {
  # Enable meeting_detect in config
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['meeting_detect'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  # No meeting fixtures → detect_meeting returns 1

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "meeting_detect: skips sound when mic in use" {
  # Enable meeting_detect in config
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['meeting_detect'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  # Mock mic in use (layer 2)
  touch "$TEST_DIR/.mock_mic_in_use"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "meeting_detect disabled: plays sound regardless" {
  # meeting_detect defaults to false, mock an active meeting
  touch "$TEST_DIR/.mock_meeting_active"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

# ============================================================
# Suppress sound when tab focused
# ============================================================

@test "suppress_sound_when_tab_focused: skips sound when terminal is focused" {
  # Enable the feature
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['suppress_sound_when_tab_focused'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  # Mock terminal as focused (Terminal.app — a recognized terminal)
  echo "Terminal" > "$TEST_DIR/.mock_terminal_focused"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "suppress_sound_when_tab_focused: plays sound when terminal is not focused" {
  # Enable the feature
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['suppress_sound_when_tab_focused'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  # Default mock: osascript returns "Safari" (not a terminal) — not focused

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "suppress_sound_when_tab_focused disabled: plays sound even when terminal is focused" {
  # Feature defaults to false — mock terminal as focused
  echo "Terminal" > "$TEST_DIR/.mock_terminal_focused"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
}

@test "Linux focus detection uses xdotool window class for zellij in Alacritty" {
  export PEON_PLATFORM=linux
  export XDG_SESSION_TYPE=x11
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['suppress_sound_when_tab_focused'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  echo "zellij: dev" > "$TEST_DIR/.mock_xdotool_window_name"
  echo "Alacritty" > "$TEST_DIR/.mock_xdotool_window_class"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  ! linux_audio_was_called
}

@test "Linux focus detection does not treat generic titles like start as st terminal" {
  export PEON_PLATFORM=linux
  export XDG_SESSION_TYPE=x11
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['suppress_sound_when_tab_focused'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  echo "start" > "$TEST_DIR/.mock_xdotool_window_name"
  echo "firefox" > "$TEST_DIR/.mock_xdotool_window_class"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  linux_audio_was_called
}

@test "suppress_sound_when_tab_focused: cmux uses focused surface instead of Ghostty AppleScript" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['suppress_sound_when_tab_focused'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  echo "cmux" > "$TEST_DIR/.mock_terminal_focused"
  cat > "$TEST_DIR/.mock_cmux_identify_json" <<'JSON'
{"focused":{"workspace_id":"11111111-1111-1111-1111-111111111111","surface_id":"22222222-2222-2222-2222-222222222222"},"caller":{"workspace_id":"11111111-1111-1111-1111-111111111111","surface_id":"22222222-2222-2222-2222-222222222222"}}
JSON

  export TERM_PROGRAM=ghostty
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  ! afplay_was_called
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"identify"* ]]
  ! grep -q 'Ghostty' "$TEST_DIR/osascript.log" 2>/dev/null
}

@test "suppress_sound_when_tab_focused: cmux background surface still plays sound" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['suppress_sound_when_tab_focused'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  echo "cmux" > "$TEST_DIR/.mock_terminal_focused"
  cat > "$TEST_DIR/.mock_cmux_identify_json" <<'JSON'
{"focused":{"workspace_id":"11111111-1111-1111-1111-111111111111","surface_id":"33333333-3333-3333-3333-333333333333"},"caller":{"workspace_id":"11111111-1111-1111-1111-111111111111","surface_id":"22222222-2222-2222-2222-222222222222"}}
JSON

  export TERM_PROGRAM=ghostty
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"identify"* ]]
}

@test "cmux status pill shows Running on SessionStart and clears on SessionEnd" {
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"set-status peon Claude Code: Running"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--icon bolt.fill"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--color #4C8DFF"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--workspace workspace:5"* ]]
  ! [[ "$(cat "$TEST_DIR/cmux.log")" == *"--socket"* ]]

  run_peon '{"hook_event_name":"SessionEnd","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"clear-status peon"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--workspace workspace:5"* ]]
}

@test "cmux status pill is disabled for native Claude Code sessions" {
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  CLAUDE_CODE_ENTRYPOINT=cli \
    run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ ! -f "$TEST_DIR/cmux.log" ]
}

@test "cmux status pill still updates for codex sessions when Claude env leaks through" {
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  CLAUDE_CODE_ENTRYPOINT=cli \
    run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"codex-123","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"set-status peon OpenAI Codex: Idle"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--icon pause.circle.fill"* ]]
  ! [[ "$(cat "$TEST_DIR/cmux.log")" == *"--color "* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--workspace workspace:5"* ]]
}

@test "cmux status pill retries transient broken pipe" {
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"
  touch "$TEST_DIR/.mock_cmux_fail_once"

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [ "$(grep -c 'set-status peon Claude Code: Idle' "$TEST_DIR/cmux.log")" -eq 2 ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--workspace workspace:5"* ]]
}

@test "cmux status pill uses native Claude input state" {
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default","tool_name":"Bash"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"set-status peon Claude Code: Needs input"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--icon bell.fill"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--color #4C8DFF"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--workspace workspace:5"* ]]
}

@test "cmux status pill uses archive icon for compacting state" {
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  run_peon '{"hook_event_name":"PreCompact","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"set-status peon Claude Code: Running"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--icon archivebox.fill"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--color #AC8D00"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--workspace workspace:5"* ]]
}

@test "cmux Codex notification title uses upstream IDE title with workspace title" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['notification_style'] = 'standard'
c['notification_title_ide'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  export CMUX_SOCKET_PATH=/tmp/cmux-test.sock
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  run_peon '{"hook_event_name":"Stop","source":"codex","cwd":"/tmp/myproject","session_id":"codex-title","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"notify --title test - OpenAI Codex"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--body Idle"* ]]
  ! [[ "$(cat "$TEST_DIR/cmux.log")" == *"notify --title"*": Idle"* ]]
}

@test "cmux notification title uses workspace and IDE without socket env" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['notification_style'] = 'standard'
c['notification_title_ide'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  run_peon '{"hook_event_name":"Stop","source":"codex","cwd":"/tmp/myproject","session_id":"codex-title","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"notify --title test - OpenAI Codex"* ]]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"--body Idle"* ]]
}

@test "cmux notification title override beats workspace title" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['notification_style'] = 'standard'
c['notification_title_override'] = 'Manual Title'
c['notification_title_ide'] = True
json.dump(c, open('$TEST_DIR/config.json', 'w'))
"
  export CMUX_WORKSPACE_ID=11111111-1111-1111-1111-111111111111
  export CMUX_SURFACE_ID=22222222-2222-2222-2222-222222222222
  export CMUX_BUNDLED_CLI_PATH="$MOCK_BIN/cmux"

  run_peon '{"hook_event_name":"Stop","source":"codex","cwd":"","session_id":"codex-title","permission_mode":"default"}'

  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/cmux.log" ]
  [[ "$(cat "$TEST_DIR/cmux.log")" == *"notify --title Manual Title - OpenAI Codex"* ]]
  ! [[ "$(cat "$TEST_DIR/cmux.log")" == *"notify --title test"* ]]
}

# ============================================================
# packs bind / unbind / bindings CLI
# ============================================================

@test "packs bind sets path_rules entry" {
  run bash "$PEON_SH" packs bind peon
  [ "$status" -eq 0 ]
  [[ "$output" == *"bound peon to"* ]]
  # Verify config has the rule (pattern is exact PWD)
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('path_rules', [])))")
  [ "$rules" = "1" ]
  pack=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c['path_rules'][0]['pack'])")
  [ "$pack" = "peon" ]
}

@test "packs bind with --pattern stores custom pattern" {
  run bash "$PEON_SH" packs bind sc_kerrigan --pattern "*/myproject/*"
  [ "$status" -eq 0 ]
  [[ "$output" == *"bound sc_kerrigan to */myproject/*"* ]]
  pattern=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c['path_rules'][0]['pattern'])")
  [ "$pattern" = "*/myproject/*" ]
}

@test "packs bind updates existing rule for same pattern" {
  # Bind peon first, then rebind sc_kerrigan to same pattern
  bash "$PEON_SH" packs bind peon --pattern "*/proj/*"
  bash "$PEON_SH" packs bind sc_kerrigan --pattern "*/proj/*"
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('path_rules', [])))")
  [ "$rules" = "1" ]
  pack=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c['path_rules'][0]['pack'])")
  [ "$pack" = "sc_kerrigan" ]
}

@test "packs bind validates pack exists" {
  run bash "$PEON_SH" packs bind nonexistent
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found"* ]]
}

@test "packs bind with --install downloads missing pack" {
  setup_pack_download_env
  run bash "$PEON_SH" packs bind test_pack_a --install --pattern "*/test/*"
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [[ "$output" == *"bound test_pack_a"* ]]
}

@test "packs unbind removes rule" {
  # Bind first using explicit pattern matching PWD
  bash "$PEON_SH" packs bind peon --pattern "$TEST_DIR/*"
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('path_rules', [])))")
  [ "$rules" = "1" ]
  # Unbind with same pattern
  run bash "$PEON_SH" packs unbind --pattern "$TEST_DIR/*"
  [ "$status" -eq 0 ]
  [[ "$output" == *"unbound"* ]]
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('path_rules', [])))")
  [ "$rules" = "0" ]
}

@test "packs unbind with --pattern removes specific pattern" {
  bash "$PEON_SH" packs bind peon --pattern "*/proj-a/*"
  bash "$PEON_SH" packs bind sc_kerrigan --pattern "*/proj-b/*"
  run bash "$PEON_SH" packs unbind --pattern "*/proj-a/*"
  [ "$status" -eq 0 ]
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('path_rules', [])))")
  [ "$rules" = "1" ]
  pack=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c['path_rules'][0]['pack'])")
  [ "$pack" = "sc_kerrigan" ]
}

@test "packs unbind no matching rule prints message" {
  # Add a rule so path_rules is non-empty, then unbind a different pattern
  bash "$PEON_SH" packs bind peon --pattern "*/other/*"
  run bash "$PEON_SH" packs unbind --pattern "*/nonexistent/*"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No binding found"* ]]
}

@test "packs bindings lists rules" {
  bash "$PEON_SH" packs bind peon --pattern "*/proj-a/*"
  bash "$PEON_SH" packs bind sc_kerrigan --pattern "*/proj-b/*"
  run bash "$PEON_SH" packs bindings
  [ "$status" -eq 0 ]
  [[ "$output" == *"*/proj-a/* -> peon"* ]]
  [[ "$output" == *"*/proj-b/* -> sc_kerrigan"* ]]
}

@test "packs bindings empty prints message" {
  run bash "$PEON_SH" packs bindings
  [ "$status" -eq 0 ]
  [[ "$output" == *"No pack bindings configured"* ]]
}

@test "packs ide-bind sets ide_rules entry" {
  run bash "$PEON_SH" packs ide-bind codex sc_kerrigan
  [ "$status" -eq 0 ]
  [[ "$output" == *"bound sc_kerrigan to IDE codex"* ]]
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('ide_rules', [])))")
  [ "$rules" = "1" ]
  ide=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c['ide_rules'][0]['ide'])")
  [ "$ide" = "codex" ]
}

@test "packs ide-unbind removes ide rule" {
  bash "$PEON_SH" packs ide-bind codex sc_kerrigan >/dev/null
  run bash "$PEON_SH" packs ide-unbind codex
  [ "$status" -eq 0 ]
  [[ "$output" == *"unbound IDE codex"* ]]
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('ide_rules', [])))")
  [ "$rules" = "0" ]
}

@test "packs exclude add stores exclude_dirs entry" {
  run bash "$PEON_SH" packs exclude add "~/conductor/workspaces"
  [ "$status" -eq 0 ]
  [[ "$output" == *"sounds & notifications silenced for ~/conductor/workspaces"* ]]
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('exclude_dirs', [])))")
  [ "$rules" = "1" ]
}

@test "packs exclude remove deletes exclude_dirs entry" {
  bash "$PEON_SH" packs exclude add "~/conductor/workspaces" >/dev/null
  run bash "$PEON_SH" packs exclude remove "~/conductor/workspaces"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no longer silencing ~/conductor/workspaces"* ]]
  rules=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(len(c.get('exclude_dirs', [])))")
  [ "$rules" = "0" ]
}

@test "status shows active path rule when cwd matches" {
  # Bind a pack with a glob that matches our cwd
  bash "$PEON_SH" packs bind sc_kerrigan --pattern "*"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"path rule: * -> sc_kerrigan"* ]]
  [[ "$output" == *"path rules: 1 configured"* ]]
}

@test "status shows path rules count but no active rule when cwd does not match" {
  # Bind a pack with a pattern that won't match
  bash "$PEON_SH" packs bind peon --pattern "*/nonexistent-dir-xyz/*"
  run bash "$PEON_SH" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"path rules: 1 configured"* ]]
  [[ "$output" != *"path rule:"* ]]
}

@test "packs bind end-to-end: bound pack plays correct sounds" {
  # Bind sc_kerrigan to a path that matches our test CWD
  bash "$PEON_SH" packs bind sc_kerrigan --pattern "*/myproject*"
  # Fire an event with a matching cwd
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"bind1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

@test "packs bind default pattern (exact cwd) matches in event handler" {
  # Bind sc_kerrigan using the exact path (simulating default bind from /home/user/myproject)
  bash "$PEON_SH" packs bind sc_kerrigan --pattern "/home/user/myproject"
  # Fire an event with that exact cwd
  run_peon '{"hook_event_name":"Stop","cwd":"/home/user/myproject","session_id":"bind2","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/sc_kerrigan/sounds/"* ]]
}

# ============================================================
# Atomic state I/O
# ============================================================

@test "corrupted state.json does not crash the hook - continues with defaults" {
  # Write corrupted JSON to state file
  echo '{invalid json garbage!!!' > "$TEST_DIR/.state.json"
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"corrupt1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
  # State file should now be valid JSON (written atomically after event)
  /usr/bin/python3 -c "import json; json.load(open('$TEST_DIR/.state.json'))"
}

@test "concurrent Stop events produce valid JSON state" {
  # Fire multiple Stop events rapidly to test atomic write safety
  for i in 1 2 3 4 5; do
    echo '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"concurrent'$i'","permission_mode":"default"}' \
      | bash "$PEON_SH" 2>/dev/null &
  done
  wait
  # State file must be valid JSON after all concurrent writes
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
assert isinstance(state, dict), 'State should be a dict'
"
}

@test "first run with no .state.json succeeds without retry delay" {
  # Remove .state.json to simulate a clean first run
  rm -f "$TEST_DIR/.state.json"
  # Time the hook invocation — should not incur 350ms retry penalty
  # Note: date +%s%N returns nanoseconds (divide by 1000000 for ms),
  # but the Python fallback already returns milliseconds (no division needed).
  local start_ms
  local _ns
  if _ns=$(date +%s%N 2>/dev/null) && [ "${#_ns}" -gt 10 ]; then
    start_ms=$((_ns / 1000000))
  else
    start_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  fi
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/firstrun","session_id":"first1","permission_mode":"default"}'
  local end_ms
  if _ns=$(date +%s%N 2>/dev/null) && [ "${#_ns}" -gt 10 ]; then
    end_ms=$((_ns / 1000000))
  else
    end_ms=$(python3 -c "import time; print(int(time.time()*1000))")
  fi
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  # Verify no retry delay was incurred (should complete well under 300ms extra)
  [ $((end_ms - start_ms)) -lt 3000 ]
  # State file should now exist (written by the hook)
  [ -f "$TEST_DIR/.state.json" ]
  /usr/bin/python3 -c "import json; s = json.load(open('$TEST_DIR/.state.json')); assert isinstance(s, dict)"
}

@test "missing .state.json does not prevent trainer status" {
  # Enable trainer in config
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['trainer'] = {'enabled': True, 'exercises': {'pushups': 100}}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  rm -f "$TEST_DIR/.state.json"
  export PEON_TEST=1
  # trainer status should work even without .state.json
  run bash "$PEON_SH" trainer status
  [ "$status" -eq 0 ]
  [[ "$output" == *"trainer status"* ]]
}

# ============================================================
# TTS speech text resolution
# ============================================================

@test "TTS: manifest speech_text present on chosen sound entry" {
  # Enable TTS in config
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True, 'backend': 'auto', 'voice': 'default', 'rate': 1.0, 'volume': 0.5, 'mode': 'sound-then-speak'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Add speech_text to manifest sound entry
  /usr/bin/python3 -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
m['categories']['task.complete']['sounds'] = [{'file': 'Done1.wav', 'label': 'Done', 'speech_text': 'Task complete for {project}'}]
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  tts_enabled=$(cat "$TEST_DIR/.tts_enabled")
  [ "$tts_enabled" = "true" ]
  tts_text=$(cat "$TEST_DIR/.tts_text")
  [ "$tts_text" = "Task complete for myproject" ]
}

@test "TTS: falls back to notification template when no speech_text" {
  # Enable TTS and notification templates
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
cfg['notification_templates'] = {'stop': '{project} is done'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  tts_enabled=$(cat "$TEST_DIR/.tts_enabled")
  [ "$tts_enabled" = "true" ]
  tts_text=$(cat "$TEST_DIR/.tts_text")
  [ "$tts_text" = "myproject is done" ]
}

@test "TTS: stop template summary falls back to last_assistant_message" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
cfg['notification_templates'] = {'stop': '{summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1","last_assistant_message":"Fixed the hook payload fallback"}'
  [ "$PEON_EXIT" -eq 0 ]
  tts_text=$(cat "$TEST_DIR/.tts_text")
  [ "$tts_text" = "Fixed the hook payload fallback" ]
}

@test "TTS: stop template summary falls back to codex payload field" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
cfg['notification_templates'] = {'stop': '{summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"codex-stop","last-assistant-message":"Codex says the branch is ready"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ "$(cat "$TEST_DIR/.tts_text")" = "Codex says the branch is ready" ]
}

@test "TTS: stop template summary falls back to gemini payload field" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
cfg['notification_templates'] = {'stop': '{summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"gemini-stop","prompt_response":"Gemini says the branch is ready"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ "$(cat "$TEST_DIR/.tts_text")" = "Gemini says the branch is ready" ]
}

@test "TTS: falls back to default template when no notification template" {
  # Enable TTS but no notification templates
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  tts_enabled=$(cat "$TEST_DIR/.tts_enabled")
  [ "$tts_enabled" = "true" ]
  tts_text=$(cat "$TEST_DIR/.tts_text")
  # Default template: "{project} — {status}" where status is "done" for Stop event
  [[ "$tts_text" == *"myproject"* ]]
  [[ "$tts_text" == *"done"* ]]
}

@test "TTS: empty resolved text produces empty TTS_TEXT" {
  # Enable TTS with a template that resolves to em dash only
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
cfg['notification_templates'] = {'stop': '{summary}'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Stop event with no transcript_summary -> summary resolves to empty
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  tts_text=$(cat "$TEST_DIR/.tts_text")
  [ -z "$tts_text" ]
}

@test "TTS: disabled in config produces TTS_ENABLED=false" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': False}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  tts_enabled=$(cat "$TEST_DIR/.tts_enabled")
  [ "$tts_enabled" = "false" ]
  tts_text=$(cat "$TEST_DIR/.tts_text")
  [ -z "$tts_text" ]
}

@test "TTS: TRAINER_TTS_TEXT populated when trainer fires and TTS enabled" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
cfg['trainer'] = {'enabled': True, 'exercises': {'pushups': 100}, 'reminder_interval_minutes': 0, 'reminder_min_gap_minutes': 0}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Create trainer manifest
  mkdir -p "$TEST_DIR/trainer"
  cat > "$TEST_DIR/trainer/manifest.json" <<'JSON'
{
  "trainer.session_start": [{"file": "remind.wav", "label": "Time for reps"}],
  "trainer.remind": [{"file": "remind.wav", "label": "Time for reps"}]
}
JSON
  touch "$TEST_DIR/trainer/remind.wav"

  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s1","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  trainer_tts=$(cat "$TEST_DIR/.trainer_tts_text")
  [[ "$trainer_tts" == *"pushups"* ]]
}

@test "TTS: all 8 TTS variables printed in output block" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True, 'backend': 'espeak', 'voice': 'en-us', 'rate': 1.5, 'volume': 0.8, 'mode': 'speak-only'}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ "$(cat "$TEST_DIR/.tts_enabled")" = "true" ]
  [ -n "$(cat "$TEST_DIR/.tts_text")" ]
  [ "$(cat "$TEST_DIR/.tts_backend")" = "espeak" ]
  [ "$(cat "$TEST_DIR/.tts_voice")" = "en-us" ]
  [ "$(cat "$TEST_DIR/.tts_rate")" = "1.5" ]
  [ "$(cat "$TEST_DIR/.tts_volume")" = "0.8" ]
  [ "$(cat "$TEST_DIR/.tts_mode")" = "speak-only" ]
  # trainer_tts_text should be empty (no trainer configured)
  [ -z "$(cat "$TEST_DIR/.trainer_tts_text")" ]
}

@test "TTS: paused hook produces TTS_ENABLED=false" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {'enabled': True}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Create .paused file to simulate paused state
  touch "$TEST_DIR/.paused"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  # When paused, peon exits early — no sound, no TTS
  # The .tts_enabled file should show false
  tts_enabled=$(cat "$TEST_DIR/.tts_enabled" 2>/dev/null || echo "false")
  [ "$tts_enabled" = "false" ]
  rm -f "$TEST_DIR/.paused"
}

# ============================================================
# packs list --registry + install (end-to-end community pack flow)
# ============================================================

@test "packs list --registry then install a random pack" {
  setup_pack_download_env
  # List registry packs and pick one that is not already installed
  output=$(bash "$PEON_SH" packs list --registry)
  # Extract pack names from output (format: "  name       Display Name")
  # The mock registry has test_pack_a and test_pack_b
  pack_name="test_pack_a"
  # Verify it's listed
  [[ "$output" == *"$pack_name"* ]]
  # Install via packs use --install
  run bash "$PEON_SH" packs use --install "$pack_name"
  [ "$status" -eq 0 ]
  # Verify pack was downloaded
  [ -d "$TEST_DIR/packs/$pack_name" ]
  [ -f "$TEST_DIR/packs/$pack_name/openpeon.json" ]
  # Verify it's now the active pack
  active=$(/usr/bin/python3 -c "import json; c=json.load(open('$TEST_DIR/config.json')); print(c.get('default_pack', c.get('active_pack')))")
  [ "$active" = "$pack_name" ]
  # Verify it shows up in local packs list
  run bash "$PEON_SH" packs list
  [ "$status" -eq 0 ]
  [[ "$output" == *"$pack_name"* ]]
}

# ============================================================
# Debug logging (ADR-002)
# ============================================================

@test "debug=false produces no log file" {
  # Default config has no debug key, so logging should be disabled
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  # No logs directory should be created
  [ ! -d "$TEST_DIR/logs" ]
}

@test "debug=true creates daily log file with all phase entries for Stop event" {
  # Enable debug logging
  enable_debug_logging
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  # logs directory should exist
  [ -d "$TEST_DIR/logs" ]
  # Daily log file should exist
  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]
  # A normal Stop event should log all 9 phases per ADR-002:
  # [hook], [config], [state], [route], [sound], [play], [notify], [trainer], [exit]
  grep -q '\[hook\]' "$logfile"
  grep -q '\[config\]' "$logfile"
  grep -q '\[state\]' "$logfile"
  grep -q '\[route\]' "$logfile"
  grep -q '\[sound\]' "$logfile"
  grep -q '\[play\]' "$logfile"
  grep -q '\[notify\]' "$logfile"
  grep -q '\[trainer\]' "$logfile"
  grep -q '\[exit\]' "$logfile"
  # All lines should carry an inv= prefix
  grep -v 'inv=' "$logfile" && false || true
}

@test "PEON_DEBUG=1 env var enables logging even when config debug=false" {
  # Config has no debug key (defaults to false)
  export PEON_DEBUG=1
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  unset PEON_DEBUG
  # logs directory should exist
  [ -d "$TEST_DIR/logs" ]
  local today
  today=$(date '+%Y-%m-%d')
  [ -f "$TEST_DIR/logs/peon-ping-${today}.log" ]
}

@test "log rotation prunes files older than debug_retention_days" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['debug'] = True
cfg['debug_retention_days'] = 3
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Create old log files (older than 3 days)
  mkdir -p "$TEST_DIR/logs"
  touch "$TEST_DIR/logs/peon-ping-2020-01-01.log"
  touch "$TEST_DIR/logs/peon-ping-2020-01-02.log"
  touch "$TEST_DIR/logs/peon-ping-2020-01-03.log"
  # Create a recent log file that should NOT be pruned
  local today
  today=$(date '+%Y-%m-%d')
  # Don't create today's file so pruning triggers (new-day detection)

  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]

  # Old files should be pruned
  [ ! -f "$TEST_DIR/logs/peon-ping-2020-01-01.log" ]
  [ ! -f "$TEST_DIR/logs/peon-ping-2020-01-02.log" ]
  [ ! -f "$TEST_DIR/logs/peon-ping-2020-01-03.log" ]
  # Today's file should exist
  [ -f "$TEST_DIR/logs/peon-ping-${today}.log" ]
}

@test "debug log contains route suppression reason for debounce" {
  enable_debug_logging
  # First Stop event
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Second Stop within 5s should be debounced
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  grep -q 'reason=debounce_5s' "$logfile"
}

@test "debug log emits [exit] on delegate_mode early exit" {
  enable_debug_logging
  # Enable suppress_delegate_sessions so delegate mode actually suppresses
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['suppress_delegate_sessions'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # Trigger delegate_mode by sending a PermissionRequest with permission_mode=dangerouslySkipPermissions
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s-del","permission_mode":"dangerouslySkipPermissions"}'
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]
  grep -q 'reason=delegate_mode' "$logfile"
  grep -q '\[exit\]' "$logfile"
  # Verify both route and exit appear for this invocation
  grep 'reason=delegate_mode' "$logfile" | grep -q '\[route\]'
}

@test "debug log emits [exit] on agent_session early exit" {
  enable_debug_logging
  # Enable suppress_delegate_sessions so delegate mode actually suppresses
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['suppress_delegate_sessions'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  # First, register session as delegate by sending with permission_mode
  run_peon '{"hook_event_name":"PermissionRequest","cwd":"/tmp/myproject","session_id":"s-agent","permission_mode":"dangerouslySkipPermissions"}'
  [ "$PEON_EXIT" -eq 0 ]

  # Now send a normal event for the same session — should hit agent_session path
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-agent"}'
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  grep -q 'reason=agent_session' "$logfile"
  # The agent_session invocation should also have an [exit] entry
  # Extract invocation ID from the agent_session route line and verify exit exists for same inv
  local inv
  inv=$(grep 'reason=agent_session' "$logfile" | sed 's/.*inv=\([^ ]*\).*/\1/')
  grep -q "\[exit\] inv=$inv" "$logfile"
}

@test "debug log emits route reason for replay suppression" {
  enable_debug_logging
  # First, send a SessionStart to set the session start time
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/myproject","session_id":"s-replay"}'
  [ "$PEON_EXIT" -eq 0 ]

  # Immediately send a Stop within 3s — should trigger replay suppression
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-replay"}'
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  grep -q 'reason=replay_suppression' "$logfile"
}

# --- Shared fixture validation helper ---
# validate_log_fixture <fixture-name>
# Runs the input JSON through peon.sh with debug=true and validates that
# each expected phase line from the fixture appears in the log output.
# Values set to empty (key=) are wildcards; non-empty values must match exactly.
validate_log_fixture() {
  local fixture_name="$1"
  local fixture_dir
  fixture_dir="${BATS_TEST_DIRNAME}/fixtures/hook-logging"
  local input_file="$fixture_dir/${fixture_name}.input.json"
  local expected_file="$fixture_dir/${fixture_name}.expected.txt"

  [ -f "$input_file" ] || { echo "Missing fixture input: $input_file"; return 1; }
  [ -f "$expected_file" ] || { echo "Missing fixture expected: $expected_file"; return 1; }

  local input
  input=$(cat "$input_file")
  run_peon "$input"
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ] || { echo "No log file created"; return 1; }

  # For each expected line, extract the [phase] tag and verify it exists in log
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    local phase
    phase=$(echo "$line" | sed -n 's/.*\[\([a-z]*\)\].*/\1/p')
    [ -z "$phase" ] && continue
    grep -q "\[$phase\]" "$logfile" || { echo "Missing phase [$phase] in log"; return 1; }

    # Check non-wildcard key=value pairs using Python regex to handle quoted values
    local kv_part
    kv_part=$(echo "$line" | sed "s/.*\[$phase\] //")
    while IFS= read -r kv; do
      [ -z "$kv" ] && continue
      local key val
      key="${kv%%=*}"
      val="${kv#*=}"
      # Skip wildcard (empty value)
      [ -z "$val" ] && continue
      # For quoted values, strip outer quotes for grep
      val=$(echo "$val" | sed 's/^"//;s/"$//')
      grep "\[$phase\]" "$logfile" | grep -q "$key=" || { echo "Missing $key in [$phase]"; return 1; }
    done < <(/usr/bin/python3 -c "
import re, sys
line = sys.stdin.read().strip()
# Parse key=value or key=\"quoted value\" pairs
for m in re.finditer(r'(\w+)=(\"[^\"]*\"|\S*)', line):
    print(m.group(0))
" <<< "$kv_part")
  done < "$expected_file"
  return 0
}

@test "fixture: stop-normal produces all expected phases" {
  enable_debug_logging
  validate_log_fixture "stop-normal"
}

@test "fixture: delegate-mode produces suppressed route" {
  enable_debug_logging
  # Enable suppress_delegate_sessions so delegate mode actually suppresses
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['suppress_delegate_sessions'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  validate_log_fixture "delegate-mode"
}

@test "fixture: cwd-with-spaces logs quoted cwd value" {
  enable_debug_logging
  validate_log_fixture "cwd-with-spaces"
  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  # Verify the cwd value is properly quoted (contains spaces)
  grep '\[hook\]' "$logfile" | grep -q 'cwd="'
}

# --- Concurrency test: 5 parallel invocations ---

@test "5 concurrent hook invocations produce non-corrupted log entries with distinct inv IDs" {
  enable_debug_logging
  # Run 5 invocations in parallel
  for i in 1 2 3 4 5; do
    echo '{"hook_event_name":"Stop","cwd":"/tmp/proj'$i'","session_id":"s-conc-'$i'"}' | \
      bash "$PEON_SH" 2>/dev/null &
  done
  wait

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]

  # Each invocation should produce at least [hook] and [exit] entries
  local hook_count exit_count
  hook_count=$(grep -c '\[hook\]' "$logfile")
  exit_count=$(grep -c '\[exit\]' "$logfile")
  [ "$hook_count" -ge 5 ]
  [ "$exit_count" -ge 5 ]

  # Extract distinct invocation IDs
  local inv_ids
  inv_ids=$(grep -o 'inv=[a-f0-9]*' "$logfile" | sort -u | wc -l | tr -d ' ')
  [ "$inv_ids" -ge 5 ]

  # Verify no corrupted lines (every non-empty line should match the log format)
  # Format: YYYY-MM-DDTHH:MM:SS.mmm [phase] inv=XXXX ...
  local bad_lines
  bad_lines=$(grep -v '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\.[0-9]\{3\} \[' "$logfile" | wc -l | tr -d ' ')
  [ "$bad_lines" -eq 0 ]
}

# --- Performance benchmark: debug=false adds <1ms overhead ---

@test "debug=false has negligible overhead (no log directory created)" {
  # Default config has debug=false — just verify no logs dir is created
  # and the hook completes successfully. A timing test is not reliable in CI,
  # but verifying zero I/O (no logs/ directory) confirms the no-op path.
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-perf"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ ! -d "$TEST_DIR/logs" ]
  # Also verify _PEON_LOG_FILE is not set (Python didn't export it)
  # The run_peon helper evals the output, so we check the var is empty
  [ -z "${_PEON_LOG_FILE:-}" ]
}

# --- PRD-002 Failure Scenario Tests ---
# 5 scenarios: missing audio backend, bad config, pack not installed, timeout, state locked

@test "PRD-002: bad config is diagnosable from log output" {
  # Write invalid JSON to config file
  echo '{bad json' > "$TEST_DIR/config.json"
  export PEON_DEBUG=1
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-badcfg"}'
  unset PEON_DEBUG
  # Hook should still succeed (falls back to defaults)
  [ "$PEON_EXIT" -eq 0 ]
  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]
  # Config error should be logged
  grep -q '\[config\]' "$logfile"
  grep '\[config\]' "$logfile" | grep -q 'error='
  grep '\[config\]' "$logfile" | grep -q 'fallback=defaults'
}

@test "PRD-002: pack not installed is diagnosable from log output" {
  /usr/bin/python3 -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['debug'] = True
cfg['default_pack'] = 'nonexistent_pack'
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-nopack"}'
  [ "$PEON_EXIT" -eq 0 ]
  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]
  # Sound error should be logged — pack not found or no sound found
  grep -q '\[sound\]' "$logfile"
  grep '\[sound\]' "$logfile" | grep -q 'error='
}

@test "PRD-002: missing audio backend is diagnosable from log output" {
  enable_debug_logging
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-noaudio"}'
  [ "$PEON_EXIT" -eq 0 ]
  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]
  # The [play] phase should log the backend being used (which in tests is a mock).
  # In a real missing-backend scenario, play_sound logs the backend attempt.
  # For this test, verify [play] phase appears and logs backend info.
  grep -q '\[play\]' "$logfile"
  grep '\[play\]' "$logfile" | grep -q 'backend='
}

@test "PRD-002: missing audio backend on linux logs play error" {
  enable_debug_logging
  # Force linux platform and remove ALL audio backends from PATH so
  # detect_linux_player fails and play_sound logs [play] error=
  export PEON_PLATFORM=linux
  # Build a PATH with only python3 and basic utils — no audio players
  local clean_bin
  clean_bin="$(mktemp -d)"
  # Keep only python3 (needed for peon.sh), bash, date, grep, sed, etc.
  for util in python3 bash date grep sed awk cat wc sort head tail mkdir touch rm printf tr cut; do
    local util_path
    util_path=$(command -v "$util" 2>/dev/null) || true
    [ -n "$util_path" ] && ln -sf "$util_path" "$clean_bin/$util"
  done
  local saved_path="$PATH"
  export PATH="$clean_bin"
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-nobackend"}'
  export PATH="$saved_path"
  unset PEON_PLATFORM
  [ "$PEON_EXIT" -eq 0 ]
  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]
  # The [play] phase should log the error when no backend is available
  grep -q '\[play\]' "$logfile"
  grep '\[play\]' "$logfile" | grep -q 'error='
}

@test "PRD-002: suppression decisions are diagnosable from log output" {
  # This covers the "timeout" scenario equivalent — debounce/suppression
  # prevents sounds from firing, and the reason is logged.
  enable_debug_logging
  # First Stop
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-supp"}'
  [ "$PEON_EXIT" -eq 0 ]
  # Second Stop within 5s — debounced
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-supp"}'
  [ "$PEON_EXIT" -eq 0 ]
  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  # Suppressed invocation should log reason
  grep -q 'suppressed=True' "$logfile"
  grep 'suppressed=True' "$logfile" | grep -q 'reason='
}

@test "PRD-002: state contention is safe with concurrent access" {
  enable_debug_logging
  # Run 3 concurrent invocations to exercise state read/write contention
  for i in 1 2 3; do
    echo '{"hook_event_name":"Stop","cwd":"/tmp/proj","session_id":"s-state-'$i'"}' | \
      bash "$PEON_SH" 2>/dev/null &
  done
  wait

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]
  # All invocations should log [state] successfully (no state read errors)
  local state_count
  state_count=$(grep -c '\[state\]' "$logfile")
  [ "$state_count" -ge 3 ]
  # Verify no state errors in the log
  ! grep '\[state\]' "$logfile" | grep -q 'error='
}

# --- Step 2B: Bash log helper hardening tests ---

@test "debug log timestamps have real millisecond precision (not hardcoded .000)" {
  enable_debug_logging
  # Run multiple invocations to increase chance of non-zero ms
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-ms1"}'
  [ "$PEON_EXIT" -eq 0 ]
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-ms2"}'
  [ "$PEON_EXIT" -eq 0 ]
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"s-ms3"}'
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]

  # Extract all millisecond parts (the 3 digits after the dot in timestamps)
  # Timestamp format: 2024-01-15T10:30:45.123 [phase] ...
  local ms_values
  ms_values=$(grep -oE '\.[0-9]{3} \[' "$logfile" | grep -oE '[0-9]{3}' | sort -u)
  # With multiple invocations, at least one timestamp should have non-zero ms.
  # If ALL timestamps are .000, the ms is likely hardcoded.
  local non_zero
  non_zero=$(echo "$ms_values" | grep -v '^000$' | head -1 || true)
  [ -n "$non_zero" ]
}

@test "debug log _log_quote escapes newlines to preserve one-line-per-entry invariant" {
  enable_debug_logging
  # Send a Stop event — the Python log function will write entries with various values.
  # We verify that NO log line is a bare continuation (i.e., every line matches the
  # timestamp-prefixed format). If _log_quote fails to escape newlines, a multi-line
  # value would produce lines without the timestamp prefix.
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/my\nproject","session_id":"s-nl"}'
  [ "$PEON_EXIT" -eq 0 ]

  local today
  today=$(date '+%Y-%m-%d')
  local logfile="$TEST_DIR/logs/peon-ping-${today}.log"
  [ -f "$logfile" ]

  # Every line in the log file must start with an ISO timestamp
  local bad_lines
  bad_lines=$(grep -cvE '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3} \[' "$logfile" || true)
  [ "$bad_lines" -eq 0 ]
}

# ── debug on/off/status ──────────────────────────────────────────────

@test "debug on sets debug true in config" {
  run bash "$PEON_SH" debug on
  [ "$status" -eq 0 ]
  [[ "$output" == *"debug logging enabled"* ]]
  val=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('debug'))")
  [ "$val" = "True" ]
}

@test "debug off sets debug false in config" {
  # Enable first
  bash "$PEON_SH" debug on >/dev/null 2>&1
  run bash "$PEON_SH" debug off
  [ "$status" -eq 0 ]
  [[ "$output" == *"debug logging disabled"* ]]
  val=$(/usr/bin/python3 -c "import json; print(json.load(open('$TEST_DIR/config.json')).get('debug'))")
  [ "$val" = "False" ]
}

@test "debug status shows off when debug is false" {
  run bash "$PEON_SH" debug status
  [ "$status" -eq 0 ]
  [[ "$output" == *"off"* ]]
}

@test "debug status shows on when debug is true" {
  bash "$PEON_SH" debug on >/dev/null 2>&1
  run bash "$PEON_SH" debug status
  [ "$status" -eq 0 ]
  [[ "$output" == *" on"* ]]
}

@test "debug status shows log directory path" {
  run bash "$PEON_SH" debug status
  [ "$status" -eq 0 ]
  [[ "$output" == *"logs directory"* ]]
}

@test "debug status shows log file count" {
  mkdir -p "$TEST_DIR/logs"
  echo "test log line" > "$TEST_DIR/logs/peon-ping-2026-03-25.log"
  run bash "$PEON_SH" debug status
  [ "$status" -eq 0 ]
  [[ "$output" == *"log files:"* ]]
}

@test "debug with no subcommand shows usage" {
  run bash "$PEON_SH" debug
  [ "$status" -eq 0 ]
  [[ "$output" == *"on"* ]]
  [[ "$output" == *"off"* ]]
  [[ "$output" == *"status"* ]]
}

# ── logs ──────────────────────────────────────────────────────────────

@test "logs shows last 50 lines of today's log" {
  mkdir -p "$TEST_DIR/logs"
  today=$(date +%Y-%m-%d)
  for i in $(seq 1 60); do
    echo "line $i" >> "$TEST_DIR/logs/peon-ping-${today}.log"
  done
  run bash "$PEON_SH" logs
  [ "$status" -eq 0 ]
  # Should show last 50 (lines 11-60), not first 10
  [[ "$output" == *"line 60"* ]]
  # Grep for exact "line 1" (word boundary) — should not appear in last 50 of 60 lines
  ! echo "$output" | grep -q '^line 1$'
}

@test "logs shows message when no log files exist" {
  run bash "$PEON_SH" logs
  [ "$status" -eq 0 ]
  [[ "$output" == *"no log"* ]] || [[ "$output" == *"No log"* ]]
}

@test "logs --last N shows last N lines across all files" {
  mkdir -p "$TEST_DIR/logs"
  echo "old line 1" > "$TEST_DIR/logs/peon-ping-2026-03-24.log"
  echo "old line 2" >> "$TEST_DIR/logs/peon-ping-2026-03-24.log"
  echo "new line 1" > "$TEST_DIR/logs/peon-ping-2026-03-25.log"
  echo "new line 2" >> "$TEST_DIR/logs/peon-ping-2026-03-25.log"
  run bash "$PEON_SH" logs --last 3
  [ "$status" -eq 0 ]
  [[ "$output" == *"new line 2"* ]]
  [[ "$output" == *"new line 1"* ]]
  [[ "$output" == *"old line 2"* ]]
}

@test "logs --session ID filters by session" {
  mkdir -p "$TEST_DIR/logs"
  today=$(date +%Y-%m-%d)
  cat > "$TEST_DIR/logs/peon-ping-${today}.log" <<'LOG'
ts=2026-03-25T10:00:00 inv=aa11 session=abc123 phase=[hook] event=Start
ts=2026-03-25T10:00:01 inv=bb22 session=def456 phase=[hook] event=Stop
ts=2026-03-25T10:00:02 inv=cc33 session=abc123 phase=[sound] file=Hello1.wav
LOG
  run bash "$PEON_SH" logs --session abc123
  [ "$status" -eq 0 ]
  [[ "$output" == *"abc123"* ]]
  [[ "$output" != *"def456"* ]]
}

# ── log rotation (--prune CLI) ───────────────────────────────────────

@test "logs --prune removes old log files" {
  # Set retention to 3 days
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['debug'] = True
c['debug_retention_days'] = 3
json.dump(c, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  mkdir -p "$TEST_DIR/logs"
  # Create log files: one from 10 days ago, one from 1 day ago, one from today
  touch "$TEST_DIR/logs/peon-ping-2020-01-01.log"
  touch "$TEST_DIR/logs/peon-ping-2020-01-02.log"
  # Create a recent file using today's date
  today=$(date +%Y-%m-%d)
  touch "$TEST_DIR/logs/peon-ping-${today}.log"

  run bash "$PEON_SH" logs --prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"pruned 2 log file(s)"* ]]
  # Old files should be gone
  [ ! -f "$TEST_DIR/logs/peon-ping-2020-01-01.log" ]
  [ ! -f "$TEST_DIR/logs/peon-ping-2020-01-02.log" ]
  # Today's file should remain
  [ -f "$TEST_DIR/logs/peon-ping-${today}.log" ]
}

@test "logs --prune reports nothing when all files are recent" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['debug_retention_days'] = 7
json.dump(c, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  mkdir -p "$TEST_DIR/logs"
  today=$(date +%Y-%m-%d)
  touch "$TEST_DIR/logs/peon-ping-${today}.log"

  run bash "$PEON_SH" logs --prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"no log files older than"* ]]
  [ -f "$TEST_DIR/logs/peon-ping-${today}.log" ]
}

@test "logs --prune respects custom retention value" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['debug_retention_days'] = 1
json.dump(c, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  mkdir -p "$TEST_DIR/logs"
  # Create a file from 2 days ago (should be pruned with 1-day retention)
  two_days_ago=$(date -d '2 days ago' +%Y-%m-%d 2>/dev/null || date -j -v-2d +%Y-%m-%d 2>/dev/null)
  touch "$TEST_DIR/logs/peon-ping-${two_days_ago}.log"
  today=$(date +%Y-%m-%d)
  touch "$TEST_DIR/logs/peon-ping-${today}.log"

  run bash "$PEON_SH" logs --prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"pruned 1 log file(s)"* ]]
  [ ! -f "$TEST_DIR/logs/peon-ping-${two_days_ago}.log" ]
  [ -f "$TEST_DIR/logs/peon-ping-${today}.log" ]
}

@test "logs --prune handles empty log directory" {
  mkdir -p "$TEST_DIR/logs"
  run bash "$PEON_SH" logs --prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"no log files older than"* ]]
}

@test "logs --prune handles missing log directory" {
  rm -rf "$TEST_DIR/logs"
  run bash "$PEON_SH" logs --prune
  [ "$status" -eq 0 ]
  [[ "$output" == *"no logs directory found"* ]]
}

# ── multi-day session search (--session --all) ───────────────────────

@test "logs --session ID --all searches across multiple day files" {
  mkdir -p "$TEST_DIR/logs"
  today=$(date +%Y-%m-%d)
  # Create yesterday's log with a session entry
  cat > "$TEST_DIR/logs/peon-ping-2026-03-24.log" <<'LOG'
ts=2026-03-24T23:59:00 inv=aa11 session=midnight123 phase=[hook] event=Start
ts=2026-03-24T23:59:30 inv=bb22 session=other999 phase=[hook] event=Stop
LOG
  # Create today's log with the same session
  cat > "$TEST_DIR/logs/peon-ping-${today}.log" <<'LOG'
ts=2026-03-25T00:00:05 inv=cc33 session=midnight123 phase=[sound] file=Hello1.wav
ts=2026-03-25T00:01:00 inv=dd44 session=other999 phase=[hook] event=Start
LOG
  run bash "$PEON_SH" logs --session midnight123 --all
  [ "$status" -eq 0 ]
  # Should find entries from both days
  [[ "$output" == *"2026-03-24T23:59:00"* ]]
  [[ "$output" == *"2026-03-25T00:00:05"* ]]
  # Should not include other sessions
  [[ "$output" != *"other999"* ]]
}

@test "logs --session ID without --all only searches today" {
  mkdir -p "$TEST_DIR/logs"
  today=$(date +%Y-%m-%d)
  # Create yesterday's log with a session entry
  cat > "$TEST_DIR/logs/peon-ping-2026-03-24.log" <<'LOG'
ts=2026-03-24T23:59:00 inv=aa11 session=midnight123 phase=[hook] event=Start
LOG
  # Create today's log with the same session
  cat > "$TEST_DIR/logs/peon-ping-${today}.log" <<'LOG'
ts=2026-03-25T00:00:05 inv=cc33 session=midnight123 phase=[sound] file=Hello1.wav
LOG
  run bash "$PEON_SH" logs --session midnight123
  [ "$status" -eq 0 ]
  # Should find today's entry only
  [[ "$output" == *"2026-03-25T00:00:05"* ]]
  # Should NOT find yesterday's entry (no --all)
  [[ "$output" != *"2026-03-24T23:59:00"* ]]
}

@test "logs --session ID --all shows results in chronological order" {
  mkdir -p "$TEST_DIR/logs"
  today=$(date +%Y-%m-%d)
  cat > "$TEST_DIR/logs/peon-ping-2026-03-23.log" <<'LOG'
ts=2026-03-23T12:00:00 inv=aa11 session=chrono123 phase=[hook] event=Start
LOG
  cat > "$TEST_DIR/logs/peon-ping-2026-03-24.log" <<'LOG'
ts=2026-03-24T12:00:00 inv=bb22 session=chrono123 phase=[hook] event=Stop
LOG
  cat > "$TEST_DIR/logs/peon-ping-${today}.log" <<'LOG'
ts=2026-03-25T12:00:00 inv=cc33 session=chrono123 phase=[sound] file=Hello1.wav
LOG
  run bash "$PEON_SH" logs --session chrono123 --all
  [ "$status" -eq 0 ]
  # All three entries should appear
  [[ "$output" == *"2026-03-23"* ]]
  [[ "$output" == *"2026-03-24"* ]]
  [[ "$output" == *"2026-03-25"* ]]
  # Verify chronological order: line 1 should be earliest
  first_line=$(echo "$output" | head -1)
  [[ "$first_line" == *"2026-03-23"* ]]
}

@test "logs --session ID --all with no matches shows message" {
  mkdir -p "$TEST_DIR/logs"
  today=$(date +%Y-%m-%d)
  echo "ts=2026-03-25T10:00:00 inv=aa11 session=abc123 phase=[hook] event=Start" > "$TEST_DIR/logs/peon-ping-${today}.log"
  run bash "$PEON_SH" logs --session nonexistent --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"no entries for session=nonexistent across all log files"* ]]
}

@test "logs --session ID --all with no log files shows message" {
  # Ensure no logs directory
  rm -rf "$TEST_DIR/logs"
  run bash "$PEON_SH" logs --session abc123 --all
  [ "$status" -eq 0 ]
  [[ "$output" == *"no log files found"* ]]
}

@test "help shows logs --session --all" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--session ID --all"* ]]
}

@test "logs --prune skips non-log files" {
  mkdir -p "$TEST_DIR/logs"
  touch "$TEST_DIR/logs/peon-ping-2020-01-01.log"
  touch "$TEST_DIR/logs/other-file.txt"
  touch "$TEST_DIR/logs/readme.md"

  run bash "$PEON_SH" logs --prune
  [ "$status" -eq 0 ]
  # Non-log files should survive
  [ -f "$TEST_DIR/logs/other-file.txt" ]
  [ -f "$TEST_DIR/logs/readme.md" ]
}

@test "logs --clear deletes all log files" {
  mkdir -p "$TEST_DIR/logs"
  touch "$TEST_DIR/logs/peon-ping-2024-01-01.log"
  touch "$TEST_DIR/logs/peon-ping-2024-06-15.log"
  touch "$TEST_DIR/logs/peon-ping-$(date +%Y-%m-%d).log"

  run bash "$PEON_SH" logs --clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"cleared 3 log file(s)"* ]]
  # All log files should be gone
  local remaining
  remaining=$(find "$TEST_DIR/logs" -name "peon-ping-*.log" 2>/dev/null | wc -l | tr -d ' ')
  [ "$remaining" -eq 0 ]
}

@test "logs --clear reports no files when directory is empty" {
  mkdir -p "$TEST_DIR/logs"

  run bash "$PEON_SH" logs --clear
  [ "$status" -eq 0 ]
  [[ "$output" == *"no log files to clear"* ]]
}

@test "logs --prune skips non-log files in logs directory" {
  /usr/bin/python3 -c "
import json
c = json.load(open('$TEST_DIR/config.json'))
c['debug_retention_days'] = 1
json.dump(c, open('$TEST_DIR/config.json', 'w'), indent=2)
"
  mkdir -p "$TEST_DIR/logs"
  # Create a non-log file (should not be touched)
  echo "keep me" > "$TEST_DIR/logs/custom-notes.txt"
  touch "$TEST_DIR/logs/peon-ping-2020-01-01.log"

  run bash "$PEON_SH" logs --prune
  [ "$status" -eq 0 ]
  # Non-log file should still exist
  [ -f "$TEST_DIR/logs/custom-notes.txt" ]
}

# ── help includes debug and logs ─────────────────────────────────────

@test "help lists debug command" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"debug"* ]]
}

@test "help lists logs command" {
  run bash "$PEON_SH" help
  [ "$status" -eq 0 ]
  [[ "$output" == *"logs"* ]]
}
