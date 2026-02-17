#!/usr/bin/env bats

# Tests for install.sh (local clone mode — no real network)
# install.sh now downloads packs from the registry via curl.
# We mock curl to simulate registry responses and pack downloads.

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
  cp "$(dirname "$BATS_TEST_FILENAME")/../completions.bash" "$CLONE_DIR/"
  cp "$(dirname "$BATS_TEST_FILENAME")/../completions.fish" "$CLONE_DIR/"
  cp "$(dirname "$BATS_TEST_FILENAME")/../relay.sh" "$CLONE_DIR/"
  cp "$(dirname "$BATS_TEST_FILENAME")/../uninstall.sh" "$CLONE_DIR/" 2>/dev/null || touch "$CLONE_DIR/uninstall.sh"
  cp -r "$(dirname "$BATS_TEST_FILENAME")/../skills" "$CLONE_DIR/" 2>/dev/null || true
  mkdir -p "$CLONE_DIR/scripts"
  cp "$(dirname "$BATS_TEST_FILENAME")/../scripts/"*.sh "$CLONE_DIR/scripts/" 2>/dev/null || true

  INSTALL_DIR="$TEST_HOME/.claude/hooks/peon-ping"

  # For --local tests: a fake project directory with .claude
  PROJECT_DIR="$(mktemp -d)"
  mkdir -p "$PROJECT_DIR/.claude"
  LOCAL_INSTALL_DIR="$PROJECT_DIR/.claude/hooks/peon-ping"

  # Create mock bin directory for curl
  MOCK_BIN="$(mktemp -d)"

  # Mock registry index.json — include all 10 default packs so install doesn't fail
  MOCK_REGISTRY_JSON='{"packs":[{"name":"peon","display_name":"Orc Peon","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"peon"},{"name":"peasant","display_name":"Human Peasant","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"peasant"},{"name":"glados","display_name":"GLaDOS","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"glados"},{"name":"sc_kerrigan","display_name":"Sarah Kerrigan","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"sc_kerrigan"},{"name":"sc_battlecruiser","display_name":"Battlecruiser","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"sc_battlecruiser"},{"name":"ra2_kirov","display_name":"Kirov Airship","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"ra2_kirov"},{"name":"dota2_axe","display_name":"Axe","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"dota2_axe"},{"name":"duke_nukem","display_name":"Duke Nukem","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"duke_nukem"},{"name":"tf2_engineer","display_name":"Engineer","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"tf2_engineer"},{"name":"hd2_helldiver","display_name":"Helldiver","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"hd2_helldiver"},{"name":"extra_pack","display_name":"Extra Pack","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"extra_pack"}]}'

  # Generic manifest template (used for any openpeon.json request)
  MOCK_MANIFEST='{"cesp_version":"1.0","name":"mock","display_name":"Mock Pack","categories":{"session.start":{"sounds":[{"file":"sounds/Hello1.wav","label":"Hello"}]},"task.complete":{"sounds":[{"file":"sounds/Done1.wav","label":"Done"}]}}}'

  # Write mock curl script
  cat > "$MOCK_BIN/curl" <<MOCK_CURL
