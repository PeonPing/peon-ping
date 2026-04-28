# Common test setup for peon-ping bats tests

# Resolve python3 via PATH (not the Linux-only /usr/bin/python3) so the
# harness works on macOS, Linux, and Git Bash for Windows without
# hardcoded absolute paths. See card w3ciyq.
if [ -z "${PEON_PY:-}" ]; then
  if PEON_PY="$(command -v python3 2>/dev/null)" && [ -n "$PEON_PY" ]; then
    export PEON_PY
  elif PEON_PY="$(command -v python 2>/dev/null)" && [ -n "$PEON_PY" ]; then
    export PEON_PY
  else
    printf 'setup.bash: python3 not found on PATH; install Python 3 to run these tests\n' >&2
    return 1 2>/dev/null || exit 1
  fi
fi

# Create isolated test environment so we never touch real config
setup_test_env() {
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR
  export CLAUDE_PEON_DIR="$TEST_DIR"
  export PEON_TEST=1

  # Prevent the user's live cmux session from leaking into tests that expect
  # normal desktop notification paths unless they opt into cmux explicitly.
  unset CMUX_SOCKET_PATH CMUX_SOCKET CMUX_WORKSPACE_ID CMUX_SURFACE_ID CMUX_PANEL_ID
  unset CMUX_BUNDLED_CLI_PATH CMUX_BUNDLE_ID
  unset TERM_PROGRAM GHOSTTY_RESOURCES_DIR ITERM_SESSION_ID WARP_IS_LOCAL_SHELL_SESSION
  unset __CFBundleIdentifier CLAUDE_SESSION_NAME

  # Create directory structure
  mkdir -p "$TEST_DIR/packs/peon/sounds"
  mkdir -p "$TEST_DIR/packs/sc_kerrigan/sounds"

  # Create minimal manifest (CESP category names)
  cat > "$TEST_DIR/packs/peon/manifest.json" <<'JSON'
{
  "name": "peon",
  "display_name": "Orc Peon",
  "categories": {
    "session.start": {
      "sounds": [
        { "file": "Hello1.wav", "label": "Ready to work?" },
        { "file": "Hello2.wav", "label": "Yes?" }
      ]
    },
    "task.acknowledge": {
      "sounds": [
        { "file": "Ack1.wav", "label": "Work, work." }
      ]
    },
    "task.complete": {
      "sounds": [
        { "file": "Done1.wav", "label": "Something need doing?" },
        { "file": "Done2.wav", "label": "Ready to work?" }
      ]
    },
    "task.error": {
      "sounds": [
        { "file": "Error1.wav", "label": "Me not that kind of orc!" }
      ]
    },
    "input.required": {
      "sounds": [
        { "file": "Perm1.wav", "label": "Something need doing?" },
        { "file": "Perm2.wav", "label": "Hmm?" }
      ]
    },
    "resource.limit": {
      "sounds": [
        { "file": "Limit1.wav", "label": "More work?" }
      ]
    },
    "user.spam": {
      "sounds": [
        { "file": "Angry1.wav", "label": "Me busy, leave me alone!" }
      ]
    }
  }
}
JSON

  # Create dummy sound files (empty but present)
  for f in Hello1.wav Hello2.wav Ack1.wav Done1.wav Done2.wav Error1.wav Perm1.wav Perm2.wav Limit1.wav Angry1.wav; do
    touch "$TEST_DIR/packs/peon/sounds/$f"
  done

  # Create second pack manifest (for pack switching tests)
  cat > "$TEST_DIR/packs/sc_kerrigan/manifest.json" <<'JSON'
{
  "name": "sc_kerrigan",
  "display_name": "Sarah Kerrigan (StarCraft)",
  "categories": {
    "session.start": {
      "sounds": [
        { "file": "Hello1.wav", "label": "What now?" }
      ]
    },
    "task.complete": {
      "sounds": [
        { "file": "Done1.wav", "label": "I gotcha." }
      ]
    }
  }
}
JSON

  for f in Hello1.wav Done1.wav; do
    touch "$TEST_DIR/packs/sc_kerrigan/sounds/$f"
  done

  # Create default config (CESP category names)
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "default_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "task.acknowledge": false,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10,
  "terminal_tab_title": true,
  "session_start_cooldown_seconds": 0
}
JSON

  # Create empty state
  echo '{}' > "$TEST_DIR/.state.json"

  # Create VERSION
  echo "1.0.0" > "$TEST_DIR/VERSION"

  # Create mock bin directory (prepended to PATH to intercept afplay, osascript, curl)
  MOCK_BIN="$TEST_DIR/mock_bin"
  mkdir -p "$MOCK_BIN"

  # Mock afplay — log calls instead of playing sound
  cat > "$MOCK_BIN/afplay" <<'SCRIPT'
