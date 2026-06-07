#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  IFLOW_SH="${PEON_SH%/peon.sh}/adapters/iflow.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# iFlow CLI pipes its event JSON on stdin (Claude-Code-style hooks).
run_iflow() {
  local json="$1"
  export PEON_TEST=1
  echo "$json" | bash "$IFLOW_SH" 2>"$TEST_DIR/stderr.log"
  IFLOW_EXIT=$?
  IFLOW_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  sleep 0.3
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$IFLOW_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Event mapping
# ============================================================

@test "Stop maps to task.complete and plays completion sound" {
  run_iflow '{"hook_event_name":"Stop","session_id":"s1"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "first SessionStart maps to session.start and plays greeting" {
  run_iflow '{"hook_event_name":"SessionStart","session_id":"s1"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "UserPromptSubmit plays no sound" {
  run_iflow '{"hook_event_name":"UserPromptSubmit","session_id":"s1"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "failed PostToolUse maps to task.error and plays error sound" {
  run_iflow '{"hook_event_name":"PostToolUse","session_id":"s1","exit_code":2,"tool_name":"Bash","error":"boom"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "successful PostToolUse plays no sound" {
  run_iflow '{"hook_event_name":"PostToolUse","session_id":"s1","exit_code":0}'
  [ "$IFLOW_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Skipped events
# ============================================================

@test "PreToolUse exits gracefully without sound" {
  run_iflow '{"hook_event_name":"PreToolUse","session_id":"s1"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "malformed stdin exits gracefully without sound" {
  run_iflow 'not json'
  [ "$IFLOW_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses iFlow sounds" {
  touch "$TEST_DIR/.paused"
  run_iflow '{"hook_event_name":"Stop","session_id":"s1"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses iFlow sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_iflow '{"hook_event_name":"Stop","session_id":"s1"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_iflow '{"hook_event_name":"Stop","session_id":"s1"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Session id prefix
# ============================================================

@test "stdin session_id and cwd are forwarded with iflow session prefix" {
  run_iflow '{"hook_event_name":"Stop","cwd":"/tmp/iflow-proj","session_id":"sess-42"}'
  [ "$IFLOW_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'iflow-sess-42', last
assert last.get('cwd') == '/tmp/iflow-proj', last
"
}