#!/bin/bash
# Mock curl for install.sh tests
url=""
output=""
args=("\$@")
for ((i=0; i<\${#args[@]}; i++)); do
  case "\${args[\$i]}" in
    -o) output="\${args[\$((i+1))]}" ;;
    http*) url="\${args[\$i]}" ;;
  esac
done

# Determine what to return based on URL
case "\$url" in
  *index.json)
    if [ -n "\$output" ]; then
      echo '$MOCK_REGISTRY_JSON' > "\$output"
    else
      echo '$MOCK_REGISTRY_JSON'
    fi
    ;;
  *openpeon.json)
    echo '$MOCK_MANIFEST' > "\$output"
    ;;
  *sounds/*)
    # Create a dummy sound file (just needs to exist)
    printf 'RIFF' > "\$output"
    ;;
  *)
    # For other URLs, create dummy file if output specified
    if [ -n "\$output" ]; then
      echo "mock" > "\$output"
    fi
    ;;
esac
exit 0
MOCK_CURL
  chmod +x "$MOCK_BIN/curl"

  # Mock afplay (prevent actual sound playback during tests)
  cat > "$MOCK_BIN/afplay" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/afplay"

  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_HOME" "$CLONE_DIR" "$PROJECT_DIR" "$MOCK_BIN"
}

@test "fresh install creates all expected files" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$INSTALL_DIR/peon.sh" ]
  [ -f "$INSTALL_DIR/config.json" ]
  [ -f "$INSTALL_DIR/VERSION" ]
  [ -f "$INSTALL_DIR/.state.json" ]
  [ -f "$INSTALL_DIR/packs/peon/openpeon.json" ]
}

@test "fresh install downloads sound files from registry" {
  bash "$CLONE_DIR/install.sh"
  # Peon pack should have sound files
  peon_count=$(ls "$INSTALL_DIR/packs/peon/sounds/"* 2>/dev/null | wc -l | tr -d ' ')
  [ "$peon_count" -gt 0 ]
}

@test "fresh install registers hooks in settings.json" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$TEST_HOME/.claude/settings.json" ]
  # Check that all five events are registered
  /usr/bin/python3 -c "
import json
s = json.load(open('$TEST_HOME/.claude/settings.json'))
hooks = s.get('hooks', {})
for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest']:
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

@test "fresh install copies completions.bash" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$INSTALL_DIR/completions.bash" ]
}

@test "fresh install adds completions source to shell rc" {
  touch "$TEST_HOME/.zshrc"
  bash "$CLONE_DIR/install.sh"
  grep -qF 'peon-ping/completions.bash' "$TEST_HOME/.zshrc"
}

# --- --local mode tests ---

@test "--local installs into project .claude directory" {
  cd "$PROJECT_DIR"
  bash "$CLONE_DIR/install.sh" --local
  [ -f "$LOCAL_INSTALL_DIR/peon.sh" ]
  [ -f "$LOCAL_INSTALL_DIR/config.json" ]
  [ -f "$LOCAL_INSTALL_DIR/VERSION" ]
  [ -f "$LOCAL_INSTALL_DIR/.state.json" ]
  [ -f "$LOCAL_INSTALL_DIR/packs/peon/openpeon.json" ]
}

@test "--local registers hooks in global settings.json" {
  cd "$PROJECT_DIR"
  bash "$CLONE_DIR/install.sh" --local
  # Hooks are always written to global settings (HOME/.claude/settings.json)
  [ -f "$TEST_HOME/.claude/settings.json" ]
  /usr/bin/python3 -c "
import json
s = json.load(open('$TEST_HOME/.claude/settings.json'))
hooks = s.get('hooks', {})
for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest']:
    assert event in hooks, f'{event} not in hooks'
    found = any('peon.sh' in h.get('command','') for entry in hooks[event] for h in entry.get('hooks',[]))
    assert found, f'peon.sh not registered for {event}'
print('OK')
"
}

@test "--local does not modify shell rc files" {
  touch "$TEST_HOME/.zshrc"
  touch "$TEST_HOME/.bashrc"
  cd "$PROJECT_DIR"
  bash "$CLONE_DIR/install.sh" --local
  ! grep -qF 'alias peon=' "$TEST_HOME/.zshrc"
  ! grep -qF 'alias peon=' "$TEST_HOME/.bashrc"
  ! grep -qF 'peon-ping/completions.bash' "$TEST_HOME/.zshrc"
}

@test "--local uninstall removes hooks and files" {
  cd "$PROJECT_DIR"
  bash "$CLONE_DIR/install.sh" --local
  [ -f "$LOCAL_INSTALL_DIR/peon.sh" ]
  # Hooks are in global settings
  [ -f "$TEST_HOME/.claude/settings.json" ]
  [ -d "$PROJECT_DIR/.claude/skills/peon-ping-toggle" ]

  # Run uninstall (non-interactive — no notify.sh restore prompt for local)
  bash "$LOCAL_INSTALL_DIR/uninstall.sh"

  # Hook entries removed from global settings.json
  /usr/bin/python3 -c "
import json
s = json.load(open('$TEST_HOME/.claude/settings.json'))
hooks = s.get('hooks', {})
for event, entries in hooks.items():
    for entry in entries:
        for h in entry.get('hooks', []):
            assert 'peon.sh' not in h.get('command', ''), f'peon.sh still in {event}'
print('OK')
"
  # Install and skill directories removed
  [ ! -d "$LOCAL_INSTALL_DIR" ]
  [ ! -d "$PROJECT_DIR/.claude/skills/peon-ping-toggle" ]
}

@test "--local fails without .claude directory" {
  NO_CLAUDE_DIR="$(mktemp -d)"
  cd "$NO_CLAUDE_DIR"
  run bash "$CLONE_DIR/install.sh" --local
  [ "$status" -ne 0 ]
  [[ "$output" == *".claude/ not found"* ]]
  rm -rf "$NO_CLAUDE_DIR"
}

@test "fresh install copies completions.fish" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$INSTALL_DIR/completions.fish" ]
}

@test "--all installs more packs than default" {
  # Default install
  bash "$CLONE_DIR/install.sh"
  default_count=$(ls -d "$INSTALL_DIR/packs/"*/ 2>/dev/null | wc -l | tr -d ' ')

  # Clean and reinstall with --all (mock registry has 2 packs)
  rm -rf "$INSTALL_DIR/packs"
  bash "$CLONE_DIR/install.sh" --all
  all_count=$(ls -d "$INSTALL_DIR/packs/"*/ 2>/dev/null | wc -l | tr -d ' ')

  # --all should install packs from registry (2 in our mock)
  [ "$all_count" -ge 2 ]
}

