#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Create a mock Kimi sessions directory
  export KIMI_SESSIONS_DIR="$TEST_DIR/sessions"
  export KIMI_DIR="$TEST_DIR/kimi_home"
  mkdir -p "$KIMI_SESSIONS_DIR"
  mkdir -p "$KIMI_DIR"

  # Copy peon.sh into test dir so the adapter can find it
  cp "$PEON_SH" "$TEST_DIR/peon.sh"

  # Mock fswatch so preflight passes
  cat > "$MOCK_BIN/fswatch" <<'SCRIPT'
#!/bin/bash
sleep 999
SCRIPT
  chmod +x "$MOCK_BIN/fswatch"

  ADAPTER_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/adapters/kimi.sh"
}

teardown() {
  # Kill any lingering daemon processes from --install tests
  if [ -f "$TEST_DIR/.kimi-adapter.pid" ]; then
    pid=$(cat "$TEST_DIR/.kimi-adapter.pid" 2>/dev/null)
    if [ -n "$pid" ]; then
      pkill -P "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$TEST_DIR/.kimi-adapter.pid"
  fi
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

# Helper: create a mock wire.jsonl event line
# Usage: create_wire_event <workspace_hash> <session_uuid> <event_type> [payload_json]
create_wire_event() {
  local ws_hash="$1"
  local uuid="$2"
  local event_type="$3"
  local payload="${4:-{}}"

  local session_dir="$KIMI_SESSIONS_DIR/$ws_hash/$uuid"
  mkdir -p "$session_dir"

  local ts
  ts=$(python3 -c "import time; print(time.time())")

  echo "{\"timestamp\": $ts, \"message\": {\"type\": \"$event_type\", \"payload\": $payload}}" \
    >> "$session_dir/wire.jsonl"
}

# Helper: create a mock kimi.json with workspace mappings
create_kimi_config() {
  local path="$1"
  local hash="$2"

  cat > "$KIMI_DIR/kimi.json" <<JSON
{
  "work_dirs": [
    {"path": "$path"}
  ]
}
JSON
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$ADAPTER_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Daemon: --install / --uninstall / --status
# ============================================================

@test "--install with running process is idempotent" {
  # Simulate a running daemon by creating a pidfile with a live PID
  sleep 999 &
  local mock_pid=$!
  echo "$mock_pid" > "$TEST_DIR/.kimi-adapter.pid"

  run bash "$ADAPTER_SH" --install
  [ "$status" -eq 0 ]
  [[ "$output" == *"already running"* ]]

  kill "$mock_pid" 2>/dev/null || true
}

@test "--status reports running when pidfile has live process" {
  sleep 999 &
  local mock_pid=$!
  echo "$mock_pid" > "$TEST_DIR/.kimi-adapter.pid"

  run bash "$ADAPTER_SH" --status
  [ "$status" -eq 0 ]
  [[ "$output" == *"is running"* ]]

  kill "$mock_pid" 2>/dev/null || true
}

@test "--status reports not running when no pidfile" {
  run bash "$ADAPTER_SH" --status
  [ "$status" -eq 1 ]
  [[ "$output" == *"not running"* ]]
}

@test "--status cleans up stale pidfile" {
  echo "99999999" > "$TEST_DIR/.kimi-adapter.pid"
  run bash "$ADAPTER_SH" --status
  [ "$status" -eq 1 ]
  [[ "$output" == *"stale PID"* ]]
  [ ! -f "$TEST_DIR/.kimi-adapter.pid" ]
}

@test "--uninstall stops a running process" {
  sleep 999 &
  local mock_pid=$!
  echo "$mock_pid" > "$TEST_DIR/.kimi-adapter.pid"

  run bash "$ADAPTER_SH" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopped"* ]]
  [ ! -f "$TEST_DIR/.kimi-adapter.pid" ]

  # Process should be dead
  sleep 0.3
  ! kill -0 "$mock_pid" 2>/dev/null
}

@test "--uninstall when not running reports cleanly" {
  run bash "$ADAPTER_SH" --uninstall
  [ "$status" -eq 0 ]
  [[ "$output" == *"not running"* ]]
}

# ============================================================
# Preflight: missing peon.sh
# ============================================================

@test "exits with error when peon.sh is not found" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  CLAUDE_PEON_DIR="$empty_dir" run bash "$ADAPTER_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"peon.sh not found"* ]]
  rm -rf "$empty_dir"
}

# ============================================================
# Preflight: missing filesystem watcher
# ============================================================

@test "exits with error when no filesystem watcher is available" {
  rm -f "$MOCK_BIN/fswatch"
  rm -f "$MOCK_BIN/inotifywait"
  PATH="$MOCK_BIN:/usr/bin:/bin" run bash "$ADAPTER_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No filesystem watcher found"* ]]
}

# ============================================================
# State tracking: session_get / session_set
# ============================================================

@test "session_get returns empty for unknown session" {
  source_adapter
  result=$(session_get "unknown-uuid-1234")
  [ -z "$result" ]
}

