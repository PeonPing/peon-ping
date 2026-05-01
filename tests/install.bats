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
  mkdir -p "$CLONE_DIR/adapters"
  cp "$(dirname "$BATS_TEST_FILENAME")/../adapters/"*.sh "$CLONE_DIR/adapters/" 2>/dev/null || true

  INSTALL_DIR="$TEST_HOME/.claude/hooks/peon-ping"

  # For --local tests: a fake project directory with .claude
  PROJECT_DIR="$(mktemp -d)"
  mkdir -p "$PROJECT_DIR/.claude"
  LOCAL_INSTALL_DIR="$PROJECT_DIR/.claude/hooks/peon-ping"

  # Create mock bin directory for curl
  MOCK_BIN="$(mktemp -d)"

  # Mock registry index.json — include all 10 default packs so install doesn't fail
  # language fields: most are "en", peon_fr is "fr", extra_pack is "fr" (for --lang filter tests)
  MOCK_REGISTRY_JSON='{"packs":[{"name":"peon","display_name":"Orc Peon","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"peon"},{"name":"peasant","display_name":"Human Peasant","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"peasant"},{"name":"glados","display_name":"GLaDOS","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"glados"},{"name":"sc_kerrigan","display_name":"Sarah Kerrigan","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"sc_kerrigan"},{"name":"sc_battlecruiser","display_name":"Battlecruiser","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"sc_battlecruiser"},{"name":"ra2_kirov","display_name":"Kirov Airship","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"ra2_kirov"},{"name":"dota2_axe","display_name":"Axe","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"dota2_axe"},{"name":"duke_nukem","display_name":"Duke Nukem","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"duke_nukem"},{"name":"tf2_engineer","display_name":"Engineer","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"tf2_engineer"},{"name":"hd2_helldiver","display_name":"Helldiver","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"hd2_helldiver"},{"name":"extra_pack","display_name":"Extra Pack","language":"fr","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"extra_pack"}]}'

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
    # UserPromptSubmit registers BOTH peon.sh (silent_window/user.spam) AND hook-handle-use.sh (slash cmds)
    if event == 'UserPromptSubmit':
        cmds = [h.get('command','') for entry in hooks[event] for h in entry.get('hooks',[])]
        assert any('peon.sh' in c for c in cmds), 'peon.sh not registered for UserPromptSubmit (breaks silent_window/user.spam)'
        assert any('hook-handle-use' in c for c in cmds), 'hook-handle-use not registered for UserPromptSubmit'
    else:
        found = any('peon.sh' in h.get('command','') for entry in hooks[event] for h in entry.get('hooks',[]))
        assert found, f'peon.sh not registered for {event}'
print('OK')
"
}

@test "update preserves sibling custom hooks registered under same matcher entry (issue #484)" {
  # First install to establish peon hooks
  bash "$CLONE_DIR/install.sh"
  [ -f "$TEST_HOME/.claude/settings.json" ]

  # Simulate a user adding a custom hook *inside* peon's SessionStart matcher entry.
  # Also add a custom entry in UserPromptSubmit alongside hook-handle-use.
  /usr/bin/python3 -c "
import json
p = '$TEST_HOME/.claude/settings.json'
s = json.load(open(p))
for entry in s['hooks']['SessionStart']:
    if any('peon.sh' in h.get('command','') for h in entry.get('hooks', [])):
        entry['hooks'].append({'type': 'command', 'command': '~/.claude/hooks/my-custom/sync.sh'})
        break
for entry in s['hooks']['UserPromptSubmit']:
    if any('hook-handle-use' in h.get('command','') for h in entry.get('hooks', [])):
        entry['hooks'].append({'type': 'command', 'command': '~/.claude/hooks/my-custom/prompt.sh'})
        break
json.dump(s, open(p, 'w'), indent=2)
"

  # Re-run install (simulates peon update)
  bash "$CLONE_DIR/install.sh"

  # Custom sibling hooks should still be present
  /usr/bin/python3 -c "
import json
s = json.load(open('$TEST_HOME/.claude/settings.json'))
session_cmds = [h.get('command','') for entry in s['hooks']['SessionStart'] for h in entry.get('hooks', [])]
prompt_cmds = [h.get('command','') for entry in s['hooks']['UserPromptSubmit'] for h in entry.get('hooks', [])]
assert any('my-custom/sync.sh' in c for c in session_cmds), 'Custom SessionStart hook was wiped: ' + repr(session_cmds)
assert any('my-custom/prompt.sh' in c for c in prompt_cmds), 'Custom UserPromptSubmit hook was wiped: ' + repr(prompt_cmds)
assert any('peon.sh' in c for c in session_cmds), 'peon.sh missing from SessionStart after update'
assert any('hook-handle-use' in c for c in prompt_cmds), 'hook-handle-use missing from UserPromptSubmit after update'
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
  echo '{"volume": 0.9, "default_pack": "peon"}' > "$INSTALL_DIR/config.json"

  # Re-run (update)
  bash "$CLONE_DIR/install.sh"

  # Config should be preserved (not overwritten)
  volume=$(/usr/bin/python3 -c "import json; print(json.load(open('$INSTALL_DIR/config.json')).get('volume'))")
  [ "$volume" = "0.9" ]
}

