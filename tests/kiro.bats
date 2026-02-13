#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Derive repo root from PEON_SH (set by setup.bash using its own BASH_SOURCE)
  KIRO_SH="${PEON_SH%/peon.sh}/adapters/kiro.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR — symlink it into the test dir
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Helper: run kiro adapter with a JSON event
run_kiro() {
  local json="$1"
  export PEON_TEST=1
  echo "$json" | bash "$KIRO_SH" 2>"$TEST_DIR/stderr.log"
  KIRO_EXIT=$?
  KIRO_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
}

# ============================================================
# Event mapping
# ============================================================

@test "agentSpawn maps to SessionStart and plays greeting" {
  run_kiro '{"hook_event_name":"agentSpawn","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "userPromptSubmit maps to UserPromptSubmit" {
  run_kiro '{"hook_event_name":"userPromptSubmit","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  # UserPromptSubmit does not play sound normally (only on spam)
  ! afplay_was_called
}

@test "stop maps to Stop and plays completion sound" {
  run_kiro '{"hook_event_name":"stop","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

# ============================================================
# Skipped events
# ============================================================

@test "preToolUse is skipped (too noisy)" {
  run_kiro '{"hook_event_name":"preToolUse","cwd":"/tmp/myproject","session_id":"k1","tool_name":"execute_bash"}'
  [ "$KIRO_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "postToolUse is skipped (too noisy)" {
  run_kiro '{"hook_event_name":"postToolUse","cwd":"/tmp/myproject","session_id":"k1","tool_name":"fs_write"}'
  [ "$KIRO_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "unknown event is skipped gracefully" {
  run_kiro '{"hook_event_name":"someNewEvent","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Session ID prefixing
# ============================================================

@test "session_id is prefixed with kiro-" {
  # Verify the adapter passes kiro-prefixed session_id to peon.sh
  # by checking that debounce works across calls (same session = same debounce)
  run_kiro '{"hook_event_name":"stop","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second stop within debounce window should be suppressed
  run_kiro '{"hook_event_name":"stop","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses Kiro sounds" {
  touch "$TEST_DIR/.paused"
  run_kiro '{"hook_event_name":"agentSpawn","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses Kiro sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "active_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_kiro '{"hook_event_name":"agentSpawn","cwd":"/tmp/myproject","session_id":"k1"}'
  [ "$KIRO_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_kiro '{"hook_event_name":"agentSpawn","cwd":"/tmp/myproject","session_id":"k1"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Spam detection
# ============================================================

@test "rapid Kiro prompts trigger annoyed sound" {
  for i in $(seq 1 3); do
    run_kiro '{"hook_event_name":"userPromptSubmit","cwd":"/tmp/myproject","session_id":"k1"}'
  done
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"Angry1.wav" ]]
}

# ============================================================
# Missing fields handled gracefully
# ============================================================

@test "minimal JSON (only hook_event_name) works" {
  run_kiro '{"hook_event_name":"stop"}'
  [ "$KIRO_EXIT" -eq 0 ]
  afplay_was_called
}

@test "extra Kiro-specific fields are ignored gracefully" {
  run_kiro '{"hook_event_name":"stop","cwd":"/tmp/p","session_id":"k1","tool_name":"execute_bash","tool_input":{"command":"ls"},"tool_response":"files..."}'
  [ "$KIRO_EXIT" -eq 0 ]
  afplay_was_called
}
