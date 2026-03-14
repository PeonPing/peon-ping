#!/usr/bin/env bats
# Tests for scripts/hook-handle-use.sh

load setup.bash

HOOK_SCRIPT=""

setup() {
  setup_test_env
  # Derive hook script path from PEON_SH (already resolved by setup_test_env)
  HOOK_SCRIPT="$(dirname "$PEON_SH")/scripts/hook-handle-use.sh"

  # hook-handle-use.sh reads CLAUDE_CONFIG_DIR to find peon install dir
  export CLAUDE_CONFIG_DIR="$TEST_DIR"

  # Create the hooks/peon-ping layout that hook-handle-use.sh expects
  mkdir -p "$TEST_DIR/hooks/peon-ping/packs/peon"
  mkdir -p "$TEST_DIR/hooks/peon-ping/packs/sc_kerrigan"

  # Copy config and state into the hooks peon-ping dir
  cp "$TEST_DIR/config.json" "$TEST_DIR/hooks/peon-ping/config.json"
  echo '{}' > "$TEST_DIR/hooks/peon-ping/.state.json"
}

teardown() {
  teardown_test_env
}

# Helper: run hook-handle-use.sh with a JSON payload
run_hook() {
  local json="$1"
  OUTPUT=$(echo "$json" | bash "$HOOK_SCRIPT" 2>/dev/null)
  HOOK_EXIT=$?
}

# ============================================================
# Passthrough behavior
# ============================================================

@test "passthrough: non-/peon-ping-use prompt continues" {
  run_hook '{"session_id":"s1","prompt":"hello world"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == True"
}

@test "passthrough: empty prompt continues" {
  run_hook '{"session_id":"s1","prompt":""}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == True"
}

@test "passthrough: /peon-ping-config is not intercepted" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-config volume 0.8"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == True"
}

# ============================================================
# Pack name extraction (POSIX sed — macOS BSD sed fix)
# ============================================================

@test "extracts pack name with leading spaces" {
  run_hook '{"session_id":"s1","prompt":"  /peon-ping-use peon"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == False, repr(d)"
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'peon' in d.get('user_message','')"
}

@test "extracts pack name: basic /peon-ping-use peon" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use peon"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'peon' in d.get('user_message','')"
}

@test "extracts pack name: pack with underscores (sc_kerrigan)" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use sc_kerrigan"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'sc_kerrigan' in d.get('user_message','')"
}

@test "extracts pack name: ignores trailing text after pack name" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use peon extra stuff"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'peon' in d.get('user_message','')"
}

# ============================================================
# Validation
# ============================================================

@test "rejects pack name with path traversal (../)" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use ../../../etc/passwd"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == False"
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'Invalid' in d.get('user_message','')"
}

@test "rejects pack name with spaces" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use bad name"}'
  [ "$HOOK_EXIT" -eq 0 ]
  # The first word 'bad' is a valid pack name (alphanumeric), but the pack won't exist
  # so we just ensure it doesn't crash and responds correctly
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == False"
}

@test "rejects nonexistent pack" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use nonexistent_pack"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == False"
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'not found' in d.get('user_message','').lower() or 'available' in d.get('user_message','').lower()"
}

# ============================================================
# State update
# ============================================================

@test "success: sets pack in state.json for session" {
  run_hook '{"session_id":"test-session-123","prompt":"/peon-ping-use peon"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == False"

  # Verify state was written
  python3 -c "
import json
state = json.load(open('$TEST_DIR/hooks/peon-ping/.state.json'))
assert 'session_packs' in state, 'session_packs missing from state'
assert 'test-session-123' in state['session_packs'], 'session not in session_packs'
pack = state['session_packs']['test-session-123']
assert isinstance(pack, dict) or pack == 'peon', 'unexpected pack format'
if isinstance(pack, dict):
    assert pack.get('pack') == 'peon', f'wrong pack: {pack}'
"
}

@test "success: sets session_override rotation mode in config.json" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use peon"}'
  [ "$HOOK_EXIT" -eq 0 ]

  python3 -c "
import json
config = json.load(open('$TEST_DIR/hooks/peon-ping/config.json'))
assert config.get('pack_rotation_mode') == 'session_override', f'rotation mode not set: {config}'
"
}

@test "success: returns user_message confirming pack" {
  run_hook '{"session_id":"s1","prompt":"/peon-ping-use peon"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert 'peon' in d.get('user_message','')"
}

@test "fallback to default session when session_id missing" {
  run_hook '{"prompt":"/peon-ping-use peon"}'
  [ "$HOOK_EXIT" -eq 0 ]
  echo "$OUTPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['continue'] == False"
}