@test "update backfills new config keys from template" {
  # First install
  bash "$CLONE_DIR/install.sh"

  # Simulate an old config missing newer keys
  echo '{"volume": 0.8, "default_pack": "peon", "enabled": true}' > "$INSTALL_DIR/config.json"

  # Re-run (update)
  bash "$CLONE_DIR/install.sh"

  # User value should be preserved
  volume=$(/usr/bin/python3 -c "import json; print(json.load(open('$INSTALL_DIR/config.json')).get('volume'))")
  [ "$volume" = "0.8" ]

  # New key from template should be backfilled
  use_sfx=$(/usr/bin/python3 -c "import json; print(json.load(open('$INSTALL_DIR/config.json')).get('use_sound_effects_device'))")
  [ "$use_sfx" = "True" ]
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

@test "--local registers hooks in project-level settings.json" {
  cd "$PROJECT_DIR"
  bash "$CLONE_DIR/install.sh" --local
  # Hooks should be written to the project-level settings (PROJECT_DIR/.claude/settings.json)
  [ -f "$PROJECT_DIR/.claude/settings.json" ]
  /usr/bin/python3 -c "
import json
s = json.load(open('$PROJECT_DIR/.claude/settings.json'))
hooks = s.get('hooks', {})
for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest']:
    assert event in hooks, f'{event} not in hooks'
    # UserPromptSubmit registers BOTH peon.sh (silent_window/user.spam) AND hook-handle-use.sh (slash cmds)
    if event == 'UserPromptSubmit':
        cmds = [h.get('command','') for entry in hooks[event] for h in entry.get('hooks',[])]
        assert any('peon.sh' in c for c in cmds), 'peon.sh not registered for UserPromptSubmit (breaks silent_window/user.spam)'
        assert any('hook-handle-use' in c for c in cmds), 'hook-handle-use not registered for UserPromptSubmit'
    else:
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
  # Hooks are in project-level settings
  [ -f "$PROJECT_DIR/.claude/settings.json" ]
  [ -d "$PROJECT_DIR/.claude/skills/peon-ping-toggle" ]

  # Run uninstall (non-interactive — no notify.sh restore prompt for local)
  bash "$LOCAL_INSTALL_DIR/uninstall.sh"

  # Hook entries removed from project-level settings.json
  /usr/bin/python3 -c "
import json
s = json.load(open('$PROJECT_DIR/.claude/settings.json'))
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

@test "--local hook paths point to project directory not global" {
  cd "$PROJECT_DIR"
  bash "$CLONE_DIR/install.sh" --local
  # Every peon.sh hook command should reference the project path, not ~/.claude
  /usr/bin/python3 -c "
import json
s = json.load(open('$PROJECT_DIR/.claude/settings.json'))
hooks = s.get('hooks', {})
for event, entries in hooks.items():
    for entry in entries:
        for h in entry.get('hooks', []):
            cmd = h.get('command', '')
            if 'peon.sh' in cmd:
                assert '$PROJECT_DIR' in cmd, f'Hook for {event} points outside project: {cmd}'
                assert '$TEST_HOME/.claude' not in cmd, f'Hook for {event} points to global: {cmd}'
print('OK')
"
}

@test "--local fails without .claude directory" {
  NO_CLAUDE_DIR="$(mktemp -d)"
  cd "$NO_CLAUDE_DIR"
  run bash "$CLONE_DIR/install.sh" --local
  [ "$status" -ne 0 ]
  [[ "$output" == *".claude/ not found"* ]]
  rm -rf "$NO_CLAUDE_DIR"
}

@test "global install creates ~/.claude if it does not exist" {
  # Simulate a machine where Claude Code was never installed (no ~/.claude)
  FAKE_HOME="$(mktemp -d)"
  run env HOME="$FAKE_HOME" CLAUDE_CONFIG_DIR="$FAKE_HOME/.claude" \
    bash "$CLONE_DIR/install.sh"
  [ "$status" -eq 0 ]
  [ -d "$FAKE_HOME/.claude/hooks/peon-ping" ]
  rm -rf "$FAKE_HOME"
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

# ============================================================
# OpenClaw install support
# ============================================================

@test "--openclaw installs to ~/.openclaw/hooks/peon-ping" {
  mkdir -p "$TEST_HOME/.openclaw"
  bash "$CLONE_DIR/install.sh" --openclaw
  [ -f "$TEST_HOME/.openclaw/hooks/peon-ping/peon.sh" ]
  [ -f "$TEST_HOME/.openclaw/hooks/peon-ping/config.json" ]
}

@test "--openclaw creates skill file at ~/.openclaw/skills/peon-ping/SKILL.md" {
  mkdir -p "$TEST_HOME/.openclaw"
  bash "$CLONE_DIR/install.sh" --openclaw
  [ -f "$TEST_HOME/.openclaw/skills/peon-ping/SKILL.md" ]
  grep -q "peon-ping" "$TEST_HOME/.openclaw/skills/peon-ping/SKILL.md"
}

@test "--openclaw does not create settings.json" {
  mkdir -p "$TEST_HOME/.openclaw"
  bash "$CLONE_DIR/install.sh" --openclaw
  [ ! -f "$TEST_HOME/.openclaw/settings.json" ]
}

@test "auto-detects openclaw when ~/.openclaw exists and ~/.claude does not" {
  rm -rf "$TEST_HOME/.claude"
  mkdir -p "$TEST_HOME/.openclaw"
  bash "$CLONE_DIR/install.sh"
  [ -f "$TEST_HOME/.openclaw/hooks/peon-ping/peon.sh" ]
  [ -f "$TEST_HOME/.openclaw/skills/peon-ping/SKILL.md" ]
}

# ============================================================
# Kimi-direct install support (--kimi flag, no Claude required)
# ============================================================
#
# These tests install adapters/kimi.sh which spawns a watcher daemon. We force
# the nohup+pidfile path with KIMI_NO_LAUNCHD=1 (so we never touch the real
# user's LaunchAgents) and stub fswatch so the spawned daemon exits cleanly
# instead of blocking forever.
_kimi_test_setup() {
  export KIMI_NO_LAUNCHD=1
  cat > "$MOCK_BIN/fswatch" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/fswatch"
}

_kimi_test_teardown() {
  # Reap any stray daemon spawned by install.sh's kimi.sh --install
  for pidfile in "$TEST_HOME/.kimi/hooks/peon-ping/.kimi-adapter.pid" "$TEST_HOME/.claude/hooks/peon-ping/.kimi-adapter.pid"; do
    if [ -f "$pidfile" ]; then
      pid=$(cat "$pidfile" 2>/dev/null)
      if [ -n "$pid" ]; then
        pkill -P "$pid" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
      fi
    fi
  done
}

@test "--kimi installs to ~/.kimi/hooks/peon-ping" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  bash "$CLONE_DIR/install.sh" --kimi
  [ -f "$TEST_HOME/.kimi/hooks/peon-ping/peon.sh" ]
  [ -f "$TEST_HOME/.kimi/hooks/peon-ping/config.json" ]
  [ -f "$TEST_HOME/.kimi/hooks/peon-ping/adapters/kimi.sh" ]
  _kimi_test_teardown
}

@test "--kimi does not write to ~/.claude/settings.json" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  # Pre-create an empty settings.json so we can detect any unwanted hook write
  echo '{}' > "$TEST_HOME/.claude/settings.json"
  bash "$CLONE_DIR/install.sh" --kimi
  # Settings file should be unchanged (no peon-ping hooks added)
  ! grep -q "peon-ping" "$TEST_HOME/.claude/settings.json"
  _kimi_test_teardown
}

@test "--kimi does not require ~/.claude to exist" {
  _kimi_test_setup
  rm -rf "$TEST_HOME/.claude"
  mkdir -p "$TEST_HOME/.kimi"
  bash "$CLONE_DIR/install.sh" --kimi
  [ -f "$TEST_HOME/.kimi/hooks/peon-ping/peon.sh" ]
  # Critical: no ~/.claude directory should be created in --kimi mode
  [ ! -d "$TEST_HOME/.claude" ]
  _kimi_test_teardown
}

@test "auto-detects kimi when ~/.kimi exists and ~/.claude does not" {
  _kimi_test_setup
  rm -rf "$TEST_HOME/.claude"
  mkdir -p "$TEST_HOME/.kimi"
  bash "$CLONE_DIR/install.sh"
  [ -f "$TEST_HOME/.kimi/hooks/peon-ping/peon.sh" ]
  [ ! -d "$TEST_HOME/.claude" ]
  _kimi_test_teardown
}

@test "--kimi flag appears in --help output" {
  run bash "$CLONE_DIR/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--kimi"* ]]
}

