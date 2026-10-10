#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Tests for adapters/opencode.sh — the OpenCode adapter install script.
# The adapter is a thin wrapper: it downloads peon-ping.ts and relies on
# peon.sh (installed separately) for config, packs, and audio playback.

setup() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  OPENCODE_SH="$REPO_ROOT/adapters/opencode.sh"

  unset XDG_CONFIG_HOME
  unset CLAUDE_PEON_DIR CLAUDE_CONFIG_DIR
  PLUGINS_DIR="$TEST_HOME/.config/opencode/plugins"

  # Mock peon.sh — satisfies preflight check
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping"
  cat > "$TEST_HOME/.claude/hooks/peon-ping/peon.sh" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$TEST_HOME/.claude/hooks/peon-ping/peon.sh"

  # --- Mock bin directory ---
  MOCK_BIN="$(mktemp -d)"

  # Mock opencode — default to v2
  OPENCODE_VERSION="${OPENCODE_VERSION:-2.0.0}"
  cat > "$MOCK_BIN/opencode" <<'MOCK_OC'
#!/bin/bash
echo "$OPENCODE_VERSION"
MOCK_OC
  chmod +x "$MOCK_BIN/opencode"

  # Mock curl — simulate downloading peon-ping.ts (v1 or v2)
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
  *peon-ping-v1.ts|*peon-ping-v2.ts|*peon-ping.ts)
    if [ -n "$output" ]; then
      echo '// peon-ping plugin for OpenCode' > "$output"
    fi
    ;;
  *)
    if [ -n "$output" ]; then
      echo "mock" > "$output"
    fi
    ;;
esac
exit 0
MOCK_CURL
  chmod +x "$MOCK_BIN/curl"

  # Mock uname — report Darwin
  cat > "$MOCK_BIN/uname" <<'SCRIPT'
#!/bin/bash
echo "Darwin"
SCRIPT
  chmod +x "$MOCK_BIN/uname"

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
# Preflight
# ============================================================

@test "install fails when peon.sh is not found" {
  rm -f "$TEST_HOME/.claude/hooks/peon-ping/peon.sh"
  run bash "$OPENCODE_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"peon.sh not found"* ]]
}

# ============================================================
# Fresh install
# ============================================================

@test "fresh install downloads plugin" {
  bash "$OPENCODE_SH"
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
}

# ============================================================
# Idempotency / re-install
# ============================================================

@test "re-install overwrites plugin file" {
  bash "$OPENCODE_SH"
  echo "// old plugin" > "$PLUGINS_DIR/peon-ping.ts"
  bash "$OPENCODE_SH"
  content=$(cat "$PLUGINS_DIR/peon-ping.ts")
  [[ "$content" == *"peon-ping plugin"* ]]
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

@test "uninstall removes plugin file" {
  bash "$OPENCODE_SH"
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
  run bash "$OPENCODE_SH" --uninstall
  [ "$status" -eq 0 ]
  [ ! -f "$PLUGINS_DIR/peon-ping.ts" ]
}

# ============================================================
# Version detection
# ============================================================

@test "detects OpenCode v1 and downloads peon-ping-v1.ts" {
  OPENCODE_VERSION="1.18.35" bash "$OPENCODE_SH"
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
}

@test "detects OpenCode v2 and downloads peon-ping-v2.ts" {
  OPENCODE_VERSION="2.0.0" bash "$OPENCODE_SH"
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
}

# ============================================================
# XDG_CONFIG_HOME support
# ============================================================

@test "XDG_CONFIG_HOME overrides default config path" {
  export XDG_CONFIG_HOME="$TEST_HOME/custom-config"
  bash "$OPENCODE_SH"
  [ -f "$TEST_HOME/custom-config/opencode/plugins/peon-ping.ts" ]
}

@test "custom hook directory allows installation outside ~/.claude" {
  export CLAUDE_PEON_DIR="$TEST_HOME/custom hook"
  mkdir -p "$CLAUDE_PEON_DIR"
  mv "$TEST_HOME/.claude/hooks/peon-ping/peon.sh" "$CLAUDE_PEON_DIR/peon.sh"
  run bash "$OPENCODE_SH"
  [ "$status" -eq 0 ]
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
}

@test "OpenPeon hook installation satisfies adapter preflight" {
  mkdir -p "$TEST_HOME/.openpeon/hooks/peon-ping"
  mv "$TEST_HOME/.claude/hooks/peon-ping/peon.sh" "$TEST_HOME/.openpeon/hooks/peon-ping/peon.sh"
  run bash "$OPENCODE_SH"
  [ "$status" -eq 0 ]
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
}

# ============================================================
# Curl dependency
# ============================================================

@test "install fails if curl is not available" {
  rm -f "$MOCK_BIN/curl"
  for cmd in printf uname grep env sed find head; do
    [ -x "/usr/bin/$cmd" ] && ln -sf "/usr/bin/$cmd" "$MOCK_BIN/$cmd" 2>/dev/null || true
  done
  # Use MOCK_BIN only so curl cannot be found (it may live in /bin or /usr/bin)
  old_path="$PATH"
  export PATH="$MOCK_BIN"
  run -127 bash "$OPENCODE_SH"
  export PATH="$old_path"
}

# ============================================================
# Adapter installs without registry
# ============================================================

@test "adapter installs even when registry not needed" {
  run bash "$OPENCODE_SH"
  [ "$status" -eq 0 ]
  [ -f "$PLUGINS_DIR/peon-ping.ts" ]
}
