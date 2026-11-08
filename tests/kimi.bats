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
  # Named like the real one: the event list --install picks depends on it.
  export KIMI_DIR="$TEST_DIR/.kimi-code"
  export KIMI_CONFIG="$KIMI_DIR/config.toml"
  mkdir -p "$KIMI_DIR"

  # --install/--uninstall reap the old watcher's LaunchAgent out of $HOME, so
  # the management flags run against a throwaway one.
  KIMI_FAKE_HOME="$TEST_DIR/fake_home"
  mkdir -p "$KIMI_FAKE_HOME/Library/LaunchAgents"
  LEGACY_PLIST="$KIMI_FAKE_HOME/Library/LaunchAgents/com.peonping.kimi-adapter.plist"
  LEGACY_PIDFILE="$TEST_DIR/.kimi-adapter.pid"
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
  run env HOME="$KIMI_FAKE_HOME" bash "$KIMI_SH" "$1"
}

# Stand in for the watcher daemon this adapter replaced. Up to v2.37.0 its
# --install ran `nohup bash "$0" &` from $PEON_DIR/adapters/kimi.sh and wrote
# $! to the pidfile, so start a stub the same way from the same path.
start_legacy_watcher() {
  mkdir -p "$TEST_DIR/adapters"
  printf '#!/bin/bash\nsleep 30\n' > "$TEST_DIR/adapters/kimi.sh"
  nohup bash "$TEST_DIR/adapters/kimi.sh" >/dev/null 2>&1 &
  LEGACY_PID=$!
  echo "$LEGACY_PID" > "$LEGACY_PIDFILE"
}

# Run a script as an unrelated background job whose pid the stale pidfile
# then points at.
start_unrelated_job() {
  printf '#!/bin/bash\nsleep 30\n' > "$1"
  bash "$1" >/dev/null 2>&1 &
  UNRELATED_PID=$!
  echo "$UNRELATED_PID" > "$LEGACY_PIDFILE"
}

# The pid is still a live process (not reaped, not a zombie).
pid_is_alive() {
  local state
  state="$(ps -p "$1" -o stat= 2>/dev/null | tr -d ' ')"
  [ -n "$state" ] && [ "${state:0:1}" != "Z" ]
}

# A killed child sticks around as a zombie until it is waited on, so kill -0
# would still succeed. Read the process state instead.
legacy_watcher_is_gone() {
  local state
  state="$(ps -p "$LEGACY_PID" -o stat= 2>/dev/null | tr -d ' ')"
  [ -z "$state" ] || [ "${state:0:1}" = "Z" ]
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
  # Dropping the daemon dropped the fswatch/inotify-tools requirement. The
  # pidfile survives only as something to clean up -- see stop_legacy_watcher.
  run grep -E "fswatch|inotifywait|wire\.jsonl" "$KIMI_SH"
  [ "$status" -ne 0 ]
  grep -q "stop_legacy_watcher" "$KIMI_SH"
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

# Install twice and uninstall a config seeded with printf-format $1, checking
# that --install leaves every byte ahead of the block alone and that --uninstall
# gives back the original file exactly.
assert_round_trip() {
  printf "$1" > "$KIMI_CONFIG"
  cp "$KIMI_CONFIG" "$TEST_DIR/config.orig"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  head -c "$(wc -c < "$TEST_DIR/config.orig")" "$KIMI_CONFIG" > "$TEST_DIR/config.head"
  run cmp "$TEST_DIR/config.head" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]

  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]
}

@test "--install and --uninstall keep whitespace inside a multiline value" {
  assert_round_trip 'prompt = """\nfirst\n    \n\t\nlast\n"""\n'
}

@test "--install and --uninstall keep a config without a final newline" {
  assert_round_trip 'default_model = "x"'
}

@test "--install and --uninstall keep a CRLF blank separator" {
  assert_round_trip 'default_model = "x"\r\n\r\n'
}

@test "--install and --uninstall keep a CRLF config without a final newline" {
  assert_round_trip 'a = 1\r\nb = 2'
}

@test "--install and --uninstall keep mixed line endings" {
  assert_round_trip 'a = 1\r\nprompt = """\nx\n"""\n'
}

@test "--install and --uninstall keep several trailing blank lines" {
  assert_round_trip 'a = 1\n\n\n'
}

