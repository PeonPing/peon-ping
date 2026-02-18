#!/usr/bin/env bats
# Tests for relay.sh — the peon-ping audio relay server

load setup

# Use the real curl, not the mock from setup.bash
REAL_CURL="$(command -v curl 2>/dev/null || echo /usr/bin/curl)"

setup() {
  setup_test_env

  # Derive relay.sh path from PEON_SH (set in setup.bash from its own location)
  RELAY_SH="$(dirname "$PEON_SH")/relay.sh"
  RELAY_PORT=19876  # Use non-default port to avoid conflicts
  RELAY_PID=""
}

teardown() {
  # Kill relay if running
  if [ -n "$RELAY_PID" ] && kill -0 "$RELAY_PID" 2>/dev/null; then
    kill "$RELAY_PID" 2>/dev/null
    wait "$RELAY_PID" 2>/dev/null || true
  fi
  # Also stop via pidfile in case daemon tests left one
  if [ -f "$TEST_DIR/.relay.pid" ]; then
    pid=$(cat "$TEST_DIR/.relay.pid" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
      wait "$pid" 2>/dev/null || true
    fi
    rm -f "$TEST_DIR/.relay.pid"
  fi
  teardown_test_env
}

# Helper: start relay and wait for it to be ready
start_relay() {
  bash "$RELAY_SH" --port="$RELAY_PORT" --peon-dir="$TEST_DIR" > /dev/null 2>&1 &
  RELAY_PID=$!

  # Wait for relay to start (up to 3 seconds)
  for i in $(seq 1 30); do
    if "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/health" > /dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  echo "Relay failed to start" >&2
  return 1
}

# ── Help and CLI ──────────────────────────────────────────────────────────────

@test "relay --help shows usage" {
  run bash "$RELAY_SH" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--port"* ]]
  [[ "$output" == *"--daemon"* ]]
}

@test "relay exits with error if packs dir missing" {
  rm -rf "$TEST_DIR/packs"
  run bash "$RELAY_SH" --port="$RELAY_PORT" --peon-dir="$TEST_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"packs not found"* ]]
}

# ── Health endpoint ───────────────────────────────────────────────────────────

@test "relay /health returns 200 OK" {
  start_relay
  run "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/health"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

# ── Play endpoint ─────────────────────────────────────────────────────────────

@test "relay /play plays a valid sound file" {
  start_relay
  run "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/play?file=packs/peon/sounds/Hello1.wav" \
    -H "X-Volume: 0.7"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "relay /play returns 400 without file parameter" {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$RELAY_PORT/play"
  [ "$output" = "400" ]
}

@test "relay /play returns 404 for nonexistent file" {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" \
    "http://127.0.0.1:$RELAY_PORT/play?file=packs/peon/sounds/nonexistent.wav"
  [ "$output" = "404" ]
}

# ── Path traversal protection ─────────────────────────────────────────────────

@test "relay blocks path traversal with .." {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" \
    "http://127.0.0.1:$RELAY_PORT/play?file=../../../etc/passwd"
  [ "$output" = "403" ]
}

@test "relay blocks path traversal with encoded .." {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" \
    "http://127.0.0.1:$RELAY_PORT/play?file=..%2F..%2F..%2Fetc%2Fpasswd"
  [ "$output" = "403" ]
}

@test "relay blocks absolute paths" {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" \
    "http://127.0.0.1:$RELAY_PORT/play?file=/etc/passwd"
  [ "$output" = "403" ]
}

# ── Notify endpoint ───────────────────────────────────────────────────────────

@test "relay /notify accepts POST with JSON body" {
  start_relay
  run "$REAL_CURL" -sf -X POST "http://127.0.0.1:$RELAY_PORT/notify" \
    -H "Content-Type: application/json" \
    -d '{"title":"peon-ping","message":"Test notification"}'
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "relay /notify accepts empty POST body" {
  start_relay
  run "$REAL_CURL" -sf -X POST "http://127.0.0.1:$RELAY_PORT/notify" \
    -H "Content-Length: 0"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "relay /notify returns 400 for invalid JSON" {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" -X POST \
    "http://127.0.0.1:$RELAY_PORT/notify" \
    -H "Content-Type: application/json" \
    -d 'not json at all'
  [ "$output" = "400" ]
}

# ── Unknown routes ────────────────────────────────────────────────────────────

@test "relay returns 404 for unknown GET route" {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$RELAY_PORT/unknown"
  [ "$output" = "404" ]
}

@test "relay returns 404 for POST to /play" {
  start_relay
  run "$REAL_CURL" -s -o /dev/null -w "%{http_code}" -X POST "http://127.0.0.1:$RELAY_PORT/play"
  # POST to /play has no handler — BaseHTTPRequestHandler returns 501
  [[ "$output" =~ ^(404|405|501)$ ]]
}

# ── Daemon mode ───────────────────────────────────────────────────────────────

@test "relay --status reports not running when no pidfile" {
  run bash "$RELAY_SH" --status --peon-dir="$TEST_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not running"* ]]
}

@test "relay --stop reports not running when no pidfile" {
  run bash "$RELAY_SH" --stop --peon-dir="$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"not running"* ]]
}

@test "relay --daemon starts and --stop stops" {
  run bash "$RELAY_SH" --daemon --port="$RELAY_PORT" --peon-dir="$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"started in background"* ]]

  # Verify pidfile was created
  [ -f "$TEST_DIR/.relay.pid" ]
  RELAY_PID=$(cat "$TEST_DIR/.relay.pid")

  # Wait for it to be ready
  for i in $(seq 1 30); do
    if "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/health" > /dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  # --status should report running
  run bash "$RELAY_SH" --status --peon-dir="$TEST_DIR" --port="$RELAY_PORT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"running"* ]]

  # --stop should stop it
  run bash "$RELAY_SH" --stop --peon-dir="$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopped"* ]]

  # pidfile should be removed
  [ ! -f "$TEST_DIR/.relay.pid" ]
  RELAY_PID=""
}

@test "relay --daemon prevents duplicate start" {
  # Start first instance
  bash "$RELAY_SH" --daemon --port="$RELAY_PORT" --peon-dir="$TEST_DIR" > /dev/null 2>&1
  RELAY_PID=$(cat "$TEST_DIR/.relay.pid" 2>/dev/null)

  # Wait for it to be ready
  for i in $(seq 1 30); do
    if "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/health" > /dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done

  # Try starting again — should say already running
  run bash "$RELAY_SH" --daemon --port="$RELAY_PORT" --peon-dir="$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already running"* ]]
}