#!/bin/bash
echo "$@" >> "${CLAUDE_PEON_DIR}/afplay.log"
echo "afplay" >> "${CLAUDE_PEON_DIR}/call_order.log"
SCRIPT
  chmod +x "$MOCK_BIN/afplay"

  # Mock peon-play — same log format as afplay mock
  cp "$MOCK_BIN/afplay" "$MOCK_BIN/peon-play"

  # Mock Linux audio backends — log calls instead of playing sound
  for player in pw-play paplay ffplay mpv play aplay; do
    cat > "$MOCK_BIN/$player" <<'SCRIPT'
#!/bin/bash
echo "$@" >> "${CLAUDE_PEON_DIR}/linux_audio.log"
SCRIPT
    chmod +x "$MOCK_BIN/$player"
  done

  # Mock xdotool for Linux focus detection tests
  cat > "$MOCK_BIN/xdotool" <<'SCRIPT'
#!/bin/bash
if [ -f "${CLAUDE_PEON_DIR}/.disabled_xdotool" ]; then
  exit 127
fi
if [[ "$*" == *"getwindowclassname"* ]]; then
  cat "${CLAUDE_PEON_DIR}/.mock_xdotool_window_class" 2>/dev/null
  exit 0
fi
if [[ "$*" == *"getwindowname"* ]]; then
  cat "${CLAUDE_PEON_DIR}/.mock_xdotool_window_name" 2>/dev/null
  exit 0
fi
exit 0
SCRIPT
  chmod +x "$MOCK_BIN/xdotool"

  # Mock terminal-notifier — log calls instead of sending real notifications
  cat > "$MOCK_BIN/terminal-notifier" <<'SCRIPT'
#!/bin/bash
echo "$@" >> "${CLAUDE_PEON_DIR}/terminal_notifier.log"
SCRIPT
  chmod +x "$MOCK_BIN/terminal-notifier"

  # Mock system_profiler — returns audio device info for headphone detection
  cat > "$MOCK_BIN/system_profiler" <<'SCRIPT'
#!/bin/bash
# Check for mock fixture files
if [ -f "${CLAUDE_PEON_DIR}/.mock_headphones_connected" ]; then
  cat <<'EOF'
Audio:

    Devices:

        External Headphones:

          Default Output Device: Yes
          Input Channels: 0
          Manufacturer: Apple Inc.
          Output Channels: 2
          Transport: USB

        MacBook Pro Speakers:

          Default Output Device: No
          Input Channels: 0
          Manufacturer: Apple Inc.
          Output Channels: 2
          Transport: Built-in

EOF
elif [ -f "${CLAUDE_PEON_DIR}/.mock_speakers_only" ]; then
  cat <<'EOF'
Audio:

    Devices:

        MacBook Pro Speakers:

          Default Output Device: Yes
          Default System Output Device: Yes
          Input Channels: 0
          Manufacturer: Apple Inc.
          Output Channels: 2
          Transport: Built-in

EOF
else
  # Default: headphones connected (same as .mock_headphones_connected)
  cat <<'EOF'
Audio:

    Devices:

        External Headphones:

          Default Output Device: Yes
          Input Channels: 0
          Manufacturer: Apple Inc.
          Output Channels: 2
          Transport: USB

