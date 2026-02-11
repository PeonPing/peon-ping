#!/usr/bin/env bats

# Tests for install.sh (local clone mode only — no network)

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  # Create minimal .claude directory (prerequisite)
  mkdir -p "$TEST_HOME/.claude"

  # Create a fake local clone with all required files
  CLONE_DIR="$(mktemp -d)"
  cp "$(dirname "$BATS_TEST_FILENAME")/../install.sh" "$CLONE_DIR/"
  cp "$(dirname "$BATS_TEST_FILENAME")/../peon.sh" "$CLONE_DIR/"
  cp "$(dirname "$BATS_TEST_FILENAME")/../config.json" "$CLONE_DIR/"
  cp "$(dirname "$BATS_TEST_FILENAME")/../VERSION" "$CLONE_DIR/"
  cp "$(dirname "$BATS_TEST_FILENAME")/../uninstall.sh" "$CLONE_DIR/" 2>/dev/null || touch "$CLONE_DIR/uninstall.sh"
  cp -r "$(dirname "$BATS_TEST_FILENAME")/../packs" "$CLONE_DIR/"

  INSTALL_DIR="$TEST_HOME/.claude/hooks/peon-ping"
}

teardown() {
  rm -rf "$TEST_HOME" "$CLONE_DIR"
}

@test "fresh install creates all expected files" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$INSTALL_DIR/peon.sh" ]
  [ -f "$INSTALL_DIR/config.json" ]
  [ -f "$INSTALL_DIR/VERSION" ]
  [ -f "$INSTALL_DIR/.state.json" ]
  [ -f "$INSTALL_DIR/packs/peon/manifest.json" ]
  [ -f "$INSTALL_DIR/packs/ra2_soviet_engineer/manifest.json" ]
}

@test "fresh install copies sound files" {
  bash "$CLONE_DIR/install.sh"
  peon_count=$(ls "$INSTALL_DIR/packs/peon/sounds/"*.wav 2>/dev/null | wc -l | tr -d ' ')
  ra2_count=$(ls "$INSTALL_DIR/packs/ra2_soviet_engineer/sounds/"*.mp3 2>/dev/null | wc -l | tr -d ' ')
  [ "$peon_count" -gt 0 ]
  [ "$ra2_count" -gt 0 ]
}

@test "fresh install registers hooks in settings.json" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$TEST_HOME/.claude/settings.json" ]
  # Check that all four events are registered
  /usr/bin/python3 -c "
import json
s = json.load(open('$TEST_HOME/.claude/settings.json'))
hooks = s.get('hooks', {})
for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification']:
    assert event in hooks, f'{event} not in hooks'
    found = any('peon.sh' in h.get('command','') for entry in hooks[event] for h in entry.get('hooks',[]))
    assert found, f'peon.sh not registered for {event}'
print('OK')
"
}

@test "fresh install creates VERSION file" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$INSTALL_DIR/VERSION" ]
  version=$(cat "$INSTALL_DIR/VERSION" | tr -d '[:space:]')
  expected=$(cat "$CLONE_DIR/VERSION" | tr -d '[:space:]')
  [ "$version" = "$expected" ]
}

@test "update preserves existing config" {
  # First install
  bash "$CLONE_DIR/install.sh"

  # Modify config
  echo '{"volume": 0.9, "active_pack": "peon"}' > "$INSTALL_DIR/config.json"

  # Re-run (update)
  bash "$CLONE_DIR/install.sh"

  # Config should be preserved (not overwritten)
  volume=$(/usr/bin/python3 -c "import json; print(json.load(open('$INSTALL_DIR/config.json')).get('volume'))")
  [ "$volume" = "0.9" ]
}

@test "peon.sh is executable after install" {
  bash "$CLONE_DIR/install.sh"
  [ -x "$INSTALL_DIR/peon.sh" ]
}
