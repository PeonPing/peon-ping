#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Create a mock Trae sessions directory
  export TRAE_SESSIONS_DIR="$TEST_DIR/sessions"
  mkdir -p "$TRAE_SESSIONS_DIR"

  # Copy peon.sh into test dir so the adapter can find it
  cp "$PEON_SH" "$TEST_DIR/peon.sh"

  # Mock fswatch so preflight passes
  cat > "$MOCK_BIN/fswatch" <<'SCRIPT'
#!/bin/bash
sleep 999
SCRIPT
  chmod +x "$MOCK_BIN/fswatch"

  ADAPTER_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/adapters/trae.sh"
}

teardown() {
  teardown_test_env
}

# Helper: source the adapter in test mode so all functions are available
# but the main watcher loop is skipped.
source_adapter() {
  export PEON_ADAPTER_TEST=1
  export TMPDIR="$TEST_DIR"
  source "$ADAPTER_SH" 2>/dev/null
  # Restore BATS-friendly settings (adapter sets -euo pipefail)
  set +e +u
  set +o pipefail 2>/dev/null || true
}

# Helper: create a session JSON file for a given id
create_session() {
  local sid="$1"
  printf '{"messages":[]}' > "$TRAE_SESSIONS_DIR/${sid}.json"
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$ADAPTER_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Preflight
# ============================================================

@test "exits with error when peon.sh is not found" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  CLAUDE_PEON_DIR="$empty_dir" run bash "$ADAPTER_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"peon.sh not found"* ]]
  rm -rf "$empty_dir"
}

@test "exits with error when no filesystem watcher is available" {
  rm -f "$MOCK_BIN/fswatch"
  rm -f "$MOCK_BIN/inotifywait"
  PATH="$MOCK_BIN:/usr/bin:/bin" run bash "$ADAPTER_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No filesystem watcher found"* ]]
}

# ============================================================
# State tracking
# ============================================================

@test "session_get returns empty for unknown id" {
  source_adapter
  result=$(session_get "unknown-sess-1234")
  [ -z "$result" ]
}

@test "session_set and session_get round-trip correctly" {
  source_adapter
  session_set "sess-aaaa" "active"
  [ "$(session_get "sess-aaaa")" = "active" ]
  session_set "sess-aaaa" "idle"
  [ "$(session_get "sess-aaaa")" = "idle" ]
}

@test "stop_time_get returns 0 for unknown id" {
  source_adapter
  [ "$(stop_time_get "unknown-sess-5678")" = "0" ]
}

@test "stop_time_set and stop_time_get round-trip correctly" {
  source_adapter
  stop_time_set "sess-bbbb" "1700000000"
  [ "$(stop_time_get "sess-bbbb")" = "1700000000" ]
}

# ============================================================
# handle_session_change: new session triggers SessionStart
# ============================================================

@test "new session file triggers SessionStart and plays greeting" {
  source_adapter
  local sid="brand-new-0001"
  create_session "$sid"

  handle_session_change "$TRAE_SESSIONS_DIR/${sid}.json"

  [ "$(session_get "$sid")" = "active" ]

  sleep 0.5
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "known session update does not emit duplicate SessionStart" {
  source_adapter
  local sid="known-0002"
  session_set "$sid" "idle"
  create_session "$sid"

  handle_session_change "$TRAE_SESSIONS_DIR/${sid}.json"

  [ "$(session_get "$sid")" = "active" ]
  sleep 0.3
  [ "$(afplay_call_count)" -eq 0 ]
}

# ============================================================
# check_idle_sessions: emits Stop for stale active sessions
# ============================================================

@test "idle active session emits Stop event" {
  export TRAE_IDLE_SECONDS=1
  source_adapter
  local sid="idle-test-0003"
  create_session "$sid"
  session_set "$sid" "active"

  sleep 2
  check_idle_sessions

  [ "$(session_get "$sid")" = "idle" ]
  sleep 0.5
  afplay_was_called
}

@test "cooldown prevents duplicate Stop events" {
  export TRAE_IDLE_SECONDS=1
  export TRAE_STOP_COOLDOWN=60
  source_adapter
  local sid="cooldown-0004"
  create_session "$sid"
  session_set "$sid" "active"

  stop_time_set "$sid" "$(date +%s)"

  sleep 2
  check_idle_sessions

  [ "$(session_get "$sid")" = "idle" ]
  sleep 0.3
  [ "$(afplay_call_count)" -eq 0 ]
}

# ============================================================
# Session id prefix
# ============================================================

@test "emit_event tags session id with trae- prefix" {
  source_adapter
  emit_event "Stop" "prefix-0005"
  sleep 0.5
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'trae-prefix-0005', last
"
}