@test "--install and --uninstall keep an empty config empty" {
  assert_round_trip ''
}

@test "--install writes the block in the config's own CRLF line endings" {
  printf 'a = 1\r\n' > "$KIMI_CONFIG"
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  # Every line of the file ends in CRLF.
  [ "$(grep -c $'\r$' "$KIMI_CONFIG")" -eq "$(wc -l < "$KIMI_CONFIG")" ]
}

@test "--install records the newline it adds to an unterminated last line" {
  printf 'a = 1' > "$KIMI_CONFIG"
  run_kimi_flag --install
  grep -qxF '# peon-ping Kimi hooks begin (newline added at end of file)' "$KIMI_CONFIG"
}

@test "--uninstall keeps the added newline when the user wrote after the block" {
  printf 'a = 1' > "$KIMI_CONFIG"
  run_kimi_flag --install
  printf 'b = 2\n' >> "$KIMI_CONFIG"
  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]
  [ "$(cat "$KIMI_CONFIG")" = $'a = 1\nb = 2' ]
}

@test "--install and --uninstall refuse an unterminated block and leave it alone" {
  printf 'a = 1\n# peon-ping Kimi hooks begin\nb = 2\n' > "$KIMI_CONFIG"
  cp "$KIMI_CONFIG" "$TEST_DIR/config.orig"

  run_kimi_flag --install
  [ "$status" -ne 0 ]
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]

  run_kimi_flag --uninstall
  [ "$status" -ne 0 ]
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]
}

@test "--install and --uninstall fail when the config cannot be written" {
  # A failed write used to report success and exit 0, after which uninstall.sh
  # deleted the adapter the hooks still ran.
  [ "$(id -u)" -ne 0 ] || skip "root ignores file permissions"
  seed_config 'a = 1'
  run_kimi_flag --install
  cp "$KIMI_CONFIG" "$TEST_DIR/config.installed"
  chmod 444 "$KIMI_CONFIG"

  run_kimi_flag --uninstall
  [ "$status" -eq 1 ]
  [[ "$output" == *"Could not write"* ]]
  [[ "$output" != *"Removed peon-ping hooks"* ]]
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.installed"
  [ "$status" -eq 0 ]

  run_kimi_flag --install
  [ "$status" -eq 1 ]
  [[ "$output" != *"registered for"* ]]
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.installed"
  [ "$status" -eq 0 ]
  chmod 644 "$KIMI_CONFIG"
}

@test "--uninstall and --status fail when the config cannot be read" {
  # grep exits 2, not 1, on a file it cannot read; taking that for "no block"
  # reported nothing to remove and let uninstall.sh delete the adapter.
  [ "$(id -u)" -ne 0 ] || skip "root ignores file permissions"
  seed_config 'a = 1'
  run_kimi_flag --install
  cp "$KIMI_CONFIG" "$TEST_DIR/config.installed"
  chmod 000 "$KIMI_CONFIG"

  run_kimi_flag --uninstall
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot read Kimi config"* ]]
  [[ "$output" != *"Nothing to remove"* ]]

  run_kimi_flag --status
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot read Kimi config"* ]]

  chmod 644 "$KIMI_CONFIG"
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.installed"
  [ "$status" -eq 0 ]
}

@test "--install refuses a config it cannot read instead of writing over it" {
  # Readable as empty, it would have been replaced by the block alone.
  [ "$(id -u)" -ne 0 ] || skip "root ignores file permissions"
  seed_config 'default_model = "x"
'
  cp "$KIMI_CONFIG" "$TEST_DIR/config.orig"
  chmod 200 "$KIMI_CONFIG"

  run_kimi_flag --install
  [ "$status" -eq 1 ]
  [[ "$output" == *"Cannot read Kimi config"* ]]
  [[ "$output" != *"registered for"* ]]

  chmod 644 "$KIMI_CONFIG"
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]
}

