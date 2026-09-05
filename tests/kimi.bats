#!/usr/bin/env bats
#
# Kimi Code drives peon-ping through its own hook system: `[[hooks]]` entries in
# ~/.kimi-code/config.toml run a command and deliver the event as JSON on stdin.
# The adapter is therefore an installer plus a stdin forwarder -- there is no
# watcher daemon, no pidfile and no wire.jsonl tailing any more.

load setup.bash

setup() {
  setup_test_env

  KIMI_SH="${PEON_SH%/peon.sh}/adapters/kimi.sh"

  # The adapter resolves peon.sh via CLAUDE_PEON_DIR.
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"

  # A Kimi home of our own so --install never touches a real ~/.kimi-code.
  export KIMI_DIR="$TEST_DIR/kimi_home"
  export KIMI_CONFIG="$KIMI_DIR/config.toml"
  mkdir -p "$KIMI_DIR"
}

teardown() {
  teardown_test_env
}

# Feed one Kimi hook event to the adapter on stdin.
run_kimi() {
  export PEON_TEST=1
  echo "$1" | bash "$KIMI_SH" 2>"$TEST_DIR/stderr.log"
  KIMI_EXIT=$?
  KIMI_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  sleep 0.3
}

# Run a management flag (--install / --uninstall / --status).
run_kimi_flag() {
  run bash "$KIMI_SH" "$1"
}

seed_config() {
  printf '%s' "$1" > "$KIMI_CONFIG"
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$KIMI_SH"
  [ "$status" -eq 0 ]
}

@test "adapter no longer needs a filesystem watcher" {
  # Dropping the daemon dropped the fswatch/inotify-tools requirement.
  run grep -E "fswatch|inotifywait|wire\.jsonl|kimi-adapter\.pid" "$KIMI_SH"
  [ "$status" -ne 0 ]
}

# ============================================================
# --install / --uninstall / --status
# ============================================================

@test "--install writes a marked block with every registered event" {
  run_kimi_flag --install
  [ "$status" -eq 0 ]

  grep -qF "# peon-ping Kimi hooks begin" "$KIMI_CONFIG"
  grep -qF "# peon-ping Kimi hooks end" "$KIMI_CONFIG"
  for ev in SessionStart SessionEnd UserPromptSubmit Stop StopFailure \
            PermissionRequest PermissionResult PostToolUseFailure \
            SubagentStart SubagentStop PreCompact; do
    grep -qF "event = \"$ev\"" "$KIMI_CONFIG"
  done
}

@test "--install leaves the per-tool-call and no-category events alone" {
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  for ev in PreToolUse PostToolUse PostCompact Interrupt Notification; do
    run grep -qF "event = \"$ev\"" "$KIMI_CONFIG"
    [ "$status" -ne 0 ]
  done
}

@test "--install shell-quotes the paths so a directory with a space still runs" {
  # Kimi spawns the hook with Node's `shell: true`, i.e. `sh -c "<command>"`.
  spaced="$TEST_DIR/peon dir"
  mkdir -p "$spaced/adapters"
  cp "$PEON_SH" "$spaced/peon.sh"
  cp "$KIMI_SH" "$spaced/adapters/kimi.sh"

  CLAUDE_PEON_DIR="$spaced" run bash "$spaced/adapters/kimi.sh" --install
  [ "$status" -eq 0 ]

  command_line=$(grep -m1 '^command = ' "$KIMI_CONFIG")
  [[ "$command_line" == *"'$spaced'"* ]]
  [[ "$command_line" == *"'$spaced/adapters/kimi.sh'"* ]]

  # The quoted command has to survive a trip through the shell.
  cmd=${command_line#command = \"}
  cmd=${cmd%\"}
  run sh -c "$cmd" <<<'{"hook_event_name":"Stop","session_id":"session_q1"}'
  [ "$status" -eq 0 ]
}

@test "--install keeps existing hooks and is idempotent" {
  seed_config 'default_model = "kimi-code/kimi-for-coding"
[[hooks]]
event = "PreToolUse"
command = "other-tool"
'
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  first=$(cat "$KIMI_CONFIG")

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [ "$(cat "$KIMI_CONFIG")" = "$first" ]

  grep -qF 'command = "other-tool"' "$KIMI_CONFIG"
}

@test "--uninstall restores the config byte for byte" {
  original='default_model = "x"
[[hooks]]
event = "PreToolUse"
'
  seed_config "$original"
  cp "$KIMI_CONFIG" "$TEST_DIR/config.orig"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]

  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]
}