# ── Volume handling ───────────────────────────────────────────────────────────

@test "relay clamps volume to valid range" {
  start_relay
  # Volume > 1.0 should be clamped (no error)
  run "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/play?file=packs/peon/sounds/Hello1.wav" \
    -H "X-Volume: 5.0"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]

  # Volume < 0 should be clamped (no error)
  run "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/play?file=packs/peon/sounds/Hello1.wav" \
    -H "X-Volume: -1.0"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

@test "relay handles invalid volume gracefully" {
  start_relay
  run "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/play?file=packs/peon/sounds/Hello1.wav" \
    -H "X-Volume: notanumber"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
}

# ── Sound Effects device config ──────────────────────────────────────────────

@test "relay uses peon-play when use_sound_effects_device is true" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": true, "categories": {} }
JSON
  start_relay
  run "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/play?file=packs/peon/sounds/Hello1.wav" \
    -H "X-Volume: 0.5"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
  # peon-play should have been called (logs to peon-play.log)
  sleep 0.2
  [ -f "$TEST_DIR/peon-play.log" ]
}

@test "relay uses afplay when use_sound_effects_device is false" {
  install_peon_play_mock
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "active_pack": "peon", "volume": 0.5, "enabled": true, "use_sound_effects_device": false, "categories": {} }
JSON
  start_relay
  run "$REAL_CURL" -sf "http://127.0.0.1:$RELAY_PORT/play?file=packs/peon/sounds/Hello1.wav" \
    -H "X-Volume: 0.5"
  [ "$status" -eq 0 ]
  [ "$output" = "OK" ]
  # afplay should have been called, not peon-play
  sleep 0.2
  [ -f "$TEST_DIR/afplay.log" ]
  [ ! -f "$TEST_DIR/peon-play.log" ]
}