EOF
fi
SCRIPT
  chmod +x "$MOCK_BIN/system_profiler"

  # Mock lsappinfo — returns a bundle ID for a given PID (IDE click-to-focus)
  cat > "$MOCK_BIN/lsappinfo" <<'SCRIPT'
#!/bin/bash
# Parse -app pid:<PID> or pid=<PID> to extract the requested PID
for arg in "$@"; do
  case "$arg" in
    pid:*|pid=*)
      _pid="${arg#pid:}"
      _pid="${_pid#pid=}"
      # Return mock bundle IDs for known test PIDs
      if [ -f "${CLAUDE_PEON_DIR}/.mock_ide_bundle_id" ]; then
        bid=$(cat "${CLAUDE_PEON_DIR}/.mock_ide_bundle_id")
        echo "\"bundleid\"=\"$bid\""
        exit 0
      fi
      ;;
  esac
done
exit 1
SCRIPT
  chmod +x "$MOCK_BIN/lsappinfo"

  # Mock osascript — log calls instead of running AppleScript/JXA
  cat > "$MOCK_BIN/osascript" <<'SCRIPT'
#!/bin/bash
# For the frontmost app check, return terminal name or "Safari" based on fixture
if [[ "$*" == *"frontmost"* ]]; then
  if [ -f "${CLAUDE_PEON_DIR}/.mock_terminal_focused" ]; then
    cat "${CLAUDE_PEON_DIR}/.mock_terminal_focused"
  else
    echo "Safari"
  fi
elif [[ "$*" == *"iTerm2"* ]] && [[ "$*" == *"tty"* ]]; then
  # iTerm2 tty query — return mock tty if fixture exists
  if [ -f "${CLAUDE_PEON_DIR}/.mock_iterm_active_ttys" ]; then
    cat "${CLAUDE_PEON_DIR}/.mock_iterm_active_ttys"
  fi
elif [[ "$1" == "-l" ]] && [[ "$2" == "JavaScript" ]]; then
  # JXA overlay call — log to overlay.log with full arguments
  echo "$@" >> "${CLAUDE_PEON_DIR}/overlay.log"
else
  echo "$@" >> "${CLAUDE_PEON_DIR}/osascript.log"
fi
SCRIPT
  chmod +x "$MOCK_BIN/osascript"

  # Mock cmux — returns fixture identify payloads and logs focus commands.
  cat > "$MOCK_BIN/cmux" <<'SCRIPT'
#!/bin/bash
echo "$@" >> "${CLAUDE_PEON_DIR}/cmux.log"
if [ -f "${CLAUDE_PEON_DIR}/.mock_cmux_fail_once" ]; then
  if printf '%s\n' "$@" | grep -q "set-status"; then
    state_file="${CLAUDE_PEON_DIR}/.mock_cmux_fail_once.state"
    if [ ! -f "$state_file" ]; then
      touch "$state_file"
      echo "Error: Failed to write to socket (Broken pipe, errno 32)" >&2
      exit 1
    fi
  fi
fi
for arg in "$@"; do
  if [ "$arg" = "list-workspaces" ]; then
    if [ -f "${CLAUDE_PEON_DIR}/.mock_cmux_list_workspaces_json" ]; then
      cat "${CLAUDE_PEON_DIR}/.mock_cmux_list_workspaces_json"
    else
      cat <<'JSON'
{"workspaces":[{"id":"11111111-1111-1111-1111-111111111111","ref":"workspace:5","title":"test"}]}
JSON
    fi
    exit 0
  fi
  if [ "$arg" = "identify" ]; then
    if [ -f "${CLAUDE_PEON_DIR}/.mock_cmux_identify_json" ]; then
      cat "${CLAUDE_PEON_DIR}/.mock_cmux_identify_json"
    else
      echo '{"focused":null,"caller":null}'
    fi
    exit 0
  fi
  if [ "$arg" = "focus-panel" ]; then
    echo "$@" >> "${CLAUDE_PEON_DIR}/cmux_focus.log"
    echo '{"ok":true}'
    exit 0
  fi
