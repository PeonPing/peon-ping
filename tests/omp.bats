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
