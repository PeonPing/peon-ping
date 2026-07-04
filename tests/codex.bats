#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  CODEX_SH="${PEON_SH%/peon.sh}/adapters/codex.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

run_codex() {
  local event="${1-}"
  local json="${2-}"
  export PEON_TEST=1
  if [ -n "$json" ]; then
    if [ -n "$event" ]; then
      echo "$json" | bash "$CODEX_SH" "$event" 2>"$TEST_DIR/stderr.log"
    else
      echo "$json" | bash "$CODEX_SH" 2>"$TEST_DIR/stderr.log"
    fi
  else
    if [ -n "$event" ]; then
      bash "$CODEX_SH" "$event" 2>"$TEST_DIR/stderr.log"
    else
      bash "$CODEX_SH" 2>"$TEST_DIR/stderr.log"
    fi
  fi
  CODEX_EXIT=$?
  CODEX_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  sleep 0.3
}

@test "adapter script has valid bash syntax" {
  run bash -n "$CODEX_SH"
  [ "$status" -eq 0 ]
}

@test "agent-turn-complete maps to Stop and plays completion sound" {
  run_codex "agent-turn-complete"
  [ "$CODEX_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "error maps to PostToolUseFailure and plays error sound" {
  run_codex "error"
  [ "$CODEX_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "permission event maps to Notification permission_prompt (no duplicate sound)" {
  run_codex "permission-required"
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stdin json session_id and cwd are forwarded with codex session prefix" {
  run_codex "" '{"event":"done","cwd":"/tmp/codex-proj","session_id":"sess-42"}'
  [ "$CODEX_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'codex-sess-42', last
assert last.get('cwd') == '/tmp/codex-proj', last
"
}

@test "legacy argv event ignores redirected stdin" {
  run_codex "agent-turn-complete" '{"hook_event_name":"PermissionRequest","session_id":"stdin-ignored"}'
  [ "$CODEX_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

# ============================================================
# Stable Codex hooks (stdin hook_event_name, PascalCase)
# ============================================================

@test "stable SessionStart maps to session.start and plays greeting" {
  run_codex "" '{"hook_event_name":"SessionStart","session_id":"s1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "stable Stop maps to task.complete and plays completion sound" {
  run_codex "" '{"hook_event_name":"Stop","session_id":"s1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "stable PermissionRequest maps to input.required and plays permission sound" {
  run_codex "" '{"hook_event_name":"PermissionRequest","tool_name":"Bash","session_id":"s1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "stable PreCompact maps to resource.limit and plays limit sound" {
  run_codex "" '{"hook_event_name":"PreCompact","session_id":"s1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Limit"* ]]
}

@test "stable SubagentStart is silent" {
  run_codex "" '{"hook_event_name":"SubagentStart","session_id":"s1","agent_id":"a1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable failed PostToolUse is silent" {
  run_codex "" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_response":{"exit_code":1}}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable successful PostToolUse is silent" {
  run_codex "" '{"hook_event_name":"PostToolUse","tool_response":{"exit_code":0}}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable PreToolUse is silent" {
  run_codex "" '{"hook_event_name":"PreToolUse","session_id":"s1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable UserPromptSubmit plays no sound" {
  run_codex "" '{"hook_event_name":"UserPromptSubmit","session_id":"s1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable PostCompact is silent" {
  run_codex "" '{"hook_event_name":"PostCompact","session_id":"s1"}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable PostToolUse failure via top-level exit_code is silent" {
  run_codex "" '{"hook_event_name":"PostToolUse","tool_name":"Bash","exit_code":2}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable PostToolUse failure via success=false is silent" {
  run_codex "" '{"hook_event_name":"PostToolUse","tool_name":"Bash","success":"false"}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stable PostToolUse failure via tool_response.is_error is silent" {
  run_codex "" '{"hook_event_name":"PostToolUse","tool_name":"Bash","tool_response":{"is_error":true}}'
  [ "$CODEX_EXIT" -eq 0 ]
  ! afplay_was_called
}