@test "--kimi rewrites skill SKILL.md paths to ~/.kimi/hooks/peon-ping" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  # Need real skill source for rewrite to do anything
  cp -r "$(dirname "$BATS_TEST_FILENAME")/../skills" "$CLONE_DIR/"
  bash "$CLONE_DIR/install.sh" --kimi

  for skill in peon-ping-toggle peon-ping-config peon-ping-use peon-ping-log; do
    skill_md="$TEST_HOME/.kimi/skills/$skill/SKILL.md"
    [ -f "$skill_md" ]
    # No leftover Claude path references
    ! grep -q '${CLAUDE_CONFIG_DIR' "$skill_md"
    ! grep -q '~/\.claude/hooks/peon-ping' "$skill_md"
    # New absolute Kimi path is present
    grep -q "$TEST_HOME/.kimi/hooks/peon-ping" "$skill_md"
  done
  _kimi_test_teardown
}

# ---------------------------------------------------------------------------
# Shared packs across Claude and Kimi installs (--kimi auto-symlink behavior)
# ---------------------------------------------------------------------------

@test "--kimi auto-symlinks packs/ to Claude's when ~/.claude has packs" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  # Pre-populate Claude's packs/ so auto-share trigger fires
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds"
  touch "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds/test.wav"

  run bash "$CLONE_DIR/install.sh" --kimi
  [ "$status" -eq 0 ]

  # Kimi's packs/ should be a symlink pointing at Claude's
  [ -L "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  link_target="$(readlink "$TEST_HOME/.kimi/hooks/peon-ping/packs")"
  [ "$link_target" = "$TEST_HOME/.claude/hooks/peon-ping/packs" ]
  # Kimi sees Claude's pack through the symlink
  [ -d "$TEST_HOME/.kimi/hooks/peon-ping/packs/glados" ]
  # Confirm install message tells the user
  [[ "$output" == *"sharing with Claude install"* ]]
  _kimi_test_teardown
}

