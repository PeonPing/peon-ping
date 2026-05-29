#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Derive repo root from PEON_SH (set by setup.bash using its own BASH_SOURCE)
  COPILOT_SH="${PEON_SH%/peon.sh}/adapters/copilot.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR — symlink it into the test dir
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Helper: run copilot adapter with an event name argument
# Copilot passes event name as $1 and JSON on stdin
run_copilot() {
  local event="$1"
  # Note: avoid ${2:-{}} — bash closes the expansion at the first }, leaving a
  # trailing literal } that makes the JSON malformed and causes jq to exit 5.
  local json="${2-}"
  if [ -z "$json" ]; then json="{}"; fi
  export PEON_TEST=1
  echo "$json" | bash "$COPILOT_SH" "$event" 2>"$TEST_DIR/stderr.log"
  COPILOT_EXIT=$?
  COPILOT_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  # On macOS peon.sh runs afplay via nohup & (background); wait for mock to finish
  sleep 0.3
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$COPILOT_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Event mapping
#
# The copilot.sh adapter was rewritten to:
#   - skip postToolUse entirely (routing to Stop floods peon.sh's 5s
#     debounce window and swallows real Stop events)
#   - map agentStop -> Stop (Copilot CLI's actual "task done" signal)
#   - map userPromptSubmitted -> UserPromptSubmit (no dual-mode marker file
#     that double-greeted alongside the real sessionStart event)
#   - handle notification, permissionRequest, postToolUseFailure,
#     subagentStart, subagentStop, preCompact, sessionEnd (all silent in
#     the old adapter even though peon.sh handles them)
# ============================================================

@test "sessionStart maps to SessionStart and plays greeting" {
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "agentStop maps to Stop and plays completion sound" {
  run_copilot agentStop '{"sessionId":"test-123","cwd":"/tmp","stopReason":"end_turn"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "postToolUse is intentionally skipped (no Stop flooding)" {
  run_copilot postToolUse '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "errorOccurred maps to PostToolUseFailure and plays error sound" {
  run_copilot errorOccurred '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "postToolUseFailure maps directly to PostToolUseFailure and plays error sound" {
  run_copilot postToolUseFailure '{"sessionId":"test-123","cwd":"/tmp","toolName":"bash","error":"failed"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "userPromptSubmitted maps to UserPromptSubmit (no dual-mode marker)" {
  run_copilot userPromptSubmitted '{"sessionId":"test-456","cwd":"/tmp","prompt":"hello"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  # First prompt does NOT double-greet (the old adapter's dual-mode bug);
  # UserPromptSubmit on first prompt is suppressed by peon.sh's startup
  # grace window. No marker file should be created.
  [ ! -f "$TEST_DIR/.copilot-session-test-456" ]
}

@test "permissionRequest maps to PermissionRequest and plays input.required sound" {
  run_copilot permissionRequest '{"sessionId":"test-123","cwd":"/tmp","toolName":"bash"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
}

@test "notification maps to Notification with notification_type preserved" {
  run_copilot notification '{"sessionId":"test-123","cwd":"/tmp","notificationType":"elicitation_dialog","message":"q?"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  # peon.sh routes elicitation_dialog to input.required and plays a sound
  afplay_was_called
}

# ============================================================
# Skipped events
# ============================================================

@test "sessionEnd maps to SessionEnd (peon decides whether to sound)" {
  run_copilot sessionEnd '{"sessionId":"test-123","cwd":"/tmp","reason":"complete"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  # peon.sh has no session.end category by default — no sound, but adapter
  # still forwards (so peon.sh can log it). This test just asserts no crash.
}

@test "preToolUse maps to PreToolUse (peon.sh's destructive-pattern policy applies)" {
  # peon.sh only emits input.required for matching destructive patterns;
  # innocuous tool input results in no sound.
  run_copilot preToolUse '{"sessionId":"test-123","cwd":"/tmp","toolName":"bash","toolArgs":{"cmd":"ls"}}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "unknown event exits gracefully without sound" {
  run_copilot some_future_event '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# JSON parsing (camelCase -> snake_case field translation)
# ============================================================

@test "extracts sessionId and translates to session_id" {
  run_copilot agentStop '{"sessionId":"custom-session-id","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  # peon.sh tracks state per session_id; we can't directly observe the
  # forwarded payload, but exit=0 + a played sound proves the adapter
  # produced a valid CESP JSON shape with session_id set.
  afplay_was_called
}

@test "extracts cwd from JSON input" {
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/custom/path"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
}

@test "falls back to default sessionId when JSON is empty" {
  run_copilot sessionStart '{}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
}

@test "falls back to PWD when cwd is missing from JSON" {
  run_copilot sessionStart '{"sessionId":"test-123"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
}

@test "translates toolName -> tool_name and toolArgs -> tool_input on preToolUse" {
  # PreToolUse is silent in peon.sh (it only sets the tab to "working"), so
  # verify the field translation directly by capturing what the adapter pipes
  # downstream rather than asserting on a sound. Replace the peon.sh symlink
  # with a recorder; rm -f first so the redirect does not write through the
  # symlink into the real peon.sh.
  rm -f "$TEST_DIR/peon.sh"
  printf '#!/bin/bash\ncat > "%s/translated.json"\n' "$TEST_DIR" > "$TEST_DIR/peon.sh"
  chmod +x "$TEST_DIR/peon.sh"
  run_copilot preToolUse '{"sessionId":"test-123","cwd":"/tmp","toolName":"bash","toolArgs":{"cmd":"rm -rf /"}}'
  [ "$COPILOT_EXIT" -eq 0 ]
  python3 -c "
import json
d = json.load(open('$TEST_DIR/translated.json'))
assert d.get('hook_event_name') == 'PreToolUse', d
assert d.get('tool_name') == 'bash', d
assert d.get('tool_input', {}).get('cmd') == 'rm -rf /', d
"
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses Copilot sounds" {
  touch "$TEST_DIR/.paused"
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses Copilot sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "default_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_copilot sessionStart '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_copilot agentStop '{"sessionId":"test-123","cwd":"/tmp"}'
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Spam detection
# ============================================================

@test "rapid Copilot prompts trigger annoyed sound" {
  # First prompt is suppressed by peon.sh's startup grace window.
  run_copilot userPromptSubmitted '{"sessionId":"spam-test","cwd":"/tmp","prompt":"hi"}'
  # Wait past the suppression window before sending rapid prompts.
  sleep 3
  rm -f "$TEST_DIR/afplay.log"
  for i in $(seq 1 3); do
    run_copilot userPromptSubmitted '{"sessionId":"spam-test","cwd":"/tmp","prompt":"more"}'
  done
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"Angry1.wav" ]]
}

# ============================================================
# Debounce
# ============================================================

@test "second Stop within debounce window is suppressed" {
  run_copilot agentStop '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second agentStop within debounce window should be suppressed
  run_copilot agentStop '{"sessionId":"test-123","cwd":"/tmp"}'
  [ "$COPILOT_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Default argument
# ============================================================

@test "no argument defaults to sessionStart" {
  export PEON_TEST=1
  echo '{"sessionId":"test-123","cwd":"/tmp"}' | bash "$COPILOT_SH" 2>"$TEST_DIR/stderr.log"
  COPILOT_EXIT=$?
  sleep 0.3
  [ "$COPILOT_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}