done
echo '{"ok":true}'
SCRIPT
  chmod +x "$MOCK_BIN/cmux"

  # Mock curl — handles version checks, relay requests, mobile notifications,
  # and pack registry/manifest/sound downloads (when mock fixtures exist)
  cat > "$MOCK_BIN/curl" <<'SCRIPT'
#!/bin/bash
# Parse -o flag and URL for pack download support
_curl_output=""
_curl_url=""
_curl_prev=""
for _a in "$@"; do
  if [ "$_curl_prev" = "-o" ]; then _curl_output="$_a"; fi
  case "$_a" in http*) _curl_url="$_a" ;; esac
  _curl_prev="$_a"
done

# Pack registry/manifest/sound download patterns (activated by mock fixture files)
if [[ "$_curl_url" == *"registry"*"index.json"* ]] || [[ "$_curl_url" == *"peonping"*"index.json"* ]]; then
  if [ -f "${CLAUDE_PEON_DIR}/.mock_registry_fail" ]; then
    exit 22
  elif [ -f "${CLAUDE_PEON_DIR}/.mock_registry_json" ]; then
    if [ -n "$_curl_output" ]; then
      cp "${CLAUDE_PEON_DIR}/.mock_registry_json" "$_curl_output"
    else
      cat "${CLAUDE_PEON_DIR}/.mock_registry_json"
    fi
    exit 0
  fi
fi
if [[ "$_curl_url" == *"openpeon.json"* ]] && [ -f "${CLAUDE_PEON_DIR}/.mock_manifest_json" ]; then
  if [ -n "$_curl_output" ]; then
    cp "${CLAUDE_PEON_DIR}/.mock_manifest_json" "$_curl_output"
  fi
  exit 0
fi
if [[ "$_curl_url" == *"/sounds/"* ]] && [ -n "$_curl_output" ]; then
  if [ -f "${CLAUDE_PEON_DIR}/.mock_manifest_json" ]; then
    printf 'RIFF' > "$_curl_output"
    exit 0
  fi
fi

# Check if this is a relay request (devcontainer/SSH audio/notification/health)
for arg in "$@"; do
  if [[ "$arg" == *"/play?"* ]] || [[ "$arg" == *"/health"* ]]; then
    echo "RELAY: $*" >> "${CLAUDE_PEON_DIR}/relay_curl.log"
    # For /play requests, also log to afplay.log so afplay_was_called works
    if [[ "$arg" == *"/play?"* ]]; then
      # Extract file path from URL query string and decode %2F to /
      file=$(echo "$arg" | sed -n 's/.*file=\([^&]*\).*/\1/p' | sed 's/%2F/\//g')
      # Extract volume from headers (look for -H X-Volume: in args)
      volume="0.5"
      for i in "$@"; do
        if [[ "$prev" == "-H" ]] && [[ "$i" == "X-Volume:"* ]]; then
          volume=$(echo "$i" | cut -d: -f2 | tr -d ' ')
        fi
        prev="$i"
      done
      # Write in afplay format: -v 0.5 /full/path/to/sound.wav
      echo "-v $volume ${CLAUDE_PEON_DIR}/$file" >> "${CLAUDE_PEON_DIR}/afplay.log"
    fi
    if [ -f "${CLAUDE_PEON_DIR}/.relay_available" ]; then
      exit 0
    else
      exit 7
    fi
  fi
  # Relay notify (devcontainer/SSH POST)
  if [[ "$arg" == *"/notify"* ]] && [[ "$arg" == *"19998"* || "$arg" == *"12345"* ]]; then
    echo "RELAY: $*" >> "${CLAUDE_PEON_DIR}/relay_curl.log"
    exit 0
  fi
  # Mobile push notification services
  if [[ "$arg" == *"ntfy.sh"* ]] || [[ "$arg" == *"ntfy/"* ]]; then
    echo "MOBILE_NTFY: $*" >> "${CLAUDE_PEON_DIR}/mobile_curl.log"
    exit 0
  fi
  if [[ "$arg" == *"api.pushover.net"* ]]; then
    echo "MOBILE_PUSHOVER: $*" >> "${CLAUDE_PEON_DIR}/mobile_curl.log"
    exit 0
  fi
  if [[ "$arg" == *"api.telegram.org"* ]]; then
    echo "MOBILE_TELEGRAM: $*" >> "${CLAUDE_PEON_DIR}/mobile_curl.log"
    exit 0
  fi
