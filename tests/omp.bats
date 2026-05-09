#!/usr/bin/env bats
bats_require_minimum_version 1.5.0

# Tests for the omp (oh-my-pi) adapter.
# Two surfaces under test: peon.sh IDE-resolution tables (Task 1) and
# adapters/omp.sh installer behavior (Task 3).

load setup.bash

# ============================================================
# IDE detection: source-based + session-id-prefix fallback
# ============================================================

setup() {
  setup_test_env
  # Enable IDE name in notification titles so tests can assert display name
  "$PEON_PY" -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['notification_title_ide'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
}

teardown() {
  teardown_test_env
  # Defensive: also clean up installer-group state if a test failed before
  # reaching its in-body teardown_installer_env call.
  if [ -n "${MOCK_BIN_INSTALLER:-}" ]; then
    rm -rf "${TEST_HOME:-/nonexistent}" "$MOCK_BIN_INSTALLER" 2>/dev/null || true
  fi
}

@test "omp source maps to oh-my-pi display name in notifications" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"omp-123","source":"omp","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "myproject - oh-my-pi" "$TEST_DIR/terminal_notifier.log"
}

@test "oh-my-pi alias normalizes to omp" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"x-1","source":"oh-my-pi","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "myproject - oh-my-pi" "$TEST_DIR/terminal_notifier.log"
}

@test "omp- session-id prefix falls back to omp when source missing" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"omp-456","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  [ -f "$TEST_DIR/terminal_notifier.log" ]
  grep -q "myproject - oh-my-pi" "$TEST_DIR/terminal_notifier.log"
}

# ============================================================
# Installer
# ============================================================

setup_installer_env() {
  # Reset any state from the IDE-detection group that might still be set
  unset CLAUDE_PEON_DIR PEON_TEST TEST_DIR

  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  OMP_SH="$REPO_ROOT/adapters/omp.sh"

  unset XDG_CONFIG_HOME
  EXT_DIR="$TEST_HOME/.omp/agent/extensions/peon-ping"

  # Mock peon.sh — satisfies preflight check
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping"
  cat > "$TEST_HOME/.claude/hooks/peon-ping/peon.sh" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$TEST_HOME/.claude/hooks/peon-ping/peon.sh"

  # Mock bin directory
  MOCK_BIN_INSTALLER="$(mktemp -d)"

  # Mock curl — return canned content for adapter URLs
  cat > "$MOCK_BIN_INSTALLER/curl" <<'MOCK_CURL'
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
  *adapters/omp/peon-ping.ts)
    [ -n "$output" ] && echo '// peon-ping adapter for oh-my-pi (omp)' > "$output"
    ;;
  *adapters/omp/package.json)
    [ -n "$output" ] && cat > "$output" <<'EOF'
{ "name": "peon-ping", "omp": { "extensions": ["./peon-ping.ts"] } }
EOF
    ;;
  *)
    [ -n "$output" ] && echo "mock" > "$output"
    ;;
esac
exit 0
MOCK_CURL
  chmod +x "$MOCK_BIN_INSTALLER/curl"

  export PATH="$MOCK_BIN_INSTALLER:$PATH"
}

teardown_installer_env() {
  rm -rf "$TEST_HOME" "$MOCK_BIN_INSTALLER" 2>/dev/null
}

@test "installer: script has valid bash syntax" {
  setup_installer_env
  run bash -n "$OMP_SH"
  [ "$status" -eq 0 ]
  teardown_installer_env
}

@test "installer: fails when peon.sh is not found" {
  setup_installer_env
  rm -f "$TEST_HOME/.claude/hooks/peon-ping/peon.sh"
  run bash "$OMP_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"peon.sh not found"* ]]
  teardown_installer_env
}

@test "installer: fresh install writes extension files" {
  setup_installer_env
  run bash "$OMP_SH"
  [ "$status" -eq 0 ]
  [ -f "$EXT_DIR/peon-ping.ts" ]
  [ -f "$EXT_DIR/package.json" ]
  grep -q "peon-ping adapter for oh-my-pi" "$EXT_DIR/peon-ping.ts"
  grep -q "\"omp\"" "$EXT_DIR/package.json"
  teardown_installer_env
}

@test "installer: re-install is idempotent and overwrites stale content" {
  setup_installer_env
  bash "$OMP_SH"
  echo "// stale" > "$EXT_DIR/peon-ping.ts"
  bash "$OMP_SH"
  grep -q "peon-ping adapter for oh-my-pi" "$EXT_DIR/peon-ping.ts"
  teardown_installer_env
}

@test "installer: --uninstall removes extension directory" {
  setup_installer_env
  bash "$OMP_SH"
  [ -d "$EXT_DIR" ]
  run bash "$OMP_SH" --uninstall
  [ "$status" -eq 0 ]
  [ ! -d "$EXT_DIR" ]
  teardown_installer_env
}

@test "installer: PEON_PING_LOCAL_ADAPTER_DIR env var copies from local path instead of curl" {
  setup_installer_env
  # Pretend we're running from a checkout
  LOCAL_SRC="$(mktemp -d)"
  mkdir -p "$LOCAL_SRC/adapters/omp"
  echo '// local checkout content' > "$LOCAL_SRC/adapters/omp/peon-ping.ts"
  echo '{"name":"peon-ping","omp":{"extensions":["./peon-ping.ts"]}}' \
    > "$LOCAL_SRC/adapters/omp/package.json"
  # Break curl so we know it wasn't used
  cat > "$MOCK_BIN_INSTALLER/curl" <<'BREAK'
#!/bin/bash
exit 99
BREAK
  chmod +x "$MOCK_BIN_INSTALLER/curl"

  PEON_PING_LOCAL_ADAPTER_DIR="$LOCAL_SRC/adapters/omp" run bash "$OMP_SH"
  [ "$status" -eq 0 ]
  grep -q "local checkout content" "$EXT_DIR/peon-ping.ts"
  rm -rf "$LOCAL_SRC"
  teardown_installer_env
}
