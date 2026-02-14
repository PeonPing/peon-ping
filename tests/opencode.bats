#!/usr/bin/env bats

# Tests for adapters/opencode.sh — the OpenCode adapter install script.
# Covers: install, uninstall, idempotency, broken-symlink fix, XDG support,
# curl dependency, and registry failure graceful handling.

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  OPENCODE_SH="$REPO_ROOT/adapters/opencode.sh"

  unset XDG_CONFIG_HOME
  PLUGINS_DIR="$TEST_HOME/.config/opencode/plugins"
  CONFIG_DIR="$TEST_HOME/.config/opencode/peon-ping"
  PACKS_DIR="$TEST_HOME/.openpeon/packs"

  # --- Mock bin directory ---
  MOCK_BIN="$(mktemp -d)"

  # Mock curl — simulate downloading peon-ping.ts and registry
  MOCK_REGISTRY='{"packs":[{"name":"peon","display_name":"Orc Peon","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"peon"}]}'

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

case "\$url" in
  *peon-ping.ts)
    if [ -n "\$output" ]; then
      echo '// peon-ping plugin for OpenCode' > "\$output"
    fi
    ;;
  *index.json)
    if [ -n "\$output" ]; then
      echo '$MOCK_REGISTRY' > "\$output"
    else
      echo '$MOCK_REGISTRY'
    fi
    ;;
  *tar.gz)
    tmppack=\$(mktemp -d)
    mkdir -p "\$tmppack/og-packs-1.0.0/peon/sounds"
    echo '{"name":"peon"}' > "\$tmppack/og-packs-1.0.0/peon/manifest.json"
    printf 'RIFF' > "\$tmppack/og-packs-1.0.0/peon/sounds/Hello1.wav"
    if [ -n "\$output" ]; then
      tar czf "\$output" -C "\$tmppack" og-packs-1.0.0
    fi
    rm -rf "\$tmppack"
    ;;
  *)
    if [ -n "\$output" ]; then
      echo "mock" > "\$output"
    fi
    ;;
esac
exit 0
MOCK_CURL
  chmod +x "$MOCK_BIN/curl"

  # Mock python3 — simulate registry JSON parser output
  cat > "$MOCK_BIN/python3" <<'MOCK_PYTHON'
#!/bin/bash
echo "PeonPing/og-packs"
echo "v1.0.0"
echo "peon"
MOCK_PYTHON
  chmod +x "$MOCK_BIN/python3"

  # Mock uname — report Darwin
  cat > "$MOCK_BIN/uname" <<'SCRIPT'
#!/bin/bash
echo "Darwin"
SCRIPT
  chmod +x "$MOCK_BIN/uname"

  # Mock afplay — prevent actual sound playback
  cat > "$MOCK_BIN/afplay" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/afplay"

  export PATH="$MOCK_BIN:$PATH"
}

teardown() {
  rm -rf "$TEST_HOME" "$MOCK_BIN"
}

# ============================================================
# Syntax
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$OPENCODE_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Fresh install
# ============================================================

@test "fresh install creates plugin, config, and pack" {
  bash "$OPENCODE_SH"
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
  [ -f "$CONFIG_DIR/config.json" ]
  [ -d "$PACKS_DIR/peon" ]
}

@test "config.json has correct defaults and all CESP categories" {
  bash "$OPENCODE_SH"
  /usr/bin/python3 -c "
import json
c = json.load(open('$CONFIG_DIR/config.json'))
assert c['active_pack'] == 'peon'
assert c['volume'] == 0.5
assert c['enabled'] == True
assert c['spam_threshold'] == 3
assert c['debounce_ms'] == 500
expected = [
  'session.start', 'session.end', 'task.acknowledge',
  'task.complete', 'task.error', 'task.progress',
  'input.required', 'resource.limit', 'user.spam'
]
for cat in expected:
    assert cat in c['categories'], f'Missing: {cat}'
    assert c['categories'][cat] == True
"
}

# ============================================================
# Idempotency / re-install
# ============================================================

@test "re-install preserves existing config" {
  bash "$OPENCODE_SH"
  /usr/bin/python3 -c "
import json
c = json.load(open('$CONFIG_DIR/config.json'))
c['volume'] = 0.9
json.dump(c, open('$CONFIG_DIR/config.json', 'w'))
"
  bash "$OPENCODE_SH"
  volume=$(/usr/bin/python3 -c "import json; print(json.load(open('$CONFIG_DIR/config.json'))['volume'])")
  [ "$volume" = "0.9" ]
}

