#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  export HOME="$TEST_DIR/home" PEON_PLATFORM=mac
  unset CLAUDE_PEON_DIR TMUX
  mkdir -p "$HOME" "$TEST_DIR/package/libexec" "$TEST_DIR/package/bin" "$TEST_DIR/launcher-bin"
  chmod 700 "$HOME"
  cp "$PEON_SH" "$TEST_DIR/package/libexec/peon.sh"
  # Homebrew's bin/peon wrapper delegates to one shared script without setting
  # CLAUDE_PEON_DIR. The package has no packs, so the real profile resolver runs.
  printf '#!/bin/bash\nexec bash "%s" "$@"\n' "$TEST_DIR/package/libexec/peon.sh" > "$TEST_DIR/package/bin/peon"
  PEON_SH="$TEST_DIR/package/bin/peon"
  ln -s /bin/bash "$TEST_DIR/launcher-bin/bash"
  profile_a="$HOME/profile-a"
  profile_b="$HOME/profile-b"
  data_a="$profile_a/hooks/peon-ping"
  data_b="$profile_b/hooks/peon-ping"
  for data in "$data_a" "$data_b"; do
    mkdir -p "$data"
    cp -R "$TEST_DIR/packs" "$data/packs"
    "$PEON_PY" - "$TEST_DIR/config.json" "$data/config.json" <<'PY'
import json, sys
config = json.load(open(sys.argv[1]))
config['desktop_notifications'] = False
with open(sys.argv[2], 'w') as target:
    json.dump(config, target)
PY
    printf '{}\n' > "$data/.state.json"
  done
  # These external sinks must use the isolated test root even though the real
  # runtime is deliberately launched without an explicit CLAUDE_PEON_DIR.
  printf '#!/bin/bash\nprintf "%%s\\n" "$*" >> "$TEST_DIR/afplay.log"\n' > "$MOCK_BIN/afplay"
  printf '#!/bin/bash\nprintf "Safari\\n"\n' > "$MOCK_BIN/osascript"
}

teardown() {
  teardown_test_env
}

@test "shared launcher keeps resumed-session working markers separate between profiles" {
  for profile in "$profile_a" "$profile_b"; do
    run env CLAUDE_CONFIG_DIR="$profile" bash "$PEON_SH" status --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"config: $profile/hooks/peon-ping/config.json"* ]] || return 1
  done

  export CLAUDE_CONFIG_DIR="$profile_b"
  run_peon '{"hook_event_name":"PermissionRequest","session_id":"resumed-session","cwd":"/tmp/profile-b-project","tool_name":"Bash","tool_input":{"command":"pwd"}}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_b/.tab_title")" == *"profile-b-project: needs approval"* ]] || return 1
  before_b=$(cksum < "$data_b/.state.json")

  export CLAUDE_CONFIG_DIR="$profile_a"
  run_peon '{"hook_event_name":"PreToolUse","session_id":"resumed-session","cwd":"/tmp/profile-a-project"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_a/.tab_title")" == *"profile-a-project: working"* ]] || return 1
  before_a=$(cksum < "$data_a/.state.json")

  export CLAUDE_CONFIG_DIR="$profile_b"
  run_peon '{"hook_event_name":"PreToolUse","session_id":"resumed-session","cwd":"/tmp/profile-b-project"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_b/.tab_title")" == *"profile-b-project: working"* ]] || return 1
  [ "$(cksum < "$data_b/.state.json")" != "$before_b" ]
  [ "$(cksum < "$data_a/.state.json")" = "$before_a" ]

  # Invalidate A's marker while B remains working, then check the reverse route.
  export CLAUDE_CONFIG_DIR="$profile_a"
  run_peon '{"hook_event_name":"PermissionRequest","session_id":"resumed-session","cwd":"/tmp/profile-a-project","tool_name":"Bash","tool_input":{"command":"pwd"}}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_a/.tab_title")" == *"profile-a-project: needs approval"* ]] || return 1
  before_a=$(cksum < "$data_a/.state.json")
  before_b=$(cksum < "$data_b/.state.json")
  run_peon '{"hook_event_name":"PreToolUse","session_id":"resumed-session","cwd":"/tmp/profile-a-project"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_a/.tab_title")" == *"profile-a-project: working"* ]] || return 1
  [ "$(cksum < "$data_a/.state.json")" != "$before_a" ]
  [ "$(cksum < "$data_b/.state.json")" = "$before_b" ]

  # Only bash is available for the wrapper's exec. Repeats in either profile
  # must need no external runtime commands and must not rewrite title or state.
  for profile in "$profile_a" "$profile_b"; do
    data="$profile/hooks/peon-ping"
    before_state=$(cksum < "$data/.state.json")
    before_title=$(cksum < "$data/.tab_title")
    CLAUDE_CONFIG_DIR="$profile" PATH="$TEST_DIR/launcher-bin" /bin/bash "$PEON_SH" <<< '{"hook_event_name":"PostToolUse","session_id":"resumed-session","cwd":"/tmp/project"}' 2> "$TEST_DIR/fast.stderr"
    [ "$?" -eq 0 ]
    [ ! -s "$TEST_DIR/fast.stderr" ]
    [ "$(cksum < "$data/.state.json")" = "$before_state" ]
    [ "$(cksum < "$data/.tab_title")" = "$before_title" ]
  done
}

@test "packless explicit override cannot lend a working marker across fallback profiles" {
  export CLAUDE_PEON_DIR="$TEST_DIR/packless-override"
  mkdir "$CLAUDE_PEON_DIR"
  cp "$TEST_DIR/package/libexec/peon.sh" "$CLAUDE_PEON_DIR/peon.sh"
  for profile in "$profile_a" "$profile_b"; do
    run env CLAUDE_CONFIG_DIR="$profile" bash "$PEON_SH" status --verbose
    [ "$status" -eq 0 ]
    [[ "$output" == *"config: $profile/hooks/peon-ping/config.json"* ]] || return 1
  done

  export CLAUDE_CONFIG_DIR="$profile_b"
  run_peon '{"hook_event_name":"PermissionRequest","session_id":"resumed-session","cwd":"/tmp/profile-b-project","tool_name":"Bash","tool_input":{"command":"pwd"}}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_b/.tab_title")" == *"profile-b-project: needs approval"* ]] || return 1
  before_b=$(cksum < "$data_b/.state.json")

  export CLAUDE_CONFIG_DIR="$profile_a"
  run_peon '{"hook_event_name":"PreToolUse","session_id":"resumed-session","cwd":"/tmp/profile-a-project"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_a/.tab_title")" == *"profile-a-project: working"* ]] || return 1
  before_a=$(cksum < "$data_a/.state.json")

  export CLAUDE_CONFIG_DIR="$profile_b"
  run_peon '{"hook_event_name":"PreToolUse","session_id":"resumed-session","cwd":"/tmp/profile-b-project"}'
  [ "$PEON_EXIT" -eq 0 ]
  [[ "$(cat "$data_b/.tab_title")" == *"profile-b-project: working"* ]] || return 1
  [ "$(cksum < "$data_b/.state.json")" != "$before_b" ]
  [ "$(cksum < "$data_a/.state.json")" = "$before_a" ]
}
