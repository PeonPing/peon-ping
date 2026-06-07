#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  QWEN_SH="${PEON_SH%/peon.sh}/adapters/qwen.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Qwen Code pipes its event JSON on stdin (Claude-Code-style hooks).
run_qwen() {
  local json="$1"
  export PEON_TEST=1
  echo "$json" | bash "$QWEN_SH" 2>"$TEST_DIR/stderr.log"
  QWEN_EXIT=$?
  QWEN_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  sleep 0.3
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$QWEN_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Event mapping
# ============================================================

@test "Stop maps to task.complete and plays completion sound" {
  run_qwen '{"hook_event_name":"Stop","session_id":"s1"}'
  [ "$QWEN_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "first SessionStart maps to session.start and plays greeting" {
  run_qwen '{"hook_event_name":"SessionStart","session_id":"s1"}'
  [ "$QWEN_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "UserPromptSubmit plays no sound" {
  run_qwen '{"hook_event_name":"UserPromptSubmit","session_id":"s1"}'
  [ "$QWEN_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "PostToolUseFailure maps to task.error and plays error sound" {
  run_qwen '{"hook_event_name":"PostToolUseFailure","session_id":"s1","tool_name":"Bash","error":"boom"}'
  [ "$QWEN_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

# ============================================================
# Skipped events
# ============================================================

@test "PreToolUse (noisy success-path) exits gracefully without sound" {
  run_qwen '{"hook_event_name":"PreToolUse","session_id":"s1"}'
  [ "$QWEN_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "unknown event exits gracefully without sound" {
  run_qwen '{"hook_event_name":"SomeFutureEvent","session_id":"s1"}'
  [ "$QWEN_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "malformed stdin exits gracefully without sound" {
  run_qwen 'not json'
  [ "$QWEN_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses Qwen sounds" {
  touch "$TEST_DIR/.paused"
  run_qwen '{"hook_event_name":"Stop","session_id":"s1"}'
  [ "$QWEN_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses Qwen sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_qwen '{"hook_event_name":"Stop","session_id":"s1"}'
  [ "$QWEN_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_qwen '{"hook_event_name":"Stop","session_id":"s1"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Session id prefix
# ============================================================

@test "stdin session_id and cwd are forwarded with qwen session prefix" {
  run_qwen '{"hook_event_name":"Stop","cwd":"/tmp/qwen-proj","session_id":"sess-42"}'
  [ "$QWEN_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'qwen-sess-42', last
assert last.get('cwd') == '/tmp/qwen-proj', last
"
}
