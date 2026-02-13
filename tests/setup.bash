# Common test setup for peon-ping bats tests

# Create isolated test environment so we never touch real config
setup_test_env() {
  TEST_DIR="$(mktemp -d)"
  export CLAUDE_PEON_DIR="$TEST_DIR"

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
    "user.spam": {
      "sounds": [
        { "file": "Angry1.wav", "label": "Me busy, leave me alone!" }
      ]
    }
  }
}
JSON

  # Create dummy sound files (empty but present)
  for f in Hello1.wav Hello2.wav Ack1.wav Done1.wav Done2.wav Error1.wav Perm1.wav Perm2.wav Angry1.wav; do
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
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "session.start": true,
    "task.acknowledge": true,
    "task.complete": true,
    "task.error": true,
    "input.required": true,
    "resource.limit": true,
    "user.spam": true
  },
  "annoyed_threshold": 3,
  "annoyed_window_seconds": 10
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
SCRIPT
  chmod +x "$MOCK_BIN/afplay"

  # Mock Linux audio backends — log calls instead of playing sound
  for player in pw-play paplay ffplay mpv play aplay; do
    cat > "$MOCK_BIN/$player" <<'SCRIPT'
#!/bin/bash
echo "$@" >> "${CLAUDE_PEON_DIR}/linux_audio.log"
SCRIPT
    chmod +x "$MOCK_BIN/$player"
  done

  # Mock osascript — log calls instead of running AppleScript
  cat > "$MOCK_BIN/osascript" <<'SCRIPT'
#!/bin/bash
# For the frontmost app check, return "Safari" (not a terminal) so notifications fire
if [[ "$*" == *"frontmost"* ]]; then
  echo "Safari"
else
  echo "$@" >> "${CLAUDE_PEON_DIR}/osascript.log"
fi
SCRIPT
  chmod +x "$MOCK_BIN/osascript"

  # Mock curl — handles both version checks and relay requests
  cat > "$MOCK_BIN/curl" <<'SCRIPT'
#!/bin/bash
# Check if this is a relay request (devcontainer audio/notification/health)
for arg in "$@"; do
  if [[ "$arg" == *"/play?"* ]] || [[ "$arg" == *"/notify"* ]] || [[ "$arg" == *"/health"* ]]; then
    echo "RELAY: $*" >> "${CLAUDE_PEON_DIR}/relay_curl.log"
    # Simulate relay availability based on marker file
    if [ -f "${CLAUDE_PEON_DIR}/.relay_available" ]; then
      exit 0
    else
      exit 7  # curl exit code for connection refused
    fi
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

  # Locate peon.sh (relative to this test file)
  PEON_SH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/peon.sh"
}

teardown_test_env() {
  rm -rf "$TEST_DIR"
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
