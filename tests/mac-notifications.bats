#!/usr/bin/env bats

@test "Ghostty notifications reach the exact PTY and preserve multiplexer fallbacks" {
  run python3 "$BATS_TEST_DIRNAME/ghostty_notify.py"
  [ "$status" -eq 0 ]
}

@test "Ghostty focus suppression requires exact terminal identity" {
  run python3 "$BATS_TEST_DIRNAME/ghostty_focus.py"
  [ "$status" -eq 0 ]
}

@test "concurrent macOS sound launches do not overlap or kill unrelated PIDs" {
  run python3 "$BATS_TEST_DIRNAME/sound_concurrency.py"
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output" >&2
    return 1
  fi
}