@test "session_set and session_get round-trip correctly" {
  source_adapter
  session_set "test-uuid-aaaa" "active"
  result=$(session_get "test-uuid-aaaa")
  [ "$result" = "active" ]

  session_set "test-uuid-aaaa" "idle"
  result=$(session_get "test-uuid-aaaa")
  [ "$result" = "idle" ]
}

# ============================================================
# Cooldown tracking: stop_time_get / stop_time_set
# ============================================================

@test "stop_time_get returns 0 for unknown session" {
  source_adapter
  result=$(stop_time_get "unknown-uuid-5678")
  [ "$result" = "0" ]
}

@test "stop_time_set and stop_time_get round-trip correctly" {
  source_adapter
  stop_time_set "test-uuid-bbbb" "1700000000"
  result=$(stop_time_get "test-uuid-bbbb")
  [ "$result" = "1700000000" ]
}

# ============================================================
# resolve_cwd: maps workspace hash to path via kimi.json
# ============================================================

@test "resolve_cwd maps workspace hash to path via kimi.json" {
  source_adapter

  # Create a kimi.json with a known path
  local test_path="/Users/dev/myproject"
  create_kimi_config "$test_path" ""

  # Compute the md5 hash of the path
  local hash
  hash=$(python3 -c "import hashlib; print(hashlib.md5('$test_path'.encode()).hexdigest())")

  result=$(resolve_cwd "$hash")
  [ "$result" = "$test_path" ]
}

@test "resolve_cwd returns PWD for unknown workspace hash" {
  source_adapter
  create_kimi_config "/some/other/path" ""

  result=$(resolve_cwd "0000000000000000deadbeef00000000")
  [ -n "$result" ]
}

# ============================================================
# New session TurnBegin triggers SessionStart
# ============================================================

