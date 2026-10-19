#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  export PEON_PLATFORM=mac
  unset TMUX
}

teardown() {
  teardown_test_env
}

warm_working_session() {
  run_peon '{"hook_event_name":"PreToolUse","cwd":"/tmp/project","session_id":"working"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  rm -f "$TEST_DIR/afplay.log"
}

assert_permission_was_handled() {
  [ "$PEON_EXIT" -eq 0 ] || return 1
  afplay_was_called || return 1
  [[ "$(afplay_sound)" == *"/sounds/Perm"* ]] || return 1
  [[ "$(cat "$TEST_DIR/.tab_title")" == *"needs approval"* ]]
}

@test "fast path cannot mistake nested tool event for root PermissionRequest" {
  warm_working_session
  run_peon '{"hook_event_name":"PermissionRequest","session_id":"working","cwd":"/tmp/project","tool_name":"Bash","tool_input":{"hook_event_name":"PreToolUse"}}'
  assert_permission_was_handled
}

@test "fast path ignores nested identity before root event and session fields" {
  warm_working_session
  run_peon '{"tool_input":{"hook_event_name":"PreToolUse","session_id":"working"},"hook_event_name":"PermissionRequest","session_id":"actual","cwd":"/tmp/project","tool_name":"Bash"}'
  assert_permission_was_handled
}

@test "fast path falls back for escaped root identity keys" {
  warm_working_session
  run_peon '{"hook\u005fevent_name":"PermissionRequest","session_id":"working","cwd":"/tmp/project","tool_name":"Bash","tool_input":{"hook_event_name":"PreToolUse"}}'
  assert_permission_was_handled
}

@test "fast path does not accept an earlier duplicate root event key" {
  warm_working_session
  run_peon '{"hook_event_name":"PreToolUse","session_id":"working","hook_event_name":"PermissionRequest","cwd":"/tmp/project","tool_name":"Bash"}'
  assert_permission_was_handled
}

@test "canonical repeated tools need no external command including large responses" {
  warm_working_session
  before=$(cksum < "$TEST_DIR/.state.json")
  payload='{"session_id":"working","cwd":"/tmp/project","hook_event_name":"PostToolUse","tool_response":{"output":"'
  padding=$(printf '%100000s' '')
  payload="$payload$padding\"}}"
  PATH=/nonexistent /bin/bash "$PEON_SH" <<< "$payload" 2> "$TEST_DIR/fast.stderr"
  [ "$?" -eq 0 ]
  [ ! -s "$TEST_DIR/fast.stderr" ]
  [ "$(cksum < "$TEST_DIR/.state.json")" = "$before" ]
}

setup_default_data_with_hostile_tmp() {
  export HOME="$TEST_DIR/home" CLAUDE_CONFIG_DIR="$TEST_DIR/claude-config"
  export TMPDIR="$TEST_DIR/shared-tmp"
  mkdir -p "$HOME" "$CLAUDE_CONFIG_DIR/hooks/peon-ping" "$TMPDIR"
  chmod 700 "$HOME"
  default_data="$CLAUDE_CONFIG_DIR/hooks/peon-ping"
  cp -R "$TEST_DIR/packs" "$default_data/packs"
  cp "$TEST_DIR/config.json" "$default_data/config.json"
  printf '{}\n' > "$default_data/.state.json"
  hostile="$TMPDIR/peon-ping-working-${UID:-0}"
  mkdir "$hostile"
  chmod 777 "$hostile"
  printf 'benign content must survive\n' > "$TEST_DIR/benign"
  ln -s "$TEST_DIR/benign" "$hostile/working"
  unset CLAUDE_PEON_DIR
}

@test "slow working marker creation cannot truncate a shared-TMPDIR symlink target" {
  setup_default_data_with_hostile_tmp
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/project","session_id":"working"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  [ "$(cat "$TEST_DIR/benign")" = 'benign content must survive' ]
}

@test "fast path never trusts markers precreated in shared TMPDIR" {
  setup_default_data_with_hostile_tmp
  before=$(cksum < "$default_data/.state.json")
  run_peon '{"hook_event_name":"PreToolUse","cwd":"/tmp/project","session_id":"working"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  [ "$(cksum < "$default_data/.state.json")" != "$before" ]
}

@test "an explicit data-dir marker symlink cannot truncate its target" {
  mkdir "$TEST_DIR/.working"
  printf 'benign content must survive\n' > "$TEST_DIR/benign"
  ln -s "$TEST_DIR/benign" "$TEST_DIR/.working/working"
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/project","session_id":"working"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  [ "$(cat "$TEST_DIR/benign")" = 'benign content must survive' ]
}

@test "nested session id cannot borrow a working marker for a different root session" {
  warm_working_session
  run_peon '{"hook_event_name":"PreToolUse","tool_input":{"session_id":"working"},"session_id":"actual","cwd":"/tmp/actualproject"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  [[ "$(cat "$TEST_DIR/.tab_title")" == *"actualproject: working"* ]]
}

@test "an unvalidated public marker directory is never trusted" {
  mkdir -p "$TEST_DIR/.working/working"
  chmod 777 "$TEST_DIR/.working"
  run_peon '{"hook_event_name":"PreToolUse","cwd":"/tmp/actualproject","session_id":"working"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  [[ "$(cat "$TEST_DIR/.tab_title")" == *"actualproject: working"* ]]
}

@test "a marker storage directory symlink is not followed on the slow path" {
  mkdir "$TEST_DIR/benign-dir"
  ln -s "$TEST_DIR/benign-dir" "$TEST_DIR/.working"
  run_peon '{"hook_event_name":"UserPromptSubmit","cwd":"/tmp/project","session_id":"working"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  [ ! -e "$TEST_DIR/benign-dir/working" ]
}

@test "default private-cache repeated tools still need no external commands" {
  setup_default_data_with_hostile_tmp
  run_peon '{"session_id":"working","cwd":"/tmp/project","hook_event_name":"PreToolUse"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  PATH=/nonexistent /bin/bash "$PEON_SH" <<< '{"session_id":"working","cwd":"/tmp/project","hook_event_name":"PostToolUse"}' 2> "$TEST_DIR/fast.stderr"
  [ "$?" -eq 0 ]
  [ ! -s "$TEST_DIR/fast.stderr" ]
}

@test "duplicate root session keys cannot borrow an earlier working marker" {
  warm_working_session
  run_peon '{"hook_event_name":"PreToolUse","session_id":"working","session_id":"actual","cwd":"/tmp/actualproject"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  [[ "$(cat "$TEST_DIR/.tab_title")" == *"actualproject: working"* ]]
}

@test "default private cache does not share working markers between installs" {
  setup_default_data_with_hostile_tmp
  run_peon '{"session_id":"working","cwd":"/tmp/project","hook_event_name":"PreToolUse"}'
  [ "$PEON_EXIT" -eq 0 ] || return 1
  mkdir "$TEST_DIR/other-install"
  cp "$PEON_SH" "$TEST_DIR/other-install/peon.sh"
  # A different invoked install must take its full path rather than borrowing
  # the first one's marker. Its external commands are unavailable in this probe.
  PATH=/nonexistent /bin/bash "$TEST_DIR/other-install/peon.sh" <<< '{"session_id":"working","cwd":"/tmp/project","hook_event_name":"PostToolUse"}' 2> "$TEST_DIR/other.stderr" || true
  [ -s "$TEST_DIR/other.stderr" ]
}
