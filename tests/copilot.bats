#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Derive repo root from PEON_SH (set by setup.bash using its own BASH_SOURCE)
  COPILOT_SH="${PEON_SH%/peon.sh}/adapters/copilot.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR — symlink it into the test dir
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Helper: run copilot adapter with an event name argument
# Copilot passes event name as $1 and JSON on stdin
run_copilot() {
  local event="$1"
  local json="${2:-{}}"
  export PEON_TEST=1
  echo "$json" | bash "$COPILOT_SH" "$event" 2>"$TEST_DIR/stderr.log"
  COPILOT_EXIT=$?
  COPILOT_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  # On macOS peon.sh runs afplay via nohup & (background); wait for mock to finish
  sleep 0.3
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$COPILOT_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Event mapping
# ============================================================

@test "sessionStart maps to SessionStart and plays greeting" {
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "postToolUse maps to Stop and plays completion sound" {
  run_copilot postToolUse '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "errorOccurred maps to TaskError and plays error sound" {
  run_copilot errorOccurred '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "first userPromptSubmitted maps to SessionStart and plays greeting" {
  run_copilot userPromptSubmitted '{"sessionId":"test-456","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "subsequent userPromptSubmitted maps to UserPromptSubmit" {
  # First call creates session marker (SessionStart)
  run_copilot userPromptSubmitted '{"sessionId":"test-789","cwd":"/tmp"}'
  # Second call is UserPromptSubmit — no sound normally
  rm -f "$TEST_DIR/afplay.log"
  run_copilot userPromptSubmitted '{"sessionId":"test-789","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Skipped events
# ============================================================

@test "sessionEnd exits gracefully without sound" {
  run_copilot sessionEnd '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "preToolUse exits gracefully without sound (too noisy)" {
  run_copilot preToolUse '{"sessionId":"test-123","cwd":"/tmp","toolName":"bash"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "unknown event exits gracefully without sound" {
  run_copilot some_future_event '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# JSON parsing
# ============================================================

@test "extracts sessionId from JSON input" {
  run_copilot sessionStart '{"sessionId":"custom-session-id","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  # Session marker file should use the custom session ID
  [ -f "$TEST_DIR/.copilot-session-custom-session-id" ]
}

@test "extracts cwd from JSON input" {
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/custom/path"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
}

@test "falls back to default sessionId when JSON is empty" {
  run_copilot sessionStart '{}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
}

@test "falls back to PWD when cwd is missing from JSON" {
  run_copilot sessionStart '{"sessionId":"test-123"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses Copilot sounds" {
  touch "$TEST_DIR/.paused"
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses Copilot sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "active_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_copilot postToolUse '{"sessionId":"test-123","cwd":"/tmp"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Spam detection
# ============================================================

@test "rapid Copilot prompts trigger annoyed sound" {
  # First userPromptSubmitted is SessionStart (creates marker).
  run_copilot userPromptSubmitted '{"sessionId":"spam-test","cwd":"/tmp"}'
  # peon.sh suppresses sounds within 3s of SessionStart (session replay protection).
  # Wait past the suppression window before sending rapid prompts.
  sleep 3
  rm -f "$TEST_DIR/afplay.log"
  for i in $(seq 1 3); do
    run_copilot userPromptSubmitted '{"sessionId":"spam-test","cwd":"/tmp"}'
  done
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"Angry1.wav" ]]
}

# ============================================================
# Debounce
# ============================================================

@test "second Stop within debounce window is suppressed" {
  run_copilot postToolUse '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second stop within debounce window should be suppressed
  run_copilot postToolUse '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Default argument
# ============================================================

@test "no argument defaults to sessionStart" {
  export PEON_TEST=1
  echo '{"sessionId":"test-123","cwd":"/tmp"}' | bash "$COPILOT_SH" 2>"$TEST_DIR/stderr.log"
  COPILOT_EXIT=$?
  sleep 0.3
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}
