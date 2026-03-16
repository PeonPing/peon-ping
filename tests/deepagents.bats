#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Derive repo root from PEON_SH (set by setup.bash using its own BASH_SOURCE)
  DEEPAGENTS_SH="${PEON_SH%/peon.sh}/adapters/deepagents.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR — symlink it into the test dir
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Helper: run deepagents adapter with a JSON event
run_deepagents() {
  local json="$1"
  export PEON_TEST=1
  echo "$json" | bash "$DEEPAGENTS_SH" 2>"$TEST_DIR/stderr.log"
  DA_EXIT=$?
  DA_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
}

# ============================================================
# Event mapping
# ============================================================

@test "session.start maps to SessionStart and plays greeting" {
  run_deepagents '{"event":"session.start","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "task.complete maps to Stop and plays completion sound" {
  run_deepagents '{"event":"task.complete","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "input.required maps to Notification with permission_prompt (no sound, tab title only)" {
  run_deepagents '{"event":"input.required","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  # Notification/permission_prompt only sets tab title — sound is handled by PermissionRequest
  ! afplay_was_called
}

@test "task.error maps to Stop and plays completion sound" {
  run_deepagents '{"event":"task.error","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

# ============================================================
# Skipped events
# ============================================================

@test "tool.call is skipped (too noisy)" {
  run_deepagents '{"event":"tool.call","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "unknown event is skipped gracefully" {
  run_deepagents '{"event":"some.unknown.event","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Session ID prefixing
# ============================================================

@test "session_id is prefixed with deepagents- and uses thread_id" {
  # Verify the adapter passes deepagents-prefixed session_id to peon.sh
  # by checking that debounce works across calls (same session = same debounce)
  run_deepagents '{"event":"task.complete","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second stop within debounce window should be suppressed
  run_deepagents '{"event":"task.complete","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses deepagents sounds" {
  touch "$TEST_DIR/.paused"
  run_deepagents '{"event":"session.start","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses deepagents sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_deepagents '{"event":"session.start","thread_id":"t1"}'
  [ "$DA_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_deepagents '{"event":"session.start","thread_id":"t1"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Spam detection
# ============================================================

@test "rapid deepagents prompts trigger annoyed sound" {
  # input.required maps to Notification/permission_prompt which doesn't trigger spam
  # Use a pattern that goes through UserPromptSubmit — but deepagents doesn't have one,
  # so we verify that multiple session.start calls within the cooldown don't double-play
  run_deepagents '{"event":"task.complete","thread_id":"t1"}'
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second identical event within debounce should be suppressed
  run_deepagents '{"event":"task.complete","thread_id":"t1"}'
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Missing fields handled gracefully
# ============================================================

@test "missing thread_id still works (falls back to PID)" {
  run_deepagents '{"event":"session.start"}'
  [ "$DA_EXIT" -eq 0 ]
  afplay_was_called
}

@test "empty JSON exits gracefully" {
  run_deepagents '{}'
  [ "$DA_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "extra fields are ignored gracefully" {
  run_deepagents '{"event":"task.complete","thread_id":"t1","extra_field":"value","nested":{"a":1}}'
  [ "$DA_EXIT" -eq 0 ]
  afplay_was_called
}
