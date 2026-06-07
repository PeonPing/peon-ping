#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Kiro IDE adapter (distinct from the Kiro CLI adapter / tests/kiro.bats)
  KIRO_IDE_SH="${PEON_SH%/peon.sh}/adapters/kiro-ide.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Kiro IDE passes the event name as argv (no stdin payload).
run_kiro_ide() {
  local event="$1"
  export PEON_TEST=1
  bash "$KIRO_IDE_SH" "$event" 2>"$TEST_DIR/stderr.log"
  KI_EXIT=$?
  KI_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$KIRO_IDE_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Event mapping
# ============================================================

@test "agentStop maps to Stop and plays completion sound" {
  run_kiro_ide "agentStop"
  [ "$KI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "sessionStart maps to SessionStart and plays greeting" {
  run_kiro_ide "sessionStart"
  [ "$KI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "preToolUse maps to PermissionRequest and plays input.required sound" {
  run_kiro_ide "preToolUse"
  [ "$KI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "promptSubmit maps to UserPromptSubmit and plays no sound" {
  run_kiro_ide "promptSubmit"
  [ "$KI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "default (no argument) maps to agentStop" {
  export PEON_TEST=1
  bash "$KIRO_IDE_SH" 2>"$TEST_DIR/stderr.log"
  KI_EXIT=$?
  [ "$KI_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

# ============================================================
# Skipped events
# ============================================================

@test "postToolUse exits gracefully without sound" {
  run_kiro_ide "postToolUse"
  [ "$KI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "fileEdited (file event) exits gracefully without sound" {
  run_kiro_ide "fileEdited"
  [ "$KI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "unknown event is skipped gracefully" {
  run_kiro_ide "some_future_event"
  [ "$KI_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses Kiro IDE sounds" {
  touch "$TEST_DIR/.paused"
  run_kiro_ide "agentStop"
  [ "$KI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses Kiro IDE sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_kiro_ide "agentStop"
  [ "$KI_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_kiro_ide "agentStop"
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Session id prefix (distinct kiro-ide- from the CLI's kiro-)
# ============================================================

@test "session_id is prefixed with kiro-ide-" {
  export KIRO_IDE_SESSION_ID="sess7"
  run_kiro_ide "agentStop"
  [ "$KI_EXIT" -eq 0 ]
  /usr/bin/python3 -c "
import json
state = json.load(open('$TEST_DIR/.state.json'))
last = state.get('last_active', {})
assert last.get('session_id') == 'kiro-ide-sess7', last
"
}
