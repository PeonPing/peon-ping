#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Derive repo root from PEON_SH (set by setup.bash using its own BASH_SOURCE)
  WINDSURF_SH="${PEON_SH%/peon.sh}/adapters/windsurf.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR — symlink it into the test dir
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Helper: run windsurf adapter with an event name argument
# Windsurf passes event name as $1 and JSON on stdin (which the adapter drains)
run_windsurf() {
  local event="$1"
  export PEON_TEST=1
  echo '{}' | bash "$WINDSURF_SH" "$event" 2>"$TEST_DIR/stderr.log"
  WINDSURF_EXIT=$?
  WINDSURF_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  # On macOS peon.sh runs afplay via nohup & (background); wait for mock to finish
  sleep 0.3
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$WINDSURF_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Event mapping
# ============================================================

@test "post_cascade_response maps to Stop and plays completion sound" {
  run_windsurf post_cascade_response
  [ "$WINDSURF_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "post_write_code maps to Stop and plays completion sound" {
  run_windsurf post_write_code
  [ "$WINDSURF_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "post_run_command maps to Stop and plays completion sound" {
  run_windsurf post_run_command
  [ "$WINDSURF_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "first pre_user_prompt maps to SessionStart and plays greeting" {
  run_windsurf pre_user_prompt
  [ "$WINDSURF_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "subsequent pre_user_prompt maps to UserPromptSubmit" {
  # First call creates session marker (SessionStart)
  run_windsurf pre_user_prompt
  # Second call is UserPromptSubmit — no sound normally
  rm -f "$TEST_DIR/afplay.log"
  run_windsurf pre_user_prompt
  [ "$WINDSURF_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Skipped events
# ============================================================

@test "unknown event exits gracefully without sound" {
  run_windsurf some_future_event
  [ "$WINDSURF_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses Windsurf sounds" {
  touch "$TEST_DIR/.paused"
  run_windsurf post_cascade_response
  [ "$WINDSURF_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses Windsurf sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_windsurf post_cascade_response
  [ "$WINDSURF_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_windsurf post_cascade_response
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Spam detection
# ============================================================

@test "rapid Windsurf prompts trigger annoyed sound" {
  # First pre_user_prompt is SessionStart (creates marker).
  run_windsurf pre_user_prompt
  # peon.sh suppresses sounds within 3s of SessionStart (session replay protection).
  # Wait past the suppression window before sending rapid prompts.
  sleep 3
  rm -f "$TEST_DIR/afplay.log"
  for i in $(seq 1 3); do
    run_windsurf pre_user_prompt
  done
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"Angry1.wav" ]]
}

# ============================================================
# Debounce
# ============================================================

@test "second Stop within debounce window is suppressed" {
  run_windsurf post_cascade_response
  [ "$WINDSURF_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second stop within debounce window should be suppressed
  run_windsurf post_cascade_response
  [ "$WINDSURF_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Default argument
# ============================================================

@test "no argument defaults to post_cascade_response (Stop)" {
  export PEON_TEST=1
  echo '{}' | bash "$WINDSURF_SH" 2>"$TEST_DIR/stderr.log"
  WINDSURF_EXIT=$?
  sleep 0.3
  [ "$WINDSURF_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}
