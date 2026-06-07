#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  ECA_SH="${PEON_SH%/peon.sh}/adapters/eca.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# ECA pipes its event JSON on stdin (hook type in the `type` field).
run_eca() {
  local json="$1"
  export PEON_TEST=1
  echo "$json" | bash "$ECA_SH" 2>"$TEST_DIR/stderr.log"
  ECA_EXIT=$?
  ECA_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  sleep 0.3
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$ECA_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Event mapping (type_map from #261)
# ============================================================

@test "sessionStart maps to session.start and plays greeting" {
  run_eca '{"type":"sessionStart","db_cache_path":"s1"}'
  [ "$ECA_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "postRequest maps to Stop and plays completion sound" {
  run_eca '{"type":"postRequest","db_cache_path":"s1"}'
  [ "$ECA_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "preToolCall maps to PermissionRequest and plays input.required sound" {
  run_eca '{"type":"preToolCall","db_cache_path":"s1"}'
  [ "$ECA_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "preRequest maps to UserPromptSubmit and plays no sound" {
  run_eca '{"type":"preRequest","db_cache_path":"s1"}'
  [ "$ECA_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Skipped types
# ============================================================

@test "chatEnd (unmapped) exits gracefully without sound" {
  run_eca '{"type":"chatEnd","db_cache_path":"s1"}'
  [ "$ECA_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "malformed stdin exits gracefully without sound" {
  run_eca 'not json'
  [ "$ECA_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses ECA sounds" {
  touch "$TEST_DIR/.paused"
  run_eca '{"type":"postRequest","db_cache_path":"s1"}'
  [ "$ECA_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses ECA sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_eca '{"type":"postRequest","db_cache_path":"s1"}'
  [ "$ECA_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_eca '{"type":"postRequest","db_cache_path":"s1"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Session id prefix (eca- from db_cache_path)
# ============================================================

@test "session_id is eca- prefixed and derived from db_cache_path" {
  run_eca '{"type":"postRequest","db_cache_path":"abc123"}'
  [ "$ECA_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'eca-abc123', last
"
}
