#!/usr/bin/env bats
#
# Tests for the WSL audio backend selector (PEON_WSL_AUDIO_BACKEND).
#
# Strategy: mock powershell.exe to log every invocation to a file, mock
# wslpath, set PEON_PLATFORM=wsl, drive a hook event through run_peon,
# then grep the powershell.exe log for "MediaPlayer" vs "SoundPlayer" to
# verify which playback path was taken.

load setup.bash

setup() {
  setup_test_env
  export PEON_PLATFORM=wsl

  # Mock powershell.exe — logs every invocation, responds to GetTempPath
  cat > "$MOCK_BIN/powershell.exe" <<SCRIPT
#!/bin/bash
echo "POWERSHELL_CALL: \$*" >> "${TEST_DIR}/powershell.log"
if [[ "\$*" == *"GetTempPath"* ]]; then
  echo "C:\\\\Users\\\\test\\\\AppData\\\\Local\\\\Temp\\\\"
  exit 0
fi
if [[ "\$*" == *"OSVersion.Version.Build"* ]]; then
  echo "26200"
  exit 0
fi
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/powershell.exe"

  # Mock wslpath — converts both directions to test paths
  cat > "$MOCK_BIN/wslpath" <<SCRIPT
#!/bin/bash
if [[ "\$1" == "-u" ]]; then
  echo "${TEST_DIR}/wsl_tmp/peon-ping-sound.wav"
elif [[ "\$1" == "-w" ]]; then
  echo "C:\\\\fake\\\\path.wav"
fi
SCRIPT
  chmod +x "$MOCK_BIN/wslpath"

  # Mock setsid — run inline (no session separation in tests)
  cat > "$MOCK_BIN/setsid" <<'SCRIPT'
#!/bin/bash
"$@"
SCRIPT
  chmod +x "$MOCK_BIN/setsid"

  # Mock ffmpeg — _wsl_play_soundplayer pipes test fixture WAVs through
  # ffmpeg for volume baking, but the fixture WAVs are empty placeholders
  # so a real ffmpeg invocation would fail and the function would return
  # before reaching the PowerShell SoundPlayer call. Replace with a
  # passthrough that just copies the input to the output path.
  cat > "$MOCK_BIN/ffmpeg" <<'SCRIPT'
#!/bin/bash
input=""
output=""
while [ $# -gt 0 ]; do
  case "$1" in
    -i) input="$2"; shift 2 ;;
    -*) shift ;;
    *) output="$1"; shift ;;
  esac
done
[ -n "$input" ] && [ -n "$output" ] && cp "$input" "$output"
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/ffmpeg"

  mkdir -p "$TEST_DIR/wsl_tmp"
}

teardown() {
  teardown_test_env
}

# Helper: grep the powershell command log for a substring
ps_log_contains() {
  grep -q "$1" "$TEST_DIR/powershell.log" 2>/dev/null
}

# Default config used by all tests
write_default_config() {
  cat > "$TEST_DIR/config.json" <<'JSON'
{ "default_pack": "peon", "volume": 0.5, "enabled": true, "notification_style": "silent", "categories": { "session.start": true, "task.complete": true, "task.error": true, "input.required": true, "resource.limit": true, "user.spam": true }, "annoyed_threshold": 3, "annoyed_window_seconds": 10 }
JSON
}

# ============================================================
# Backend env var routing
# ============================================================

@test "PEON_WSL_AUDIO_BACKEND=mediaplayer routes to WPF MediaPlayer (no probe, no copy)" {
  write_default_config
  export PEON_WSL_AUDIO_BACKEND=mediaplayer
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  ps_log_contains "MediaPlayer"
  ! ps_log_contains "SoundPlayer"
  # No probe cache should be written when backend is forced
  [ ! -f "$TEST_DIR/.wsl-mediaplayer-probe-26200" ]
}

@test "PEON_WSL_AUDIO_BACKEND=soundplayer routes to System.Media.SoundPlayer" {
  write_default_config
  export PEON_WSL_AUDIO_BACKEND=soundplayer
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  ps_log_contains "SoundPlayer"
  ! ps_log_contains "MediaPlayer"
}

@test "PEON_WSL_AUDIO_BACKEND=auto with cached probe=yes uses MediaPlayer" {
  write_default_config
  # Pre-seed the probe cache so no probe runs
  echo yes > "$TEST_DIR/.wsl-mediaplayer-probe-26200"
  export PEON_WSL_AUDIO_BACKEND=auto
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  ps_log_contains "MediaPlayer"
  ! ps_log_contains "SoundPlayer"
}

@test "PEON_WSL_AUDIO_BACKEND=auto with cached probe=no uses SoundPlayer" {
  write_default_config
  echo no > "$TEST_DIR/.wsl-mediaplayer-probe-26200"
  export PEON_WSL_AUDIO_BACKEND=auto
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  ps_log_contains "SoundPlayer"
  ! ps_log_contains "MediaPlayer"
}

@test "PEON_WSL_AUDIO_BACKEND default (unset) is auto" {
  write_default_config
  echo no > "$TEST_DIR/.wsl-mediaplayer-probe-26200"
  unset PEON_WSL_AUDIO_BACKEND
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  ps_log_contains "SoundPlayer"
}

@test "PEON_WSL_AUDIO_BACKEND with invalid value falls back to auto" {
  write_default_config
  echo yes > "$TEST_DIR/.wsl-mediaplayer-probe-26200"
  export PEON_WSL_AUDIO_BACKEND=garbage
  run_peon '{"hook_event_name":"SessionStart","cwd":"/tmp/p","session_id":"s1"}'
  [ "$PEON_EXIT" -eq 0 ]
  ps_log_contains "MediaPlayer"
}
