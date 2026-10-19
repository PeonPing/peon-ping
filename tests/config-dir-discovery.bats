#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env
  FAKE_HOME="$TEST_DIR/home"
  LIBEXEC="$TEST_DIR/homebrew/libexec"
  HOOKS="$FAKE_HOME/.claude/hooks/peon-ping"
  PROFILE="$FAKE_HOME/.other-claude"
  SHARED="$FAKE_HOME/.openpeon"
  mkdir -p "$LIBEXEC" "$HOOKS" "$PROFILE" "$SHARED"
  cp "$PEON_SH" "$LIBEXEC/peon.sh"
  ln -s "$LIBEXEC/peon.sh" "$HOOKS/peon.sh"
  ln -s "$TEST_DIR/packs" "$SHARED/packs"
  ln -s "$SHARED/packs" "$HOOKS/packs"
  printf '{"default_pack":"peon","volume":0.2}\n' > "$SHARED/config.json"
  printf '{"default_pack":"sc_kerrigan","volume":0.7}\n' > "$HOOKS/config.json"
}

teardown() {
  teardown_test_env
}

invoke_peon() {
  env -u CLAUDE_PEON_DIR -u CODEX_HOME -u XDG_CONFIG_HOME -u GEMINI_CONFIG_DIR \
    HOME="$FAKE_HOME" CLAUDE_CONFIG_DIR="$PROFILE" PEON_PLATFORM=linux PEON_TEST=1 "$@"
}

@test "config discovery: invoked hooks symlink keeps its config with another Claude profile" {
  run invoke_peon bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $HOOKS/config.json"* ]] || return 1
  [[ "$output" == *"default pack: sc_kerrigan"* ]] || return 1
  [[ "$output" == *"volume: 70%"* ]] || return 1
}

@test "config discovery: invoked hooks wins over another profile with packs" {
  mkdir -p "$PROFILE/hooks/peon-ping"
  ln -s "$SHARED/packs" "$PROFILE/hooks/peon-ping/packs"
  cp "$SHARED/config.json" "$PROFILE/hooks/peon-ping/config.json"
  run invoke_peon bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $HOOKS/config.json"* ]] || return 1
}

@test "config discovery: relative hooks symlink keeps its invoking directory" {
  rm "$HOOKS/peon.sh"
  ln -s "../../../../homebrew/libexec/peon.sh" "$HOOKS/peon.sh"
  run invoke_peon bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $HOOKS/config.json"* ]] || return 1
}

@test "config discovery: config writes through the hook symlink update only its config" {
  run invoke_peon bash "$HOOKS/peon.sh" volume 0.6
  [ "$status" -eq 0 ]
  "$PEON_PY" - "$HOOKS/config.json" "$SHARED/config.json" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))['volume'] == 0.6
assert json.load(open(sys.argv[2]))['volume'] == 0.2
PY
}

@test "config discovery: explicit CLAUDE_PEON_DIR with packs overrides the invoking hooks" {
  run invoke_peon env CLAUDE_PEON_DIR="$SHARED" bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $SHARED/config.json"* ]] || return 1
  [[ "$output" == *"default pack: peon"* ]] || return 1
}

@test "config discovery: self-contained resolved install wins over the shim directory" {
  ln -s "$SHARED/packs" "$LIBEXEC/packs"
  cp "$SHARED/config.json" "$LIBEXEC/config.json"
  run invoke_peon bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $LIBEXEC/config.json"* ]] || return 1
}

@test "config discovery: direct Homebrew script still uses the configured profile hooks" {
  mkdir -p "$PROFILE/hooks/peon-ping"
  ln -s "$SHARED/packs" "$PROFILE/hooks/peon-ping/packs"
  cp "$HOOKS/config.json" "$PROFILE/hooks/peon-ping/config.json"
  run invoke_peon bash "$LIBEXEC/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $PROFILE/hooks/peon-ping/config.json"* ]] || return 1
}

@test "config discovery: direct Homebrew script still falls back to shared packs" {
  run invoke_peon bash "$LIBEXEC/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $SHARED/config.json"* ]] || return 1
}

@test "config discovery: an invoking config without packs does not anchor discovery" {
  rm "$HOOKS/packs"
  run invoke_peon bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $SHARED/config.json"* ]] || return 1
}

@test "config discovery: the resolved installation still supplies bundled relay scripts" {
  printf '#!/bin/bash\necho synthetic-relay-from-libexec\n' > "$LIBEXEC/relay.sh"
  run invoke_peon bash "$HOOKS/peon.sh" relay --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"synthetic-relay-from-libexec"* ]] || return 1
}

@test "config discovery: an empty explicit directory retains the existing shared fallback" {
  mkdir -p "$TEST_DIR/empty-explicit"
  run invoke_peon env CLAUDE_PEON_DIR="$TEST_DIR/empty-explicit" bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $SHARED/config.json"* ]] || return 1
}

@test "config discovery: the default Claude profile still reads the invoking hooks config" {
  run invoke_peon env CLAUDE_CONFIG_DIR="" bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $HOOKS/config.json"* ]] || return 1
}

@test "config discovery: project-local config still overrides reads and volume writes" {
  local project="$TEST_DIR/project"
  local local_config="$project/.claude/hooks/peon-ping/config.json"
  mkdir -p "$(dirname "$local_config")"
  cp "$SHARED/config.json" "$local_config"
  cd "$project"
  run invoke_peon bash "$HOOKS/peon.sh" status --verbose
  [ "$status" -eq 0 ]
  [[ "$output" == *"config: $local_config"* ]] || return 1
  [[ "$output" == *"global config: $HOOKS/config.json"* ]] || return 1
  run invoke_peon bash "$HOOKS/peon.sh" volume 0.4
  [ "$status" -eq 0 ]
  "$PEON_PY" - "$HOOKS/config.json" "$local_config" <<'PY'
import json, sys
assert json.load(open(sys.argv[1]))['volume'] == 0.7
assert json.load(open(sys.argv[2]))['volume'] == 0.4
PY
}