@test "--uninstall keeps a blank line the config already ended with" {
  printf 'default_model = "x"\n\n' > "$KIMI_CONFIG"
  cp "$KIMI_CONFIG" "$TEST_DIR/config.orig"

  run_kimi_flag --install
  run_kimi_flag --uninstall

  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]
}

@test "--uninstall on a config without the block reports cleanly" {
  seed_config 'default_model = "x"
'
  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to remove"* ]]
}

@test "--status reports the registered event count" {
  run_kimi_flag --install
  run_kimi_flag --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"11 events"* ]]
}

@test "--status exits non-zero when nothing is registered" {
  seed_config 'default_model = "x"
'
  run_kimi_flag --status
  [ "$status" -eq 1 ]
  [[ "$output" == *"not registered"* ]]
}

@test "--install fails loudly when peon.sh is missing" {
  rm -f "$TEST_DIR/peon.sh"
  run_kimi_flag --install
  [ "$status" -eq 1 ]
  [[ "$output" == *"peon.sh not found"* ]]
}

@test "an unknown flag is rejected" {
  run bash "$KIMI_SH" --nope
  [ "$status" -eq 1 ]
}

# ============================================================
# Hook mode: event mapping
# ============================================================

@test "SessionStart plays a greeting sound" {
  run_kimi '{"hook_event_name":"SessionStart","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "Stop plays a completion sound" {
  run_kimi '{"hook_event_name":"Stop","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "PermissionRequest plays the input.required sound" {
  # The watcher had no input.required path at all; the hooks do.
  run_kimi '{"hook_event_name":"PermissionRequest","tool_name":"Bash","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "PreCompact plays the resource.limit sound" {
  run_kimi '{"hook_event_name":"PreCompact","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Limit"* ]]
}

@test "PostToolUseFailure plays the error sound" {
  run_kimi '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","error":"boom","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "StopFailure borrows the tool-failure path so a failed turn still errors" {
  run_kimi '{"hook_event_name":"StopFailure","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "PostToolUseFailure unwraps the error object Kimi 0.41 sends" {
  run_kimi '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","session_id":"session_s1","error":{"code":"internal","message":"Process exited with code 7\nCommand failed.","retryable":false}}'
  [ "$KIMI_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'kimi-s1', last
"
  afplay_was_called
}

@test "PermissionResult is forwarded but stays silent" {
  # It maps to PreToolUse, which only clears the 'needs approval' tab title.
  run_kimi '{"hook_event_name":"PermissionResult","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "per-tool-call and no-category events are dropped without a sound" {
  for ev in PreToolUse PostToolUse PostCompact Interrupt Notification; do
    run_kimi "{\"hook_event_name\":\"$ev\",\"session_id\":\"session_s1\"}"
    [ "$KIMI_EXIT" -eq 0 ]
    ! afplay_was_called
  done
}

# ============================================================
# Hook mode: payload shape and exit codes
# ============================================================

@test "session ids lose Kimi's session_ prefix and gain the kimi- one" {
  run_kimi '{"hook_event_name":"Stop","session_id":"session_9f3c1a2b-1eae","cwd":"/tmp/kimi-proj"}'
  [ "$KIMI_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'kimi-9f3c1a2b-1eae', last
assert last.get('cwd') == '/tmp/kimi-proj', last
"
}

@test "malformed stdin exits 0 so Kimi never reads it as a block" {
  # Kimi treats exit code 2 as 'block this operation' on UserPromptSubmit,
  # PreToolUse and Stop.
  run_kimi 'not json at all'
  [ "$KIMI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "a payload without hook_event_name exits 0 and stays silent" {
  run_kimi '{"session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "hook mode writes nothing to stdout" {
  # Kimi parses a hook's stdout as a decision document.
  export PEON_TEST=1
  output=$(echo '{"hook_event_name":"Stop","session_id":"session_s1"}' | bash "$KIMI_SH" 2>/dev/null)
  [ -z "$output" ]
}

@test "hook mode exits 0 when peon.sh is missing" {
  rm -f "$TEST_DIR/peon.sh"
  run_kimi '{"hook_event_name":"Stop","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
}

@test "paused state suppresses sounds" {
  touch "$TEST_DIR/.paused"
  run_kimi '{"hook_event_name":"Stop","session_id":"session_s1"}'
  [ "$KIMI_EXIT" -eq 0 ]
  ! afplay_was_called
}
