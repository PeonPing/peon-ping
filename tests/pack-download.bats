#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  setup_pack_download_env
}

teardown() {
  teardown_test_env
}

# ============================================================
# --list-registry
# ============================================================

@test "--list-registry prints pack names from registry" {
  run bash "$PACK_DL_SH" --list-registry --dir="$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test_pack_a"* ]]
  [[ "$output" == *"test_pack_b"* ]]
  [[ "$output" == *"Test Pack A"* ]]
}

@test "--list-registry shows checkmark for installed packs" {
  # Pre-install test_pack_a
  mkdir -p "$TEST_DIR/packs/test_pack_a"
  run bash "$PACK_DL_SH" --list-registry --dir="$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"test_pack_a"*"✓"* ]]
  # test_pack_b is not installed — no checkmark
  line_b=$(echo "$output" | grep "test_pack_b")
  [[ "$line_b" != *"✓"* ]]
}

@test "--list-registry works without --dir" {
  run bash "$PACK_DL_SH" --list-registry
  [ "$status" -eq 0 ]
  [[ "$output" == *"test_pack_a"* ]]
}

@test "--list-registry falls back when registry unreachable" {
  touch "$TEST_DIR/.mock_registry_fail"
  run bash "$PACK_DL_SH" --list-registry --dir="$TEST_DIR"
  [ "$status" -eq 0 ]
  # Should use fallback pack list (contains "peon")
  [[ "$output" == *"peon"* ]]
}

# ============================================================
# --packs (download specific packs)
# ============================================================

@test "--packs downloads specified packs" {
  run bash "$PACK_DL_SH" --dir="$TEST_DIR" --packs=test_pack_a,test_pack_b
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a/sounds" ]
  [ -d "$TEST_DIR/packs/test_pack_b/sounds" ]
  [ -f "$TEST_DIR/packs/test_pack_a/openpeon.json" ]
  [ -f "$TEST_DIR/packs/test_pack_b/openpeon.json" ]
}

@test "--packs downloads sound files" {
  run bash "$PACK_DL_SH" --dir="$TEST_DIR" --packs=test_pack_a
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/packs/test_pack_a/sounds/Hello1.wav" ]
}

@test "--packs creates checksums file" {
  run bash "$PACK_DL_SH" --dir="$TEST_DIR" --packs=test_pack_a
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/packs/test_pack_a/.checksums" ]
}

@test "--packs with single pack works" {
  run bash "$PACK_DL_SH" --dir="$TEST_DIR" --packs=test_pack_a
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [ ! -d "$TEST_DIR/packs/test_pack_b" ]
}

# ============================================================
# --all (download all from registry)
# ============================================================

@test "--all downloads all packs from registry" {
  run bash "$PACK_DL_SH" --dir="$TEST_DIR" --all
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/packs/test_pack_a" ]
  [ -d "$TEST_DIR/packs/test_pack_b" ]
}

# ============================================================
# Validation
# ============================================================

@test "invalid pack name is skipped" {
  run bash "$PACK_DL_SH" --dir="$TEST_DIR" --packs="../etc/passwd"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping invalid"* ]] || [[ "$(cat "$TEST_DIR/stderr.log" 2>/dev/null)" == *"skipping invalid"* ]]
}

@test "missing --dir shows error" {
  run bash "$PACK_DL_SH" --packs=test_pack_a
  [ "$status" -ne 0 ]
  [[ "$output" == *"--dir is required"* ]]
}

@test "missing --packs and --all shows error" {
  run bash "$PACK_DL_SH" --dir="$TEST_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"--packs"* ]]
}

# ============================================================
# Safety functions
# ============================================================

@test "is_safe_filename allows question marks and exclamation marks" {
  eval "$(sed -n '/^is_safe_filename()/,/^}/p' "$PACK_DL_SH")"
  is_safe_filename "New_construction?.mp3"
  is_safe_filename "Yeah?.mp3"
  is_safe_filename "What!.wav"
  is_safe_filename "Hello.wav"
}

@test "is_safe_filename rejects unsafe characters" {
  eval "$(sed -n '/^is_safe_filename()/,/^}/p' "$PACK_DL_SH")"
  ! is_safe_filename "../etc/passwd"
  ! is_safe_filename "file;rm -rf /"
  ! is_safe_filename 'file$(cmd)'
}

@test "urlencode_filename encodes question marks" {
  eval "$(sed -n '/^urlencode_filename()/,/^}/p' "$PACK_DL_SH")"
  result=$(urlencode_filename "New_construction?.mp3")
  [ "$result" = "New_construction%3F.mp3" ]
}

@test "urlencode_filename encodes exclamation marks" {
  eval "$(sed -n '/^urlencode_filename()/,/^}/p' "$PACK_DL_SH")"
  result=$(urlencode_filename "Wow!.mp3")
  [ "$result" = "Wow%21.mp3" ]
}

@test "urlencode_filename leaves normal filenames unchanged" {
  eval "$(sed -n '/^urlencode_filename()/,/^}/p' "$PACK_DL_SH")"
  result=$(urlencode_filename "Hello.wav")
  [ "$result" = "Hello.wav" ]
}
