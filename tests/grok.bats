#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  unset GROK_HOOK_EVENT GROK_SESSION_ID GROK_WORKSPACE_ROOT

  GROK_SH="${PEON_SH%/peon.sh}/adapters/grok.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

run_grok() {
  local json="${1-}"
  export PEON_TEST=1
  if [ -n "$json" ]; then
    echo "$json" | bash "$GROK_SH" 2>"$TEST_DIR/stderr.log"
  else
    bash "$GROK_SH" 2>"$TEST_DIR/stderr.log"
  fi
  GROK_EXIT=$?
  GROK_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  sleep 0.3
}

@test "adapter script has valid bash syntax" {
  run bash -n "$GROK_SH"
  [ "$status" -eq 0 ]
}

@test "session_start maps to session.start and plays greeting" {
  run_grok '{"hookEventName":"session_start","sessionId":"s1"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "stop end_turn maps to task.complete and plays completion sound" {
  run_grok '{"hookEventName":"stop","sessionId":"s1","reason":"end_turn"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "stop without reason still plays completion sound" {
  run_grok '{"hookEventName":"stop","sessionId":"s-plain"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "session-end Stop is silent" {
  run_grok '{"hookEventName":"stop","sessionId":"s1","reason":"shutdown"}'
  [ "$GROK_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "permission_prompt maps to input.required and plays permission sound" {
  run_grok '{"hookEventName":"notification","sessionId":"s1","notificationType":"permission_prompt"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "idle_prompt maps to task.complete and plays completion sound" {
  run_grok '{"hookEventName":"notification","sessionId":"s-idle","notificationType":"idle_prompt"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "pre_compact maps to resource.limit and plays limit sound" {
  run_grok '{"hookEventName":"pre_compact","sessionId":"s1"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Limit"* ]]
}

@test "shell PostToolUseFailure plays error sound" {
  run_grok '{"hookEventName":"post_tool_use_failure","sessionId":"s1","toolName":"run_terminal_command","errorDetails":"exit 1"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "StopFailure plays error sound" {
  run_grok '{"hookEventName":"stop_failure","sessionId":"s-fail","error":"rate_limit"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "SubagentStart is silent" {
  run_grok '{"hookEventName":"subagent_start","sessionId":"s1","agentId":"a1"}'
  [ "$GROK_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "PreToolUse is silent" {
  run_grok '{"hookEventName":"pre_tool_use","sessionId":"s1","toolName":"read_file"}'
  [ "$GROK_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "PostToolUse is silent" {
  run_grok '{"hookEventName":"post_tool_use","sessionId":"s1"}'
  [ "$GROK_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "PostCompact is silent" {
  run_grok '{"hookEventName":"post_compact","sessionId":"s1"}'
  [ "$GROK_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "UserPromptSubmit plays no sound" {
  run_grok '{"hookEventName":"user_prompt_submit","sessionId":"s1"}'
  [ "$GROK_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "stdin sessionId and cwd are forwarded with grok session prefix" {
  run_grok '{"hookEventName":"stop","reason":"end_turn","cwd":"/tmp/grok-proj","sessionId":"sess-42"}'
  [ "$GROK_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'grok-sess-42', last
assert last.get('cwd') == '/tmp/grok-proj', last
"
}

@test "GROK_HOOK_EVENT env is used when stdin has no event name" {
  export GROK_HOOK_EVENT=session_start
  export GROK_SESSION_ID=env-sid
  run_grok '{"cwd":"/tmp/from-env"}'
  [ "$GROK_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}
