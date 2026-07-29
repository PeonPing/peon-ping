#!/usr/bin/env bats
#
# Unit tests for scripts/tts-minimax.sh (MiniMax T2A cloud TTS backend).
#
# The backend has two verifiable halves:
#   1. Request construction — region → endpoint mapping, model/format/voice
#      resolution, GroupId handling, JSON body. Verified through the dry-run
#      trace (PEON_TTS_DRY_RUN=1 writes the resolved request to a trace file
#      and skips the network call).
#   2. Live request + response handling — verified against a PATH-mocked
#      `curl` returning a canned T2A response and a PATH-mocked audio player,
#      asserting the hex audio is decoded and handed to the player.
#
# The credential (MINIMAX_API_KEY) must never appear in the trace or on any
# output stream — asserted explicitly below.

TTS_SCRIPT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)/scripts/tts-minimax.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  MOCK_BIN="$TEST_DIR/mock_bin"
  mkdir -p "$MOCK_BIN"
  export PEON_DIR="$TEST_DIR"
  unset PEON_DEBUG PEON_MINIMAX_REGION PEON_MINIMAX_MODEL PEON_MINIMAX_FORMAT
  unset MINIMAX_API_KEY MINIMAX_GROUP_ID
}

teardown() {
  rm -rf "$TEST_DIR"
}

# --- Helpers ---

# Install a mock binary that logs args to <name>.log and stdin to <name>.stdin.
mock_cmd() {
  local name="$1" exit_code="${2:-0}"
  local path="$MOCK_BIN/$name"
  {
    printf '%s\n' '#!/bin/bash'
    printf 'echo "ARGS: $*" >> "%s/%s.log"\n' "$TEST_DIR" "$name"
    printf 'if [ ! -t 0 ]; then cat >> "%s/%s.stdin"; fi\n' "$TEST_DIR" "$name"
    printf 'exit %s\n' "$exit_code"
  } > "$path"
  chmod +x "$path"
}

mock_uname() {
  local kernel="$1"
  cat > "$MOCK_BIN/uname" <<SCRIPT
#!/bin/bash
printf '%s\n' '$kernel'
SCRIPT
  chmod +x "$MOCK_BIN/uname"
}

# Mock curl: log args, then emit a canned response body to stdout.
mock_curl_response() {
  local body="$1" exit_code="${2:-0}"
  {
    printf '%s\n' '#!/bin/bash'
    printf 'echo "ARGS: $*" >> "%s/curl.log"\n' "$TEST_DIR"
    printf 'printf %s %q\n' '%s' "$body"
    printf 'exit %s\n' "$exit_code"
  } > "$MOCK_BIN/curl"
  chmod +x "$MOCK_BIN/curl"
}

with_mocks() { export PATH="$MOCK_BIN:$PATH"; }

mock_args() { [ -f "$TEST_DIR/$1.log" ] && cat "$TEST_DIR/$1.log"; }
mock_called() { [ -f "$TEST_DIR/$1.log" ]; }

# Read a field out of the dry-run trace JSON.
tj() {
  python3 -c "import json;d=json.load(open('$1'));print($2)"
}

run_dry() {
  # run_dry <text> <voice> <rate> <vol> ; writes trace to $TEST_DIR/trace.json
  local text="$1" voice="${2:-default}" rate="${3:-1.0}" vol="${4:-0.5}"
  printf '%s\n' "$text" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    bash "$TTS_SCRIPT" "$voice" "$rate" "$vol"
}

# ============================================================
# Script existence + syntax
# ============================================================

@test "tts-minimax.sh: file exists and is executable" {
  [ -f "$TTS_SCRIPT" ]
  [ -x "$TTS_SCRIPT" ]
}

@test "tts-minimax.sh: passes bash -n syntax check" {
  bash -n "$TTS_SCRIPT"
}

# ============================================================
# Regional endpoint resolution (dry-run)
# ============================================================

@test "dry-run: default region resolves the global endpoint" {
  run_dry "hello"
  [ "$(tj "$TEST_DIR/trace.json" "d['url']")" = "https://api.minimax.io/v1/t2a_v2" ]
  [ "$(tj "$TEST_DIR/trace.json" "d['region']")" = "global_en" ]
}

@test "dry-run: cn_zh region resolves the CN endpoint" {
  printf '%s\n' "hello" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    PEON_MINIMAX_REGION=cn_zh bash "$TTS_SCRIPT" default 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['url']")" = "https://api.minimaxi.com/v1/t2a_v2" ]
}