done
# Version check behavior
if [ -f "${CLAUDE_PEON_DIR}/.mock_remote_version" ]; then
  cat "${CLAUDE_PEON_DIR}/.mock_remote_version"
else
  echo "1.0.0"
fi
SCRIPT
  chmod +x "$MOCK_BIN/curl"

  export PATH="$MOCK_BIN:$PATH"

  # Mock meeting-detect binary — returns MIC_IN_USE or MIC_NOT_IN_USE based on fixture
  mkdir -p "$TEST_DIR/scripts"
  cat > "$TEST_DIR/scripts/meeting-detect" <<'SCRIPT'
#!/bin/bash
if [ -f "${CLAUDE_PEON_DIR}/.mock_mic_in_use" ]; then
  echo "MIC_IN_USE"
else
  echo "MIC_NOT_IN_USE"
fi
SCRIPT
  chmod +x "$TEST_DIR/scripts/meeting-detect"

  # Copy notify.sh into test dir so send_notification() can find it
  _src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  mkdir -p "$TEST_DIR/scripts"
  if [ -f "$_src_dir/scripts/notify.sh" ]; then
    cp "$_src_dir/scripts/notify.sh" "$TEST_DIR/scripts/notify.sh"
    chmod +x "$TEST_DIR/scripts/notify.sh"
  fi
  if [ -f "$_src_dir/scripts/cmux-focus.sh" ]; then
    cp "$_src_dir/scripts/cmux-focus.sh" "$TEST_DIR/scripts/cmux-focus.sh"
    chmod +x "$TEST_DIR/scripts/cmux-focus.sh"
  fi
  if [ -f "$_src_dir/scripts/cmux-status-presentation.sh" ]; then
    cp "$_src_dir/scripts/cmux-status-presentation.sh" "$TEST_DIR/scripts/cmux-status-presentation.sh"
    chmod +x "$TEST_DIR/scripts/cmux-status-presentation.sh"
  fi
  if [ -f "$_src_dir/scripts/cmux-workspace-field.sh" ]; then
    cp "$_src_dir/scripts/cmux-workspace-field.sh" "$TEST_DIR/scripts/cmux-workspace-field.sh"
    chmod +x "$TEST_DIR/scripts/cmux-workspace-field.sh"
  fi
  # Mock relay as available for devcontainer/SSH tests
  # (Tests running in devcontainer need this to prevent "relay not reachable" errors)
  touch "$TEST_DIR/.relay_available"

  # Locate peon.sh (relative to this test file)
  PEON_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/peon.sh"
  # Change to TEST_DIR so PWD-based local config lookup does not pick up
  # a real installation config (e.g. with pack_rotation) from outside the test env
  cd "$TEST_DIR"
}

# Install mock TTS backend script at $PEON_DIR/scripts/tts-native.sh
# Reads text from stdin and logs invocation args + text to tts.log
install_mock_tts_backend() {
  mkdir -p "$TEST_DIR/scripts"
  cat > "$TEST_DIR/scripts/tts-native.sh" <<'SCRIPT'
#!/bin/bash
# Mock TTS backend: logs voice, rate, volume args and stdin text
text=$(cat)
echo "voice=$1 rate=$2 vol=$3 text=$text" >> "${CLAUDE_PEON_DIR}/tts.log"
echo "tts" >> "${CLAUDE_PEON_DIR}/call_order.log"
SCRIPT
  chmod +x "$TEST_DIR/scripts/tts-native.sh"
}