@test "new session TurnBegin triggers SessionStart and plays greeting sound" {
  source_adapter
  local ws_hash="abc123"
  local uuid="new-session-0001"

  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  # State should be active
  result=$(session_get "$uuid")
  [ "$result" = "active" ]

  # Give async audio a moment (peon.sh uses nohup &)
  sleep 0.5

  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

# ============================================================
# Subsequent TurnBegin does NOT re-trigger SessionStart
# ============================================================

@test "subsequent TurnBegin in known session does not re-trigger SessionStart" {
  source_adapter
  local ws_hash="abc123"
  local uuid="known-session-0002"

  # Pre-register as known
  session_set "$uuid" "active"

  # Create the wire event
  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  # State should still be active
  result=$(session_get "$uuid")
  [ "$result" = "active" ]

  # No greeting sound should play (UserPromptSubmit doesn't trigger on first prompt)
  sleep 0.3
  # Single prompt doesn't trigger spam sound
  count=$(afplay_call_count)
  [ "$count" -eq 0 ]
}

# ============================================================
# TurnEnd triggers Stop and plays completion sound
# ============================================================

@test "TurnEnd triggers Stop and plays completion sound" {
  source_adapter
  local ws_hash="abc123"
  local uuid="stop-session-0003"

  # Pre-register session
  session_set "$uuid" "active"

  create_wire_event "$ws_hash" "$uuid" "TurnEnd" '{}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  # Give async audio a moment
  sleep 0.5

  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

# ============================================================
# CompactionBegin triggers PreCompact
# ============================================================

@test "CompactionBegin triggers PreCompact and plays resource.limit sound" {
  source_adapter
  local ws_hash="abc123"
  local uuid="compact-session-0004"

  # Pre-register session
  session_set "$uuid" "active"

  create_wire_event "$ws_hash" "$uuid" "CompactionBegin" '{}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  sleep 0.5

  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Limit"* ]]
}

# ============================================================
# SubagentEvent with nested TurnBegin triggers SubagentStart
# ============================================================

@test "SubagentEvent with nested TurnBegin triggers SubagentStart" {
  source_adapter
  local ws_hash="abc123"
  local uuid="subagent-session-0005"

  # Pre-register session
  session_set "$uuid" "active"

  create_wire_event "$ws_hash" "$uuid" "SubagentEvent" '{"message": {"type": "TurnBegin", "payload": {}}}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  # SubagentStart is tracked but doesn't play a sound by default
  # Just verify no crash and state is still valid
  result=$(session_get "$uuid")
  [ "$result" = "active" ]
}

# ============================================================
# Unknown/noisy events are silently skipped
# ============================================================

@test "unknown events (ContentPart, ToolCall) are silently skipped" {
  source_adapter
  local ws_hash="abc123"
  local uuid="noisy-session-0006"

  session_set "$uuid" "active"

  create_wire_event "$ws_hash" "$uuid" "ContentPart" '{"text": "hello"}'
  create_wire_event "$ws_hash" "$uuid" "ToolCall" '{"name": "Read"}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  sleep 0.3
  count=$(afplay_call_count)
  [ "$count" -eq 0 ]
}

# ============================================================
# Stop cooldown prevents duplicate sounds
# ============================================================

@test "Stop cooldown prevents duplicate Stop sounds" {
  export KIMI_STOP_COOLDOWN=60
  source_adapter
  local ws_hash="abc123"
  local uuid="cooldown-session-0007"

  session_set "$uuid" "active"

  # Set a recent stop time (within cooldown window)
  local now
  now=$(date +%s)
  stop_time_set "$uuid" "$now"

  create_wire_event "$ws_hash" "$uuid" "TurnEnd" '{}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  # No sound should play (cooldown suppressed the Stop event)
  sleep 0.3
  count=$(afplay_call_count)
  [ "$count" -eq 0 ]
}

# ============================================================
# /clear detection: suppress Stop for old session
# ============================================================

@test "TurnEnd for old session is suppressed when /clear creates a new session" {
  source_adapter
  local ws_hash="abc123"
  local old_uuid="old-session-clear-01"
  local new_uuid="new-session-clear-01"

  # Pre-register old session
  session_set "$old_uuid" "active"

  # New session created (simulates /clear creating a new session)
  create_wire_event "$ws_hash" "$new_uuid" "TurnBegin" '{"user_input": []}'
  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$new_uuid/wire.jsonl"
  sleep 0.5

  # Clear afplay log (SessionStart may or may not have played depending on config)
  rm -f "$TEST_DIR/afplay.log"

  # Old session ends (TurnEnd arrives right after /clear)
  create_wire_event "$ws_hash" "$old_uuid" "TurnEnd" '{}'
  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$old_uuid/wire.jsonl"

  # Stop should be suppressed — it's from the /clear teardown, not a real completion
  sleep 0.3
  count=$(afplay_call_count)
  [ "$count" -eq 0 ]
}

@test "TurnEnd for same session is NOT suppressed (normal completion)" {
  source_adapter
  local ws_hash="abc123"
  local uuid="normal-complete-01"

  # New session created
  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'
  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"
  sleep 0.5
  rm -f "$TEST_DIR/afplay.log"

  # Same session ends normally (TurnEnd for the same UUID)
  create_wire_event "$ws_hash" "$uuid" "TurnEnd" '{}'
  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  # Should play completion sound — this is a normal turn end, not a /clear
  sleep 0.5
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

# ============================================================
# Pre-existing sessions at startup are not treated as new
# ============================================================

@test "pre-existing sessions at startup are not treated as new sessions" {
  local ws_hash="abc123"
  local uuid="existing-session-0008"

  # Create session files BEFORE sourcing the adapter
  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  source_adapter

  # The session should already be in state as "active" (pre-registered)
  result=$(session_get "$uuid")
  [ "$result" = "active" ]

  # Adding a new TurnBegin should NOT fire SessionStart (already known)
  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"
  sleep 0.3
  # Single additional prompt = no spam sound
  count=$(afplay_call_count)
  [ "$count" -eq 0 ]
}

# ============================================================
# Paused state suppresses sounds
# ============================================================

@test "paused state (.paused file) suppresses sounds" {
  source_adapter
  touch "$TEST_DIR/.paused"

  local ws_hash="abc123"
  local uuid="paused-session-0009"

  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  sleep 0.3
  ! afplay_was_called
}

# ============================================================
# enabled=false suppresses sounds
# ============================================================

@test "enabled=false suppresses sounds" {
  source_adapter

  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON

  local ws_hash="abc123"
  local uuid="disabled-session-0010"

  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  sleep 0.3
  ! afplay_was_called
}

# ============================================================
# Volume config is passed through
# ============================================================

@test "volume config is passed through to afplay" {
  source_adapter

  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON

  local ws_hash="abc123"
  local uuid="volume-session-0011"

  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"

  sleep 0.5
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Byte offset tracking: only new lines are processed
# ============================================================

@test "byte offset tracking only processes new lines" {
  source_adapter
  local ws_hash="abc123"
  local uuid="offset-session-0012"

  # Write a TurnBegin event (new session → greeting)
  create_wire_event "$ws_hash" "$uuid" "TurnBegin" '{"user_input": []}'

  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"
  sleep 0.5
  count1=$(afplay_call_count)
  [ "$count1" -eq 1 ]

  # Call handle_wire_change again without new data — should not replay
  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"
  sleep 0.3
  count2=$(afplay_call_count)
  [ "$count2" -eq 1 ]

  # Now add a TurnEnd — should process only the new line
  create_wire_event "$ws_hash" "$uuid" "TurnEnd" '{}'
  handle_wire_change "$KIMI_SESSIONS_DIR/$ws_hash/$uuid/wire.jsonl"
  sleep 0.5
  count3=$(afplay_call_count)
  [ "$count3" -eq 2 ]
}

# ============================================================
# Non-wire.jsonl files are ignored
# ============================================================

@test "non-wire.jsonl files are ignored" {
  source_adapter

  handle_wire_change "$KIMI_SESSIONS_DIR/abc123/some-uuid/metadata.json"
  handle_wire_change "$KIMI_SESSIONS_DIR/abc123/some-uuid/events.log"

  sleep 0.3
  count=$(afplay_call_count)
  [ "$count" -eq 0 ]
}