@test "--install and --uninstall keep the config's mode and symlink" {
  mkdir -p "$TEST_DIR/dotfiles"
  printf 'a = 1\n' > "$TEST_DIR/dotfiles/kimi.toml"
  chmod 640 "$TEST_DIR/dotfiles/kimi.toml"
  ln -s "$TEST_DIR/dotfiles/kimi.toml" "$KIMI_CONFIG"

  run_kimi_flag --install
  [ -L "$KIMI_CONFIG" ]
  grep -qF "# peon-ping Kimi hooks begin" "$TEST_DIR/dotfiles/kimi.toml"
  run_kimi_flag --uninstall
  [ -L "$KIMI_CONFIG" ]
  [ "$(cat "$TEST_DIR/dotfiles/kimi.toml")" = "a = 1" ]
  perms=$(stat -c '%a' "$TEST_DIR/dotfiles/kimi.toml" 2>/dev/null || stat -f '%Lp' "$TEST_DIR/dotfiles/kimi.toml")
  [ "$perms" = "640" ]
}

# kimi-cli 1.28.0-1.52.0 validates `event` against thirteen names and refuses
# to load a config naming any other; PermissionRequest/PermissionResult are
# Kimi Code only.
assert_kimi_cli_events() {
  [ "$(grep -c '^event = ' "$1")" -eq 9 ]
  run grep -E '^event = "Permission(Request|Result)"' "$1"
  [ "$status" -ne 0 ]
  while read -r ev; do
    case "$ev" in
      PreToolUse|PostToolUse|PostToolUseFailure|UserPromptSubmit|Stop|StopFailure|\
      SessionStart|SessionEnd|SubagentStart|SubagentStop|PreCompact|PostCompact|Notification) ;;
      *) echo "kimi-cli rejects event $ev"; return 1 ;;
    esac
  done < <(sed -n 's/^event = "\(.*\)"$/\1/p' "$1")
}

@test "--install registers the Permission events for Kimi Code" {
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  grep -qx 'event = "PermissionRequest"' "$KIMI_CONFIG"
  grep -qx 'event = "PermissionResult"' "$KIMI_CONFIG"
  [ "$(grep -c '^event = ' "$KIMI_CONFIG")" -eq 11 ]
}

@test "--install leaves Kimi Code only events out of a kimi-cli config" {
  export KIMI_DIR="$TEST_DIR/.kimi" KIMI_CONFIG="$TEST_DIR/.kimi/config.toml"
  mkdir -p "$KIMI_DIR"
  printf 'default_model = ""\n' > "$KIMI_CONFIG"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [[ "$output" == *"registered for kimi-cli"* ]]
  [[ "$output" == *"Left out PermissionRequest PermissionResult"* ]]
  assert_kimi_cli_events "$KIMI_CONFIG"
}

@test "--install rewrites a kimi-cli block that still names Permission events" {
  # An install from before this fix left a config kimi-cli cannot load;
  # re-running --install has to repair it.
  export KIMI_DIR="$TEST_DIR/.kimi" KIMI_CONFIG="$TEST_DIR/.kimi/config.toml"
  mkdir -p "$KIMI_DIR"
  printf '%s\n' 'a = 1' '' '# peon-ping Kimi hooks begin' '' '[[hooks]]' \
    'event = "PermissionRequest"' 'command = "x"' '' '# peon-ping Kimi hooks end' > "$KIMI_CONFIG"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  assert_kimi_cli_events "$KIMI_CONFIG"
  [ "$(grep -c 'peon-ping Kimi hooks begin' "$KIMI_CONFIG")" -eq 1 ]
}

@test "--install treats a config under KIMI_CODE_HOME as Kimi Code" {
  export KIMI_CODE_HOME="$TEST_DIR/custom-kimi-home"
  export KIMI_DIR="$KIMI_CODE_HOME" KIMI_CONFIG="$KIMI_CODE_HOME/config.toml"
  mkdir -p "$KIMI_DIR"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [ "$(grep -c '^event = ' "$KIMI_CONFIG")" -eq 11 ]
}

@test "--install falls back to the events both Kimis accept for an unknown home" {
  export KIMI_DIR="$TEST_DIR/somewhere" KIMI_CONFIG="$TEST_DIR/somewhere/config.toml"
  mkdir -p "$KIMI_DIR"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  assert_kimi_cli_events "$KIMI_CONFIG"
}

