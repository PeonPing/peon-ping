# Common test setup for peon-ping bats tests

# Create isolated test environment so we never touch real config
setup_test_env() {
  TEST_DIR="$(mktemp -d)"
  export CLAUDE_PEON_DIR="$TEST_DIR"

  # Create directory structure
  mkdir -p "$TEST_DIR/packs/peon/sounds"

  # Create minimal manifest
  cat > "$TEST_DIR/packs/peon/manifest.json" <<'JSON'
{
  "name": "peon",
  "display_name": "Orc Peon",
  "categories": {
    "greeting": {
      "sounds": [
        { "file": "Hello1.wav", "line": "Ready to work?" },
        { "file": "Hello2.wav", "line": "Yes?" }
      ]
    },
    "acknowledge": {
      "sounds": [
        { "file": "Ack1.wav", "line": "Work, work." }
      ]
    },
    "complete": {
      "sounds": [
        { "file": "Done1.wav", "line": "Something need doing?" },
        { "file": "Done2.wav", "line": "Ready to work?" }
      ]
    },
    "error": {
      "sounds": [
        { "file": "Error1.wav", "line": "Me not that kind of orc!" }
      ]
    },
    "permission": {
      "sounds": [
        { "file": "Perm1.wav", "line": "Something need doing?" },
        { "file": "Perm2.wav", "line": "Hmm?" }
      ]
    },
    "annoyed": {
      "sounds": [
        { "file": "Angry1.wav", "line": "Me busy, leave me alone!" }
      ]
    }
  }
}
JSON

  # Create dummy sound files (empty but present)
  for f in Hello1.wav Hello2.wav Ack1.wav Done1.wav Done2.wav Error1.wav Perm1.wav Perm2.wav Angry1.wav; do
    touch "$TEST_DIR/packs/peon/sounds/$f"
  done

  # Create default config
  cat > "$TEST_DIR/config.json" <<'JSON'
{
  "active_pack": "peon",
  "volume": 0.5,
  "enabled": true,
  "categories": {
    "greeting": true,
    "acknowledge": true,
    "complete": true,
    "error": true,
    "permission": true,
    "resource_limit": true,
    "annoyed": true
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

  # Mock curl — return a configurable version string
  cat > "$MOCK_BIN/curl" <<'SCRIPT'
#!/bin/bash
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