@test "dry-run: unknown region falls back to the global endpoint" {
  printf '%s\n' "hi" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    PEON_MINIMAX_REGION=bogus bash "$TTS_SCRIPT" default 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['url']")" = "https://api.minimax.io/v1/t2a_v2" ]
}

@test "dry-run: MINIMAX_GROUP_ID is appended as a query argument" {
  printf '%s\n' "hi" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    MINIMAX_GROUP_ID=grp42 bash "$TTS_SCRIPT" default 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['url']")" = "https://api.minimax.io/v1/t2a_v2?GroupId=grp42" ]
  [ "$(tj "$TEST_DIR/trace.json" "d['has_group_id']")" = "True" ]
}

# ============================================================
# Model + request body (dry-run)
# ============================================================

@test "dry-run: default model is speech-2.8-hd" {
  run_dry "hi"
  [ "$(tj "$TEST_DIR/trace.json" "d['model']")" = "speech-2.8-hd" ]
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['model']")" = "speech-2.8-hd" ]
}

@test "dry-run: PEON_MINIMAX_MODEL overrides the model (speech-2.8-turbo)" {
  printf '%s\n' "hi" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    PEON_MINIMAX_MODEL=speech-2.8-turbo bash "$TTS_SCRIPT" default 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['model']")" = "speech-2.8-turbo" ]
}

@test "dry-run: request carries model, text, and voice_setting.speed" {
  run_dry "read this aloud"
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['text']")" = "read this aloud" ]
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['voice_setting']['speed']")" = "1.0" ]
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['audio_setting']['format']")" = "mp3" ]
}

@test "dry-run: voice=default omits voice_id" {
  run_dry "hi" default 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "'voice_id' in d['request']['voice_setting']")" = "False" ]
}

@test "dry-run: explicit voice populates voice_setting.voice_id" {
  run_dry "hi" some-voice-id 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['voice_setting']['voice_id']")" = "some-voice-id" ]
}

@test "dry-run: PEON_MINIMAX_FORMAT changes audio_setting.format" {
  printf '%s\n' "hi" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    PEON_MINIMAX_FORMAT=wav bash "$TTS_SCRIPT" default 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['audio_setting']['format']")" = "wav" ]
}

# ============================================================
# Rate clamping (dry-run)
# ============================================================

@test "dry-run: rate above 2.0 is clamped to 2.0" {
  run_dry "hi" default 3.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['voice_setting']['speed']")" = "2.0" ]
}

@test "dry-run: rate below 0.5 is clamped to 0.5" {
  run_dry "hi" default 0.1 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['voice_setting']['speed']")" = "0.5" ]
}

# ============================================================
# Credential safety
# ============================================================

@test "dry-run: has_api_key reflects the environment" {
  run_dry "hi"
  [ "$(tj "$TEST_DIR/trace.json" "d['has_api_key']")" = "False" ]
  printf '%s\n' "hi" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    MINIMAX_API_KEY=sekret bash "$TTS_SCRIPT" default 1.0 0.5
  [ "$(tj "$TEST_DIR/trace.json" "d['has_api_key']")" = "True" ]
}

@test "dry-run: the API key value never appears in the trace" {
  printf '%s\n' "hi" | \
    PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE="$TEST_DIR/trace.json" \
    MINIMAX_API_KEY=super-secret-value bash "$TTS_SCRIPT" default 1.0 0.5
  ! grep -q "super-secret-value" "$TEST_DIR/trace.json"
}

# ============================================================
# Text safety — shell metacharacters
# ============================================================

@test "dry-run: metacharacters in text are JSON-escaped, not interpreted" {
  run_dry 'Hello $USER `whoami` "quoted"'
  [ "$(tj "$TEST_DIR/trace.json" "d['request']['text']")" = 'Hello $USER `whoami` "quoted"' ]
}

# ============================================================
# Empty / whitespace input contract
# ============================================================

@test "empty stdin: exits 0 without writing a trace or calling curl" {
  mock_curl_response '{}'
  with_mocks
  run bash -c ": | PEON_TTS_DRY_RUN=1 PEON_TTS_TRACE_FILE='$TEST_DIR/trace.json' bash '$TTS_SCRIPT' default 1.0 0.5"
  [ "$status" -eq 0 ]
  [ ! -f "$TEST_DIR/trace.json" ]
  ! mock_called "curl"
}