# What Kimi Code's kimi-cli migration leaves behind: hooks re-serialized out of
# ~/.kimi/config.toml, our block markers gone.
seed_migrated_hooks() {
  cat > "$KIMI_CONFIG" <<TOML
default_model = "k2"

[[hooks]]
event = "Stop"
command = "CLAUDE_PEON_DIR='$TEST_DIR' bash '$TEST_DIR/adapters/kimi.sh'"
timeout = 10

[[hooks]]
event = "SessionStart"
command = "CLAUDE_PEON_DIR='$TEST_DIR' bash '$TEST_DIR/adapters/kimi.sh'"
timeout = 10
TOML
}

@test "--install warns about adapter hooks outside its block and leaves them alone" {
  seed_migrated_hooks
  cp "$KIMI_CONFIG" "$TEST_DIR/config.orig"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 hook command(s) outside the peon-ping block"* ]]
  # Only the marked block was added; the unmarked hooks are byte-identical.
  head -c "$(wc -c < "$TEST_DIR/config.orig")" "$KIMI_CONFIG" > "$TEST_DIR/config.head"
  run cmp "$TEST_DIR/config.head" "$TEST_DIR/config.orig"
  [ "$status" -eq 0 ]
}

@test "--status and --uninstall warn about adapter hooks outside the block" {
  seed_migrated_hooks
  run_kimi_flag --install

  run_kimi_flag --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"outside the peon-ping block"* ]]

  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"outside the peon-ping block"* ]]
  [ "$(grep -c 'adapters/kimi.sh' "$KIMI_CONFIG")" -eq 2 ]
}

@test "--uninstall warns about unmarked adapter hooks even with no block to remove" {
  seed_migrated_hooks
  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to remove"* ]]
  [[ "$output" == *"2 hook command(s) outside the peon-ping block"* ]]
}

@test "the unmanaged-hook check sees a Windows adapter path too" {
  printf '%s\n' '[[hooks]]' 'event = "Stop"' \
    "command = 'powershell -NoProfile -File \"C:\\peon\\adapters\\kimi.ps1\"'" > "$KIMI_CONFIG"
  run_kimi_flag --install
  [[ "$output" == *"1 hook command(s) outside the peon-ping block"* ]]
}

