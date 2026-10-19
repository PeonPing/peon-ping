#!/usr/bin/env bats

@test "Ghostty notifications reach the exact PTY and preserve multiplexer fallbacks" {
  run python3 "$BATS_TEST_DIRNAME/ghostty_notify.py"
  [ "$status" -eq 0 ]
}

@test "Ghostty focus suppression requires exact terminal identity" {
  run python3 "$BATS_TEST_DIRNAME/ghostty_focus.py"
  [ "$status" -eq 0 ]
}