# Helper: check if TTS backend was called
tts_was_called() {
  [ -f "$TEST_DIR/tts.log" ] && [ -s "$TEST_DIR/tts.log" ]
}

# Helper: get TTS call count
tts_call_count() {
  if [ -f "$TEST_DIR/tts.log" ]; then
    wc -l < "$TEST_DIR/tts.log" | tr -d ' '
  else
    echo "0"
  fi
}

# Helper: get call ordering (reads combined call_order.log)
# Returns lines like "afplay\ntts" — callers compare line positions.
call_order() {
  if [ -f "$TEST_DIR/call_order.log" ]; then
    cat "$TEST_DIR/call_order.log"
  fi
}

# Helper: get last TTS log line
tts_last_call() {
  if [ -f "$TEST_DIR/tts.log" ]; then
    tail -1 "$TEST_DIR/tts.log"
  fi
}

# Helper: run peon.sh with TTS config written to config.json
# Usage: run_peon_tts <json> [speech_text] [TTS_MODE] [TTS_ENABLED]
# speech_text is injected into the manifest's task.complete entries so the
# Python block resolves it as TTS_TEXT.  Pass "" to test empty-text skip.
run_peon_tts() {
  local json="$1"
  local speech_text="${2:-Hello world}"
  local tts_mode="${3:-sound-then-speak}"
  local tts_enabled="${4:-true}"

  # Write TTS section into config.json so the Python block picks it up
  "$PEON_PY" -c "
import json, sys
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['tts'] = {
  'enabled': $( [ "$tts_enabled" = "true" ] && echo "True" || echo "False" ),
  'backend': 'native',
  'voice': 'default',
  'rate': 1.0,
  'volume': 0.5,
  'mode': '$tts_mode'
}
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"

  # Inject speech_text into manifest sound entries so the Python TTS
  # resolution chain finds it.  An empty string means no speech_text field.
  if [ -n "$speech_text" ]; then
    "$PEON_PY" -c "
import json
m = json.load(open('$TEST_DIR/packs/peon/manifest.json'))
for cat in m.get('categories', {}).values():
    for entry in cat.get('sounds', []):
        entry['speech_text'] = $(printf '%s' "$speech_text" | "$PEON_PY" -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
json.dump(m, open('$TEST_DIR/packs/peon/manifest.json', 'w'))
"
  fi

  export PEON_TEST=1
  echo "$json" | bash "$PEON_SH" 2>"$TEST_DIR/stderr.log"
  PEON_EXIT=$?
  PEON_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
}

teardown_test_env() {
  # Clean up relay mock
  rm -f "$TEST_DIR/.relay_available" 2>/dev/null || true
  rm -rf "$TEST_DIR" 2>/dev/null || true
}

# Set up mock fixtures for pack-download.sh tests
setup_pack_download_env() {
  # Mock registry JSON (includes language field for --lang filter tests)
  cat > "$TEST_DIR/.mock_registry_json" <<'JSON'
{"packs":[{"name":"test_pack_a","display_name":"Test Pack A","language":"en","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"test_pack_a"},{"name":"test_pack_b","display_name":"Test Pack B","language":"fr","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"test_pack_b"},{"name":"test_pack_c","display_name":"Test Pack C","language":"en-GB","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"test_pack_c"},{"name":"test_pack_d","display_name":"Test Pack D","language":"en,ru","source_repo":"PeonPing/og-packs","source_ref":"v1.0.0","source_path":"test_pack_d"}]}
JSON

  # Mock manifest (used for any openpeon.json download)
  cat > "$TEST_DIR/.mock_manifest_json" <<'JSON'
{"cesp_version":"1.0","name":"mock","display_name":"Mock Pack","categories":{"session.start":{"sounds":[{"file":"sounds/Hello1.wav","label":"Hello"}]}}}
JSON

  # Locate pack-download.sh (relative to this test file)
  PACK_DL_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/pack-download.sh"

  # Create scripts dir so peon.sh can find pack-download.sh
  mkdir -p "$TEST_DIR/scripts"
  cp "$PACK_DL_SH" "$TEST_DIR/scripts/pack-download.sh"
  chmod +x "$TEST_DIR/scripts/pack-download.sh"
}

# Helper: run peon.sh with a JSON event
run_peon() {
  local json="$1"
  export PEON_TEST=1
  echo "$json" | bash "$PEON_SH" 2>"$TEST_DIR/stderr.log"
  PEON_EXIT=$?
  PEON_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
}

# Helper: check if afplay was called
afplay_was_called() {
  [ -f "$TEST_DIR/afplay.log" ] && [ -s "$TEST_DIR/afplay.log" ]
}

# Helper: get the sound file afplay was called with
afplay_sound() {
  if [ -f "$TEST_DIR/afplay.log" ]; then
    # afplay log format: -v 0.5 /path/to/sound.wav
    tail -1 "$TEST_DIR/afplay.log" | awk '{print $NF}'
  fi
}

# Helper: get afplay call count
afplay_call_count() {
  if [ -f "$TEST_DIR/afplay.log" ]; then
    wc -l < "$TEST_DIR/afplay.log" | tr -d ' '
  else
    echo "0"
  fi
}

# Helper: install peon-play mock at $PEON_DIR/scripts/peon-play (where peon.sh looks)
install_peon_play_mock() {
  mkdir -p "$TEST_DIR/scripts"
  cat > "$TEST_DIR/scripts/peon-play" <<'SCRIPT'
#!/bin/bash
echo "$@" >> "${CLAUDE_PEON_DIR}/peon-play.log"
SCRIPT
  chmod +x "$TEST_DIR/scripts/peon-play"
}

# Helper: check if peon-play was called (via $PEON_DIR/scripts/peon-play)
peon_play_was_called() {
  [ -f "$TEST_DIR/peon-play.log" ] && [ -s "$TEST_DIR/peon-play.log" ]
}

# Helper: check if a Linux audio player was called
linux_audio_was_called() {
  [ -f "$TEST_DIR/linux_audio.log" ] && [ -s "$TEST_DIR/linux_audio.log" ]
}

# Helper: get the command line used for Linux audio
linux_audio_cmdline() {
  if [ -f "$TEST_DIR/linux_audio.log" ]; then
    tail -1 "$TEST_DIR/linux_audio.log"
  fi
}

# Helper: check if a relay curl request was made
relay_was_called() {
  [ -f "$TEST_DIR/relay_curl.log" ] && [ -s "$TEST_DIR/relay_curl.log" ]
}

# Helper: get the relay curl request line
relay_cmdline() {
  if [ -f "$TEST_DIR/relay_curl.log" ]; then
    tail -1 "$TEST_DIR/relay_curl.log"
  fi
}

# Helper: get relay call count
relay_call_count() {
  if [ -f "$TEST_DIR/relay_curl.log" ]; then
    wc -l < "$TEST_DIR/relay_curl.log" | tr -d ' '
  else
    echo "0"
  fi
}

# Helper: get the resolved icon path
resolved_icon() {
  if [ -f "$TEST_DIR/.icon_path" ]; then
    cat "$TEST_DIR/.icon_path"
  fi
}

# Helper: check if a mobile notification was sent
mobile_was_called() {
  [ -f "$TEST_DIR/mobile_curl.log" ] && [ -s "$TEST_DIR/mobile_curl.log" ]
}

# Helper: get the mobile notification request line
mobile_cmdline() {
  if [ -f "$TEST_DIR/mobile_curl.log" ]; then
    tail -1 "$TEST_DIR/mobile_curl.log"
  fi
}

# Helper: enable debug logging in the test config
# Replaces the copy-pasted python3 JSON manipulation boilerplate
enable_debug_logging() {
  "$PEON_PY" -c "
import json
cfg = json.load(open('$TEST_DIR/config.json'))
cfg['debug'] = True
json.dump(cfg, open('$TEST_DIR/config.json', 'w'))
"
}
