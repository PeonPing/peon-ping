#!/usr/bin/env bats

@test "Codex config helper preserves the existing hook representation" {
  run python3 "$BATS_TEST_DIRNAME/test_codex_config.py"
  [ "$status" -eq 0 ]
}