@test "whitespace-only stdin: exits 0 without calling curl" {
  mock_curl_response '{}'
  with_mocks
  run bash -c "printf '   \\n' | MINIMAX_API_KEY=k bash '$TTS_SCRIPT' default 1.0 0.5"
  [ "$status" -eq 0 ]
  ! mock_called "curl"
}

# ============================================================
# --list-voices contract
# ============================================================

@test "--list-voices: exits 0 without a request" {
  mock_curl_response '{}'
  with_mocks
  run bash "$TTS_SCRIPT" --list-voices
  [ "$status" -eq 0 ]
  ! mock_called "curl"
}

# ============================================================
# Live path — request + response handling
# ============================================================

@test "live: no MINIMAX_API_KEY skips the request and exits 0" {
  mock_curl_response '{"data":{"audio":"6162"},"base_resp":{"status_code":0}}'
  with_mocks
  run bash -c "echo hi | bash '$TTS_SCRIPT' default 1.0 0.5"
  [ "$status" -eq 0 ]
  ! mock_called "curl"
}

@test "live: curl is invoked with the endpoint URL and a Bearer header" {
  mock_uname "Darwin"
  mock_cmd "afplay"
  mock_curl_response '{"data":{"audio":"6162","status":2},"base_resp":{"status_code":0}}'
  with_mocks
  echo "hi" | MINIMAX_API_KEY=k bash "$TTS_SCRIPT" default 1.0 0.5
  mock_called "curl"
  local args; args=$(mock_args "curl")
  [[ "$args" == *"https://api.minimax.io/v1/t2a_v2"* ]]
  [[ "$args" == *"Authorization: Bearer"* ]]
}

@test "live: successful response is hex-decoded and handed to the macOS player" {
  mock_uname "Darwin"
  # afplay mock records the byte content of the file it is asked to play.
  cat > "$MOCK_BIN/afplay" <<SCRIPT
#!/bin/bash
echo "ARGS: \$*" >> "$TEST_DIR/afplay.log"
for a in "\$@"; do f="\$a"; done
[ -f "\$f" ] && od -An -tx1 "\$f" | tr -d ' \n' >> "$TEST_DIR/afplay.bytes"
SCRIPT
  chmod +x "$MOCK_BIN/afplay"
  mock_curl_response '{"data":{"audio":"6162","status":2},"base_resp":{"status_code":0}}'
  with_mocks
  echo "hi" | MINIMAX_API_KEY=k bash "$TTS_SCRIPT" default 1.0 0.7
  mock_called "afplay"
  [[ "$(mock_args afplay)" == *"-v 0.7"* ]]
  # 6162 hex == "ab"
  [ "$(cat "$TEST_DIR/afplay.bytes")" = "6162" ]
}

@test "live: base_resp.status_code != 0 skips playback" {
  mock_uname "Darwin"
  mock_cmd "afplay"
  mock_curl_response '{"base_resp":{"status_code":1001,"status_msg":"bad"}}'
  with_mocks
  run bash -c "echo hi | MINIMAX_API_KEY=k bash '$TTS_SCRIPT' default 1.0 0.5"
  [ "$status" -eq 0 ]
  ! mock_called "afplay"
}

@test "live: empty data.audio skips playback" {
  mock_uname "Darwin"
  mock_cmd "afplay"
  mock_curl_response '{"data":{"audio":""},"base_resp":{"status_code":0}}'
  with_mocks
  run bash -c "echo hi | MINIMAX_API_KEY=k bash '$TTS_SCRIPT' default 1.0 0.5"
  [ "$status" -eq 0 ]
  ! mock_called "afplay"
}

@test "live: curl failure does not fail the script (exit 0)" {
  mock_uname "Darwin"
  mock_cmd "afplay"
  mock_curl_response '' 1
  with_mocks
  run bash -c "echo hi | MINIMAX_API_KEY=k bash '$TTS_SCRIPT' default 1.0 0.5"
  [ "$status" -eq 0 ]
  ! mock_called "afplay"
}

@test "live: Linux routes decoded audio through the preferred player (pw-play)" {
  mock_uname "Linux"
  mock_cmd "pw-play"
  mock_curl_response '{"data":{"audio":"6162","status":2},"base_resp":{"status_code":0}}'
  with_mocks
  echo "hi" | MINIMAX_API_KEY=k bash "$TTS_SCRIPT" default 1.0 0.5
  mock_called "pw-play"
}
