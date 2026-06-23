#!/usr/bin/env bats
# copyright (c) 2026 Atlassian US, Inc.

load setup.bash

setup() {
  setup_test_env

  # Derive repo root from PEON_SH (set by setup.bash using its own BASH_SOURCE)
  ROVODEV_SH="${PEON_SH%/peon.sh}/adapters/rovodev.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR — symlink it into the test dir
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

# Helper: run rovodev adapter with an event argument
run_rovodev() {
  local event="$1"
  export PEON_TEST=1
  bash "$ROVODEV_SH" "$event" 2>"$TEST_DIR/stderr.log"
  ROVODEV_EXIT=$?
  ROVODEV_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
}

run_rovodev_with_stdin() {
  local event="$1"
  local stdin_json="$2"
  export PEON_TEST=1
  printf '%s' "$stdin_json" | bash "$ROVODEV_SH" "$event" 2>"$TEST_DIR/stderr.log"
  ROVODEV_EXIT=$?
  ROVODEV_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
}

# ============================================================
# Event mapping
# ============================================================

@test "on_complete maps to Stop and plays completion sound" {
  run_rovodev "on_complete"
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

@test "on_error maps to PostToolUseFailure and plays error sound" {
  run_rovodev "on_error"
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Error"* ]]
}

@test "on_session_start maps to SessionStart and plays session.start sound" {
  run_rovodev "on_session_start"
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

@test "on_user_prompt maps to UserPromptSubmit and marks session working without sound" {
  run_rovodev "on_user_prompt"
  [ "$ROVODEV_EXIT" -eq 0 ]
  ! afplay_was_called
  grep -q ': working' "$TEST_DIR/.tab_title"
}

@test "on_tool_start maps to PreToolUse and marks session working without sound" {
  run_rovodev "on_tool_start"
  [ "$ROVODEV_EXIT" -eq 0 ]
  ! afplay_was_called
  grep -q ': working' "$TEST_DIR/.tab_title"
}

@test "on_tool_end maps to PostToolUse and marks session working without sound" {
  run_rovodev "on_tool_end"
  [ "$ROVODEV_EXIT" -eq 0 ]
  ! afplay_was_called
  grep -q ': working' "$TEST_DIR/.tab_title"
}

@test "on_session_end maps to SessionEnd and exits without sound" {
  run_rovodev "on_session_end"
  [ "$ROVODEV_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "on_tool_permission maps to PermissionRequest and plays input.required sound" {
  run_rovodev "on_tool_permission"
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "on_tool_permission without tool_input shows bash in permission notification" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": true,
  "notification_style": "standard",
  "notification_templates": {
    "permission": "{summary}"
  },
  "categories": {}
}
JSON
  payload=$(printf '{"session_id":"s1","cwd":"%s","hook_event_name":"on_tool_permission","attributes":{}}' "$TEST_DIR")
  run_rovodev_with_stdin "on_tool_permission" "$payload"
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  grep -q 'Permission requested (bash)' "$TEST_DIR/terminal_notifier.log"
}

@test "on_tool_permission notification prefers permission text over transcript text" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "desktop_notifications": true,
  "notification_style": "standard",
  "notification_templates": {
    "permission": "{summary}"
  },
  "categories": {}
}
JSON
  cat > "$TEST_DIR/transcript.json" <<'JSON'
{
  "message_history": [
    {
      "kind": "response",
      "parts": [
        {
          "part_kind": "text",
          "content": "This is the transcript response that should not appear"
        }
      ]
    }
  ]
}
JSON
  payload=$(printf '{"session_id":"s1","cwd":"%s","hook_event_name":"on_tool_permission","transcript_path":"%s/transcript.json","attributes":{"tool_input":{"tool_name":"create_file","args":{"_intent":"Create file for user"}}}}' "$TEST_DIR" "$TEST_DIR")
  run_rovodev_with_stdin "on_tool_permission" "$payload"
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  grep -q 'Permission requested (create_file) — Create file for user' "$TEST_DIR/terminal_notifier.log"
  ! grep -q 'transcript response' "$TEST_DIR/terminal_notifier.log"
}

@test "on_permission_request is accepted as alias for on_tool_permission" {
  run_rovodev "on_permission_request"
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Perm"* ]]
}

@test "default (no argument) maps to on_complete" {
  export PEON_TEST=1
  bash "$ROVODEV_SH" 2>"$TEST_DIR/stderr.log"
  ROVODEV_EXIT=$?
  [ "$ROVODEV_EXIT" -eq 0 ]
  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Done"* ]]
}

# ============================================================
# Skipped events
# ============================================================

@test "unknown event is skipped gracefully" {
  run_rovodev "some_unknown_event"
  [ "$ROVODEV_EXIT" -eq 0 ]
  ! afplay_was_called
}

# ============================================================
# Session ID prefixing
# ============================================================

@test "session_id is prefixed with rovodev-" {
  # Verify the adapter passes rovodev-prefixed session_id to peon.sh
  # by checking that debounce works across calls (same session = same debounce)
  run_rovodev "on_complete"
  [ "$ROVODEV_EXIT" -eq 0 ]
  count1=$(afplay_call_count)
  [ "$count1" = "1" ]

  # Second stop within debounce window should be suppressed
  run_rovodev "on_complete"
  [ "$ROVODEV_EXIT" -eq 0 ]
  count2=$(afplay_call_count)
  [ "$count2" = "1" ]
}

# ============================================================
# Config passthrough
# ============================================================

@test "paused state suppresses Rovo Dev sounds" {
  touch "$TEST_DIR/.paused"
  run_rovodev "on_complete"
  [ "$ROVODEV_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "enabled=false suppresses Rovo Dev sounds" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "enabled": false, "active_pack": "peon", "volume": 0.5, "categories": {} }
JSON
  run_rovodev "on_complete"
  [ "$ROVODEV_EXIT" -eq 0 ]
  ! afplay_was_called
}

@test "volume from config is passed through" {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.3, "enabled": true, "categories": {} }
JSON
  run_rovodev "on_complete"
  afplay_was_called
  log_line=$(tail -1 "$TEST_DIR/afplay.log")
  [[ "$log_line" == *"-v 0.3"* ]]
}

# ============================================================
# Installer auto-registration
# ============================================================

# Helper: set up a minimal install environment for install.sh tests
setup_install_env() {
  INSTALL_HOME="$(mktemp -d)"
  CLONE_DIR="$(mktemp -d)"
  INSTALL_MOCK_BIN="$(mktemp -d)"

  # Copy required installer files — derive repo root from PEON_SH (set by setup.bash)
  local src_dir
  src_dir="${PEON_SH%/peon.sh}"
  cp "$src_dir/install.sh" "$CLONE_DIR/"
  cp "$src_dir/peon.sh" "$CLONE_DIR/"
  cp "$src_dir/config.json" "$CLONE_DIR/"
  cp "$src_dir/VERSION" "$CLONE_DIR/"
  cp "$src_dir/completions.bash" "$CLONE_DIR/"
  cp "$src_dir/completions.fish" "$CLONE_DIR/"
  cp "$src_dir/relay.sh" "$CLONE_DIR/"
  cp "$src_dir/uninstall.sh" "$CLONE_DIR/" 2>/dev/null || touch "$CLONE_DIR/uninstall.sh"
  mkdir -p "$CLONE_DIR/scripts"
  cp "$src_dir/scripts/"*.sh "$CLONE_DIR/scripts/" 2>/dev/null || true
  mkdir -p "$CLONE_DIR/adapters"
  cp "$src_dir/adapters/"*.sh "$CLONE_DIR/adapters/" 2>/dev/null || true

  mkdir -p "$INSTALL_HOME/.claude"

  # Mock curl — return valid JSON for registry/manifest, dummy files for everything else
  local mock_registry='{"packs":[{"name":"peon","display_name":"Orc Peon","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"peon"},{"name":"peasant","display_name":"Human Peasant","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"peasant"},{"name":"sc_scv","display_name":"StarCraft SCV","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"sc_scv"},{"name":"sc_battlecruiser","display_name":"Battlecruiser","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"sc_battlecruiser"},{"name":"glados","display_name":"GLaDOS","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"glados"}]}'
  local mock_manifest='{"cesp_version":"1.0","name":"mock","display_name":"Mock Pack","categories":{"session.start":{"sounds":[{"file":"sounds/Hello1.wav","label":"Hello"}]},"task.complete":{"sounds":[{"file":"sounds/Done1.wav","label":"Done"}]}}}'

  cat > "$INSTALL_MOCK_BIN/curl" <<SCRIPT
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
  *index.json)
    if [ -n "\$output" ]; then echo '$mock_registry' > "\$output"
    else echo '$mock_registry'; fi ;;
  *openpeon.json)
    [ -n "\$output" ] && echo '$mock_manifest' > "\$output" ;;
  *sounds/*)
    [ -n "\$output" ] && printf 'RIFF' > "\$output" ;;
  *)
    [ -n "\$output" ] && echo "mock" > "\$output" ;;
esac
exit 0
SCRIPT
  chmod +x "$INSTALL_MOCK_BIN/curl"

  # Mock afplay
  cat > "$INSTALL_MOCK_BIN/afplay" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$INSTALL_MOCK_BIN/afplay"

  export HOME="$INSTALL_HOME"
  export PATH="$INSTALL_MOCK_BIN:$PATH"
}

teardown_install_env() {
  rm -rf "$INSTALL_HOME" "$CLONE_DIR" "$INSTALL_MOCK_BIN"
}

@test "install: registers hooks when config.yml exists with no eventHooks" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  echo "someOtherConfig: true" > "$INSTALL_HOME/.rovodev/config.yml"
  bash "$CLONE_DIR/install.sh"
  grep -q "eventHooks:" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "on_complete" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "on_error" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "on_tool_permission" "$INSTALL_HOME/.rovodev/config.yml"
  # Original config preserved
  grep -q "someOtherConfig: true" "$INSTALL_HOME/.rovodev/config.yml"
  teardown_install_env
}

@test "install: creates config.yml when only directory exists" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  bash "$CLONE_DIR/install.sh"
  [ -f "$INSTALL_HOME/.rovodev/config.yml" ]
  grep -q "eventHooks:" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "on_complete" "$INSTALL_HOME/.rovodev/config.yml"
  teardown_install_env
}

@test "install: backfills new hooks into old Rovo Dev config without duplicating old hooks" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  cat > "$INSTALL_HOME/.rovodev/config.yml" <<'EOF'
eventHooks:
  events:
    - name: on_complete
      commands:
        - command: bash /old/rovodev.sh on_complete
    - name: on_error
      commands:
        - command: bash /old/rovodev.sh on_error
    - name: on_tool_permission
      commands:
        - command: bash /old/rovodev.sh on_tool_permission
EOF
  bash "$CLONE_DIR/install.sh" > "$TEST_DIR/install.log"
  [ "$?" -eq 0 ]
  grep -q "Missing Rovo Dev CLI event hooks added to" "$TEST_DIR/install.log"
  for hook in on_user_prompt on_tool_start on_tool_end on_session_start on_session_end; do
    grep -q -- "- name: $hook" "$INSTALL_HOME/.rovodev/config.yml"
    grep -q "rovodev.sh $hook" "$INSTALL_HOME/.rovodev/config.yml"
  done
  [ "$(grep -c "rovodev.sh on_complete" "$INSTALL_HOME/.rovodev/config.yml")" -eq 1 ]
  [ "$(grep -c "rovodev.sh on_error" "$INSTALL_HOME/.rovodev/config.yml")" -eq 1 ]
  [ "$(grep -c "rovodev.sh on_tool_permission" "$INSTALL_HOME/.rovodev/config.yml")" -eq 1 ]
  teardown_install_env
}

@test "install: skips with message when all Rovo Dev hooks already exist" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  cat > "$INSTALL_HOME/.rovodev/config.yml" <<'EOF'
eventHooks:
  events:
    - name: on_complete
      commands:
        - command: bash /old/rovodev.sh on_complete
    - name: on_error
      commands:
        - command: bash /old/rovodev.sh on_error
    - name: on_tool_permission
      commands:
        - command: bash /old/rovodev.sh on_tool_permission
    - name: on_user_prompt
      commands:
        - command: bash /old/rovodev.sh on_user_prompt
    - name: on_tool_start
      commands:
        - command: bash /old/rovodev.sh on_tool_start
    - name: on_tool_end
      commands:
        - command: bash /old/rovodev.sh on_tool_end
    - name: on_session_start
      commands:
        - command: bash /old/rovodev.sh on_session_start
    - name: on_session_end
      commands:
        - command: bash /old/rovodev.sh on_session_end
EOF
  bash "$CLONE_DIR/install.sh" > "$TEST_DIR/install.log"
  [ "$?" -eq 0 ]
  grep -q "peon-ping hooks already present in Rovo Dev CLI config — skipping" "$TEST_DIR/install.log"
  [ "$(grep -c "rovodev.sh" "$INSTALL_HOME/.rovodev/config.yml")" -eq 8 ]
  teardown_install_env
}

@test "install: handles empty events array (events: [])" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  cat > "$INSTALL_HOME/.rovodev/config.yml" <<'EOF'
eventHooks:
  logFile: /Users/testuser/.rovodev/event_hooks.log
  events: []
EOF
  bash "$CLONE_DIR/install.sh"
  # events: [] should be replaced with actual events
  ! grep -q 'events: \[\]' "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh on_complete" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh on_error" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh on_tool_permission" "$INSTALL_HOME/.rovodev/config.yml"
  # logFile preserved
  grep -q "logFile:" "$INSTALL_HOME/.rovodev/config.yml"
  teardown_install_env
}

@test "install: appends command to existing event, creates missing events" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  cat > "$INSTALL_HOME/.rovodev/config.yml" <<'EOF'
eventHooks:
  events:
    - name: on_complete
      commands:
        - command: echo "my custom hook"
EOF
  bash "$CLONE_DIR/install.sh"
  # Original hook preserved
  grep -q 'echo "my custom hook"' "$INSTALL_HOME/.rovodev/config.yml"
  # rovodev.sh command added under existing on_complete (not a duplicate event)
  grep -q "rovodev.sh on_complete" "$INSTALL_HOME/.rovodev/config.yml"
  # Only one '- name: on_complete' entry (command appended, not new event)
  count=$(grep -c "\- name: on_complete" "$INSTALL_HOME/.rovodev/config.yml")
  [ "$count" -eq 1 ]
  # Missing events created as new entries
  grep -q "rovodev.sh on_error" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh on_tool_permission" "$INSTALL_HOME/.rovodev/config.yml"
  teardown_install_env
}

@test "install: appends with matching indentation (2-space)" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  cat > "$INSTALL_HOME/.rovodev/config.yml" <<'EOF'
eventHooks:
  events:
  - name: on_complete
    commands:
    - command: echo "my custom hook"
EOF
  bash "$CLONE_DIR/install.sh"
  # Original hook preserved
  grep -q 'echo "my custom hook"' "$INSTALL_HOME/.rovodev/config.yml"
  # rovodev.sh command added under existing on_complete with matching indent
  grep -q "rovodev.sh on_complete" "$INSTALL_HOME/.rovodev/config.yml"
  # Only one on_complete event (command appended, not duplicated)
  count=$(grep -c "\- name: on_complete" "$INSTALL_HOME/.rovodev/config.yml")
  [ "$count" -eq 1 ]
  # Missing events created with 2-space indentation
  grep -q "^  - name: on_error" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "^  - name: on_tool_permission" "$INSTALL_HOME/.rovodev/config.yml"
  teardown_install_env
}

@test "install: appends commands to all three existing events without duplicates" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  cat > "$INSTALL_HOME/.rovodev/config.yml" <<'EOF'
eventHooks:
  events:
  - name: on_complete
    commands:
    - command: echo "existing complete"
  - name: on_error
    commands:
    - command: echo "existing error"
  - name: on_tool_permission
    commands:
    - command: echo "existing permission"
EOF
  bash "$CLONE_DIR/install.sh"
  # All original hooks preserved
  grep -q 'echo "existing complete"' "$INSTALL_HOME/.rovodev/config.yml"
  grep -q 'echo "existing error"' "$INSTALL_HOME/.rovodev/config.yml"
  grep -q 'echo "existing permission"' "$INSTALL_HOME/.rovodev/config.yml"
  # rovodev.sh commands added
  grep -q "rovodev.sh on_complete" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh on_error" "$INSTALL_HOME/.rovodev/config.yml"
  grep -q "rovodev.sh on_tool_permission" "$INSTALL_HOME/.rovodev/config.yml"
  # No duplicate events — each event name appears exactly once
  [ "$(grep -c '\- name: on_complete' "$INSTALL_HOME/.rovodev/config.yml")" -eq 1 ]
  [ "$(grep -c '\- name: on_error' "$INSTALL_HOME/.rovodev/config.yml")" -eq 1 ]
  [ "$(grep -c '\- name: on_tool_permission' "$INSTALL_HOME/.rovodev/config.yml")" -eq 1 ]
  teardown_install_env
}

@test "install: preserves multi-line command values when appending hooks" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  cat > "$INSTALL_HOME/.rovodev/config.yml" <<'EOF'
eventHooks:
  logFile: /Users/testuser/.rovodev/event_hooks.log
  events:
  - name: on_tool_permission
    commands:
    - command: osascript -e 'display notification "Rovo Dev CLI needs permission to
        use tools to continue." with title "Rovo Dev CLI"'
  - name: on_complete
    commands:
    - command: osascript -e 'display notification "on_complete" with title "Rovo Dev
        CLI"'
  - name: on_error
    commands:
    - command: osascript -e 'display notification "on_error" with title "Rovo Dev
        CLI"'
EOF
  bash "$CLONE_DIR/install.sh"
  local cfg="$INSTALL_HOME/.rovodev/config.yml"
  # Multi-line osascript commands must remain intact (continuation lines not split)
  grep -q 'use tools to continue." with title "Rovo Dev CLI"' "$cfg"
  # The peon-ping command must appear AFTER the continuation line, not before it
  local perm_cmd_line
  perm_cmd_line=$(grep -n 'rovodev.sh on_tool_permission' "$cfg" | head -1 | cut -d: -f1)
  local continuation_line
  continuation_line=$(grep -n 'use tools to continue' "$cfg" | head -1 | cut -d: -f1)
  [ "$perm_cmd_line" -gt "$continuation_line" ]
  # rovodev.sh commands added for all events
  grep -q "rovodev.sh on_complete" "$cfg"
  grep -q "rovodev.sh on_error" "$cfg"
  grep -q "rovodev.sh on_tool_permission" "$cfg"
  # No duplicate events
  [ "$(grep -c '\- name: on_complete' "$cfg")" -eq 1 ]
  [ "$(grep -c '\- name: on_error' "$cfg")" -eq 1 ]
  [ "$(grep -c '\- name: on_tool_permission' "$cfg")" -eq 1 ]
  teardown_install_env
}

@test "install: detects config.yaml extension" {
  setup_install_env
  mkdir -p "$INSTALL_HOME/.rovodev"
  echo "someConfig: true" > "$INSTALL_HOME/.rovodev/config.yaml"
  bash "$CLONE_DIR/install.sh"
  grep -q "eventHooks:" "$INSTALL_HOME/.rovodev/config.yaml"
  grep -q "rovodev.sh" "$INSTALL_HOME/.rovodev/config.yaml"
  # config.yml should not be created
  [ ! -f "$INSTALL_HOME/.rovodev/config.yml" ]
  teardown_install_env
}

@test "install: does nothing when no .rovodev directory" {
  setup_install_env
  rm -rf "$INSTALL_HOME/.rovodev"
  bash "$CLONE_DIR/install.sh"
  [ ! -d "$INSTALL_HOME/.rovodev" ]
  teardown_install_env
}
