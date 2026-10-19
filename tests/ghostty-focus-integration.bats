#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  export PEON_PLATFORM=mac TERM_PROGRAM=ghostty
  export TEST_HOOK_TTY=ttys042 TEST_GHOSTTY_TTY=/dev/ttys042
  unset TMUX PEON_SESSION_TTY
  "$PEON_PY" - "$TEST_DIR/config.json" <<'PY'
import json, sys
path = sys.argv[1]
config = json.load(open(path))
config.update(desktop_notifications=True, notification_style='overlay',
              suppress_sound_when_tab_focused=False, terminal_tab_title=False,
              notification_all_screens=False)
json.dump(config, open(path, 'w'))
PY
  cp "$(dirname "$PEON_SH")/scripts/mac-overlay.js" "$TEST_DIR/scripts/mac-overlay.js"
  mv "$MOCK_BIN/osascript" "$MOCK_BIN/osascript-default"
  cat > "$MOCK_BIN/osascript" <<'SCRIPT'
#!/bin/bash
if [[ "$*" == *'Ghostty'* ]] && [[ "$*" == *'tty of'* ]]; then
  printf '%s' "$TEST_GHOSTTY_TTY"
else
  exec "${0%/*}/osascript-default" "$@"
fi
SCRIPT
  chmod +x "$MOCK_BIN/osascript"
  # Keep real process ancestry, supplying a controlled session TTY at the OS
  # boundary. The hook must discover/cache it itself; no session TTY is seeded.
  cat > "$MOCK_BIN/ps" <<'SCRIPT'
#!/bin/bash
printf '%s\n' "$*" >> "$TEST_DIR/ps.log"
case "$*" in
  '-A -o pid=,ppid=,tty=')
    /bin/ps -A -o pid=,ppid= | while read -r pid ppid; do
      printf '%s %s %s\n' "$pid" "$ppid" "${TEST_HOOK_TTY:-??}"
    done ;;
  *) exec /bin/ps "$@" ;;
esac
SCRIPT
  chmod +x "$MOCK_BIN/ps"
  printf 'Ghostty\n' > "$TEST_DIR/.mock_terminal_focused"
}

teardown() {
  teardown_test_env
}

@test "Ghostty focused desktop popup is suppressed with default sound-focus setting" {
  # Removing lazy TTY resolution from the focus branch makes this actual hook
  # dispatch an overlay: the default audio setting never does the early lookup.
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/project","session_id":"focused"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  [ ! -s "$TEST_DIR/overlay.log" ]
  [ "$(awk '$0 == "-A -o pid=,ppid=,tty=" {n++} END {print n+0}' "$TEST_DIR/ps.log")" -eq 1 ]
}

@test "Ghostty background terminal still receives its desktop popup" {
  export TEST_GHOSTTY_TTY=/dev/ttys099
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/project","session_id":"background"}'
  [ "$PEON_EXIT" -eq 0 ]
  afplay_was_called
  [ -s "$TEST_DIR/overlay.log" ]
}

@test "Ghostty unavailable session identity keeps desktop popup enabled" {
  export TEST_HOOK_TTY=
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/project","session_id":"unknown"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -s "$TEST_DIR/overlay.log" ]
}

@test "Ghostty unsupported TTY query keeps desktop popup enabled" {
  export TEST_GHOSTTY_TTY=
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/project","session_id":"unsupported"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -s "$TEST_DIR/overlay.log" ]
}