@test "re-install overwrites plugin file" {
  bash "$OPENCODE_SH"
  echo "// old plugin" > "$PLUGINS_DIR/peon-ping.ts"
  bash "$OPENCODE_SH"
  content=$(cat "$PLUGINS_DIR/peon-ping.ts")
  [[ "$content" == *"peon-ping plugin"* ]]
}

@test "re-install skips pack if already installed" {
  bash "$OPENCODE_SH"
  echo "marker" > "$PACKS_DIR/peon/marker.txt"
  bash "$OPENCODE_SH"
  [ -f "$PACKS_DIR/peon/marker.txt" ]
}

# ============================================================
# Broken symlink fix (fix-curl-symlink)
# ============================================================

@test "install removes broken symlink before downloading plugin" {
  mkdir -p "$PLUGINS_DIR"
  ln -sf /nonexistent/path "$PLUGINS_DIR/peon-ping.ts"
  [ -L "$PLUGINS_DIR/peon-ping.ts" ]

  bash "$OPENCODE_SH"
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
  [ ! -L "$PLUGINS_DIR/peon-ping.ts" ]
}

# ============================================================
# Uninstall
# ============================================================

@test "uninstall removes plugin and config but preserves packs" {
  bash "$OPENCODE_SH"
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
  [ -d "$CONFIG_DIR" ]
  [ -d "$PACKS_DIR" ]

  run bash "$OPENCODE_SH" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$PLUGINS_DIR/peon-ping.ts" ]
  [ ! -d "$CONFIG_DIR" ]
  [ -d "$PACKS_DIR" ]
}

# ============================================================
# XDG_CONFIG_HOME support
# ============================================================

@test "XDG_CONFIG_HOME overrides default config path" {
  export XDG_CONFIG_HOME="$TEST_HOME/custom-config"
  bash "$OPENCODE_SH"
  [ -f "$TEST_HOME/custom-config/opencode/plugins/peon-ping.ts" ]
  [ -f "$TEST_HOME/custom-config/opencode/peon-ping/config.json" ]
}

# ============================================================
# Curl dependency
# ============================================================

@test "install fails if curl is not available" {
  rm -f "$MOCK_BIN/curl"
  for cmd in printf uname grep env sed find head; do
    [ -x "/usr/bin/$cmd" ] && ln -sf "/usr/bin/$cmd" "$MOCK_BIN/$cmd" 2>/dev/null || true
  done
  export PATH="$MOCK_BIN:/bin"
  run bash "$OPENCODE_SH"
  [ "$status" -ne 0 ]
}

# ============================================================
# Relay config fields
# ============================================================

@test "re-install preserves user-added relay_host and relay_port in config" {
  bash "$OPENCODE_SH"
  /usr/bin/python3 -c "
import json
c = json.load(open('$CONFIG_DIR/config.json'))
c['relay_host'] = 'my-relay.local'
c['relay_port'] = 12345
json.dump(c, open('$CONFIG_DIR/config.json', 'w'))
"
  bash "$OPENCODE_SH"
  /usr/bin/python3 -c "
import json
c = json.load(open('$CONFIG_DIR/config.json'))
assert c.get('relay_host') == 'my-relay.local', f'relay_host lost: {c}'
assert c.get('relay_port') == 12345, f'relay_port lost: {c}'
"
}

# ============================================================
# Registry failure graceful handling
# ============================================================

@test "install succeeds even if registry is unreachable" {
  cat > "$MOCK_BIN/curl" <<'MOCK_CURL'
#!/bin/bash
url=""
output=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o) output="${args[$((i+1))]}" ;;
    http*) url="${args[$i]}" ;;
  esac
done
case "$url" in
  *peon-ping.ts)
    echo '// plugin' > "$output"
    exit 0
    ;;
  *index.json)
    exit 1
    ;;
  *)
    if [ -n "$output" ]; then echo "mock" > "$output"; fi
    exit 0
    ;;
esac
MOCK_CURL
  chmod +x "$MOCK_BIN/curl"

  cat > "$MOCK_BIN/python3" <<'MOCK_PYTHON'
#!/bin/bash
exit 1
MOCK_PYTHON
  chmod +x "$MOCK_BIN/python3"

  run bash "$OPENCODE_SH"
  [ "$status" -eq 0 ]
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
  [ -f "$CONFIG_DIR/config.json" ]
}
