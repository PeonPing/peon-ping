#!/usr/bin/env bats

@test "manual rename skill preserves state on read and write failures" {
  run python3 "$BATS_TEST_DIRNAME/test_rename_skill.py" -v
  echo "$output"
  [ "$status" -eq 0 ]
}