@test "--kimi --no-shared-packs downloads separately even when Claude has packs" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds"
  touch "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds/test.wav"

  bash "$CLONE_DIR/install.sh" --kimi --no-shared-packs

  # Kimi's packs/ must be a real directory (downloaded), not a symlink
  [ ! -L "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  [ -d "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  _kimi_test_teardown
}

@test "--kimi falls back to download when Claude packs/ is missing" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  rm -rf "$TEST_HOME/.claude/hooks/peon-ping/packs"
  bash "$CLONE_DIR/install.sh" --kimi
  [ ! -L "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  [ -d "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  _kimi_test_teardown
}

@test "--kimi falls back to download when Claude packs/ is empty" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/packs"  # empty dir
  bash "$CLONE_DIR/install.sh" --kimi
  [ ! -L "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  [ -d "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  _kimi_test_teardown
}

@test "--kimi --packs=<name> skips auto-share (explicit pack intent)" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds"
  touch "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds/test.wav"
  bash "$CLONE_DIR/install.sh" --kimi --packs=peon
  # User asked for a specific pack — keep Kimi's packs/ as a real dir
  [ ! -L "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  [ -d "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  _kimi_test_teardown
}

@test "--kimi auto-share is idempotent across reruns" {
  _kimi_test_setup
  mkdir -p "$TEST_HOME/.kimi"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds"
  touch "$TEST_HOME/.claude/hooks/peon-ping/packs/glados/sounds/test.wav"

  bash "$CLONE_DIR/install.sh" --kimi
  [ -L "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  # Re-run should not break the symlink
  bash "$CLONE_DIR/install.sh" --kimi
  [ -L "$TEST_HOME/.kimi/hooks/peon-ping/packs" ]
  link_target="$(readlink "$TEST_HOME/.kimi/hooks/peon-ping/packs")"
  [ "$link_target" = "$TEST_HOME/.claude/hooks/peon-ping/packs" ]
  _kimi_test_teardown
}

@test "--no-shared-packs flag appears in --help output" {
  run bash "$CLONE_DIR/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--no-shared-packs"* ]]
}