@test "install creates openpeon.json manifests not legacy manifest.json" {
  bash "$CLONE_DIR/install.sh"
  [ -f "$INSTALL_DIR/packs/peon/openpeon.json" ]
  [ ! -f "$INSTALL_DIR/packs/peon/manifest.json" ]
}

@test "--packs installs only specified packs" {
  bash "$CLONE_DIR/install.sh" --packs=peon,glados
  [ -d "$INSTALL_DIR/packs/peon" ]
  [ -d "$INSTALL_DIR/packs/glados" ]
  # Should NOT have other default packs
  [ ! -d "$INSTALL_DIR/packs/peasant" ]
  [ ! -d "$INSTALL_DIR/packs/duke_nukem" ]
}

@test "--packs with single pack works" {
  bash "$CLONE_DIR/install.sh" --packs=peon
  [ -d "$INSTALL_DIR/packs/peon" ]
  pack_count=$(ls -d "$INSTALL_DIR/packs/"*/ 2>/dev/null | wc -l | tr -d ' ')
  [ "$pack_count" -eq 1 ]
}

@test "--packs overrides default pack list" {
  bash "$CLONE_DIR/install.sh" --packs=glados
  [ -d "$INSTALL_DIR/packs/glados" ]
  [ ! -d "$INSTALL_DIR/packs/peon" ]
}

# --- is_safe_filename tests ---

@test "is_safe_filename allows question marks and exclamation marks" {
  # Source just the function from pack-download.sh
  eval "$(sed -n '/^is_safe_filename()/,/^}/p' "$CLONE_DIR/scripts/pack-download.sh")"
  is_safe_filename "New_construction?.mp3"
  is_safe_filename "Yeah?.mp3"
  is_safe_filename "What!.wav"
  is_safe_filename "Hello.wav"
}

@test "is_safe_filename rejects unsafe characters" {
  eval "$(sed -n '/^is_safe_filename()/,/^}/p' "$CLONE_DIR/scripts/pack-download.sh")"
  ! is_safe_filename "../etc/passwd"
  ! is_safe_filename "file;rm -rf /"
  ! is_safe_filename 'file$(cmd)'
}

# --- urlencode_filename tests ---

@test "urlencode_filename encodes question marks" {
  eval "$(sed -n '/^urlencode_filename()/,/^}/p' "$CLONE_DIR/scripts/pack-download.sh")"
  result=$(urlencode_filename "New_construction?.mp3")
  [ "$result" = "New_construction%3F.mp3" ]
}

@test "urlencode_filename encodes exclamation marks" {
  eval "$(sed -n '/^urlencode_filename()/,/^}/p' "$CLONE_DIR/scripts/pack-download.sh")"
  result=$(urlencode_filename "Wow!.mp3")
  [ "$result" = "Wow%21.mp3" ]
}

@test "urlencode_filename encodes hash symbols" {
  eval "$(sed -n '/^urlencode_filename()/,/^}/p' "$CLONE_DIR/scripts/pack-download.sh")"
  result=$(urlencode_filename "Track#1.mp3")
  [ "$result" = "Track%231.mp3" ]
}