@test "--install does not warn when the only adapter hooks are its own" {
  printf 'default_model = "k2"\n# bash adapters/kimi.sh in a comment is not a hook\n' > "$KIMI_CONFIG"
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  run_kimi_flag --install
  [[ "$output" != *"outside the peon-ping block"* ]]
  run_kimi_flag --status
  [[ "$output" != *"outside the peon-ping block"* ]]
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
# Migration off the watcher daemon this adapter replaced
# ============================================================

@test "--install unloads the LaunchAgent the watcher daemon left behind" {
  # Its plist has KeepAlive=true and runs this script with no arguments, which
  # is now hook mode: it would read an empty stdin, exit 0, and be restarted
  # every ten seconds forever.
  : > "$LEGACY_PLIST"
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [ ! -f "$LEGACY_PLIST" ]
  grep -qF "# peon-ping Kimi hooks begin" "$KIMI_CONFIG"
}

@test "--install stops the watcher daemon and clears its pidfile" {
  start_legacy_watcher
  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped the old Kimi watcher daemon"* ]]
  [ ! -f "$LEGACY_PIDFILE" ]
  legacy_watcher_is_gone
}

@test "--uninstall stops the watcher daemon too" {
  : > "$LEGACY_PLIST"
  start_legacy_watcher
  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$LEGACY_PLIST" ]
  [ ! -f "$LEGACY_PIDFILE" ]
  legacy_watcher_is_gone
}

@test "--stop-watcher stops the watcher daemon and leaves the config alone" {
  printf 'a = 1\n' > "$KIMI_CONFIG"
  run_kimi_flag --install
  cp "$KIMI_CONFIG" "$TEST_DIR/config.installed"
  start_legacy_watcher

  run_kimi_flag --stop-watcher
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped the old Kimi watcher daemon"* ]]
  legacy_watcher_is_gone
  run cmp "$KIMI_CONFIG" "$TEST_DIR/config.installed"
  [ "$status" -eq 0 ]
}

@test "a stale pidfile is cleared without killing whatever reused the pid" {
  # The pid outlives the process that wrote it, so a pid now belonging to
  # something else must be left alone.
  sleep 30 &
  unrelated_pid=$!
  echo "$unrelated_pid" > "$LEGACY_PIDFILE"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [ ! -f "$LEGACY_PIDFILE" ]
  kill -0 "$unrelated_pid"
  kill "$unrelated_pid" 2>/dev/null || true
}

@test "a stale pidfile does not kill an unrelated shell job with kimi in its name" {
  start_unrelated_job "$TEST_DIR/kimi-unrelated-job.sh"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [ ! -f "$LEGACY_PIDFILE" ]
  pid_is_alive "$UNRELATED_PID"
  [[ "$output" != *"Stopped the old Kimi watcher daemon"* ]]
  kill "$UNRELATED_PID" 2>/dev/null || true
}

@test "a stale pidfile does not kill a kimi.sh that is not this install's adapter" {
  mkdir -p "$TEST_DIR/elsewhere"
  start_unrelated_job "$TEST_DIR/elsewhere/kimi.sh"

  run_kimi_flag --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$LEGACY_PIDFILE" ]
  pid_is_alive "$UNRELATED_PID"
  [[ "$output" == *"could not be verified"* ]]
  kill "$UNRELATED_PID" 2>/dev/null || true
}

@test "a stale pidfile does not kill the adapter run with arguments" {
  # Only the watcher ran with no arguments; anything with a flag after the
  # path is some other invocation that just happens to share the script.
  mkdir -p "$TEST_DIR/adapters"
  printf '#!/bin/bash\nsleep 30\n' > "$TEST_DIR/adapters/kimi.sh"
  bash "$TEST_DIR/adapters/kimi.sh" --status >/dev/null 2>&1 &
  other_pid=$!
  echo "$other_pid" > "$LEGACY_PIDFILE"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  pid_is_alive "$other_pid"
  kill "$other_pid" 2>/dev/null || true
}

@test "a stale pidfile does not kill a program handed 'bash <adapter>' as arguments" {
  # ps joins argv with spaces, so "python3 -c ... /usr/bin/bash <adapter>"
  # contains "/bash <adapter>" even though bash is just an argument here.
  mkdir -p "$TEST_DIR/adapters"
  printf '#!/bin/bash\nsleep 30\n' > "$TEST_DIR/adapters/kimi.sh"
  python3 -c 'import time; time.sleep(30)' /usr/bin/bash "$TEST_DIR/adapters/kimi.sh" &
  other_pid=$!
  echo "$other_pid" > "$LEGACY_PIDFILE"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [[ "$output" != *"Stopped the old Kimi watcher daemon"* ]]
  pid_is_alive "$other_pid"
  kill "$other_pid" 2>/dev/null || true
}

@test "--install stops a watcher started from a relative adapter path" {
  # `bash adapters/kimi.sh --install` from a checkout left "bash adapters/kimi.sh"
  # as the watcher's command line. Resolving it needs /proc/<pid>/cwd.
  [ -d /proc/self ] || skip "no /proc to resolve the watcher's cwd"
  mkdir -p "$TEST_DIR/adapters"
  printf '#!/bin/bash\nsleep 30\n' > "$TEST_DIR/adapters/kimi.sh"
  cd "$TEST_DIR"
  nohup bash adapters/kimi.sh >/dev/null 2>&1 &
  LEGACY_PID=$!
  cd - >/dev/null
  echo "$LEGACY_PID" > "$LEGACY_PIDFILE"

  run_kimi_flag --install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped the old Kimi watcher daemon"* ]]
  sleep 0.2
  run pid_is_alive "$LEGACY_PID"
  [ "$status" -ne 0 ]
}

@test "the adapter resolves its install dir from its own path" {
  # Copied into an install root that is not ~/.claude (--local, --kimi, a custom
  # CLAUDE_CONFIG_DIR) and run without CLAUDE_PEON_DIR, it still has to find
  # peon.sh -- and bake the right dir into the hook command it registers.
  root="$TEST_DIR/custom_root"
  mkdir -p "$root/adapters"
  cp "$KIMI_SH" "$root/adapters/kimi.sh"
  ln -sf "$PEON_SH" "$root/peon.sh"

  run env -u CLAUDE_PEON_DIR HOME="$KIMI_FAKE_HOME" bash "$root/adapters/kimi.sh" --install
  [ "$status" -eq 0 ]
  grep -qF "CLAUDE_PEON_DIR='$root'" "$KIMI_CONFIG"
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