# ---------------------------------------------------------------------------
# --rovodev-only flag tests
# ---------------------------------------------------------------------------

@test "--rovodev-only exits 0 when ~/.rovodev dir exists" {
  mkdir -p "$TEST_HOME/.rovodev"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/adapters"
  echo '#!/bin/bash' > "$TEST_HOME/.claude/hooks/peon-ping/adapters/rovodev.sh"
  run bash "$CLONE_DIR/install.sh" --rovodev-only
  [ "$status" -eq 0 ]
}

@test "--rovodev-only exits 1 when ~/.rovodev dir does not exist" {
  run bash "$CLONE_DIR/install.sh" --rovodev-only
  [ "$status" -eq 1 ]
}

@test "--rovodev-only creates config.yml when dir exists but no config" {
  mkdir -p "$TEST_HOME/.rovodev"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/adapters"
  echo '#!/bin/bash' > "$TEST_HOME/.claude/hooks/peon-ping/adapters/rovodev.sh"
  run bash "$CLONE_DIR/install.sh" --rovodev-only
  [ "$status" -eq 0 ]
  [ -f "$TEST_HOME/.rovodev/config.yml" ]
  grep -q "on_complete" "$TEST_HOME/.rovodev/config.yml"
  grep -q "on_error" "$TEST_HOME/.rovodev/config.yml"
  grep -q "on_tool_permission" "$TEST_HOME/.rovodev/config.yml"
}

@test "--rovodev-only replaces events: [] with event entries" {
  mkdir -p "$TEST_HOME/.rovodev"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/adapters"
  echo '#!/bin/bash' > "$TEST_HOME/.claude/hooks/peon-ping/adapters/rovodev.sh"
  cat > "$TEST_HOME/.rovodev/config.yml" <<EOF
eventHooks:
  logFile: /tmp/test.log
  events: []
EOF
  run bash "$CLONE_DIR/install.sh" --rovodev-only
  [ "$status" -eq 0 ]
  # Should not contain empty array anymore
  ! grep -q 'events: \[\]' "$TEST_HOME/.rovodev/config.yml"
  # Should have events
  grep -q "on_complete" "$TEST_HOME/.rovodev/config.yml"
  # Should preserve logFile
  grep -q "logFile:" "$TEST_HOME/.rovodev/config.yml"
}

@test "--rovodev-only skips if rovodev.sh already registered" {
  mkdir -p "$TEST_HOME/.rovodev"
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping/adapters"
  echo '#!/bin/bash' > "$TEST_HOME/.claude/hooks/peon-ping/adapters/rovodev.sh"
  cat > "$TEST_HOME/.rovodev/config.yml" <<EOF
eventHooks:
  events:
    - name: on_complete
      commands:
        - command: bash /some/path/rovodev.sh on_complete
EOF
  run bash "$CLONE_DIR/install.sh" --rovodev-only
  [ "$status" -eq 0 ]
  [[ "$output" == *"already present"* ]]
}

@test "--rovodev-only shows in help" {
  run bash "$CLONE_DIR/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--rovodev-only"* ]]
}

# ============================================================
# --lang (language filtering)
# ============================================================

@test "--all --lang=fr installs only French packs" {
  bash "$CLONE_DIR/install.sh" --all --lang=fr
  # extra_pack is the only French pack in our mock registry
  [ -d "$INSTALL_DIR/packs/extra_pack" ]
  # English packs should NOT be installed
  [ ! -d "$INSTALL_DIR/packs/peon" ]
  [ ! -d "$INSTALL_DIR/packs/glados" ]
}

@test "--lang=xx shows zero-match warning" {
  run bash "$CLONE_DIR/install.sh" --all --lang=xx
  [ "$status" -eq 0 ]
  [[ "$output" == *"no packs match language"* ]]
}

@test "--lang appears in --help output" {
  run bash "$CLONE_DIR/install.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--lang"* ]]
}