@test "urlencode_filename leaves normal filenames unchanged" {
  eval "$(sed -n '/^urlencode_filename()/,/^}/p' "$CLONE_DIR/scripts/pack-download.sh")"
  result=$(urlencode_filename "Hello.wav")
  [ "$result" = "Hello.wav" ]
}

# --- checksum caching tests ---

@test "re-install skips already-downloaded sound files via checksum cache" {
  # First install
  bash "$CLONE_DIR/install.sh" --packs=peon
  [ -f "$INSTALL_DIR/packs/peon/.checksums" ]

  # Record file modification times
  stat -f '%m' "$INSTALL_DIR/packs/peon/sounds/"* > "$TEST_HOME/mtimes_before"

  # Sleep to ensure mtime would change if files were rewritten
  sleep 1

  # Re-install
  bash "$CLONE_DIR/install.sh" --packs=peon

  # Files should NOT have been re-downloaded (mtimes unchanged)
  stat -f '%m' "$INSTALL_DIR/packs/peon/sounds/"* > "$TEST_HOME/mtimes_after"
  diff "$TEST_HOME/mtimes_before" "$TEST_HOME/mtimes_after"
}

@test "checksums file is created during install" {
  bash "$CLONE_DIR/install.sh" --packs=peon
  [ -f "$INSTALL_DIR/packs/peon/.checksums" ]
  # Should have at least one entry
  [ "$(wc -l < "$INSTALL_DIR/packs/peon/.checksums" | tr -d ' ')" -gt 0 ]
}

@test "corrupted file is re-downloaded on re-install" {
  # First install
  bash "$CLONE_DIR/install.sh" --packs=peon

  # Corrupt a sound file (change its content so checksum mismatches)
  sound_file=$(ls "$INSTALL_DIR/packs/peon/sounds/"*.wav 2>/dev/null | head -1)
  [ -n "$sound_file" ]
  echo "CORRUPTED" > "$sound_file"

  # Re-install — corrupted file should be re-downloaded
  bash "$CLONE_DIR/install.sh" --packs=peon

  # File should no longer contain "CORRUPTED" (mock curl writes "RIFF")
  ! grep -q "CORRUPTED" "$sound_file"
}

@test "install does not rm -rf sounds directory" {
  # First install
  bash "$CLONE_DIR/install.sh" --packs=peon

  # Add an extra file to the sounds directory
  echo "extra" > "$INSTALL_DIR/packs/peon/sounds/custom_sound.wav"

  # Re-install
  bash "$CLONE_DIR/install.sh" --packs=peon

  # Extra file should still exist (not wiped by rm -rf)
  [ -f "$INSTALL_DIR/packs/peon/sounds/custom_sound.wav" ]
}

# --- URL encoding in download path ---

@test "mock curl receives URL-encoded filename for special chars" {
  # Create a manifest with a filename containing a question mark
  SPECIAL_MANIFEST='{"cesp_version":"1.0","name":"mock","display_name":"Mock Pack","categories":{"session.start":{"sounds":[{"file":"sounds/Yeah?.wav","label":"Yeah?"}]}}}'

  # Override mock curl to log URLs and handle the special manifest
  cat > "$MOCK_BIN/curl" <<MOCK_CURL
#!/bin/bash
url=""
output=""
args=("\$@")
for ((i=0; i<\${#args[@]}; i++)); do
  case "\${args[\$i]}" in
    -o) output="\${args[\$((i+1))]}" ;;
    http*) url="\${args[\$i]}" ;;
  esac
done
# Log URL to file (not stdout — that breaks piped registry fetch)
echo "\$url" >> "$TEST_HOME/curl_urls.log"
case "\$url" in
  *index.json)
    if [ -n "\$output" ]; then
      echo '$MOCK_REGISTRY_JSON' > "\$output"
    else
      echo '$MOCK_REGISTRY_JSON'
    fi
    ;;
  *openpeon.json)
    echo '$SPECIAL_MANIFEST' > "\$output"
    ;;
  *sounds/*)
    printf 'RIFF' > "\$output"
    ;;
  *)
    if [ -n "\$output" ]; then echo "mock" > "\$output"; fi
    ;;
esac
exit 0
MOCK_CURL
  chmod +x "$MOCK_BIN/curl"

  bash "$CLONE_DIR/install.sh" --packs=peon

  # Check that curl was called with %3F instead of literal ?
  grep -q '%3F' "$TEST_HOME/curl_urls.log"
}
