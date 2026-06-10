#!/usr/bin/env bats

# Pi is a TypeScript-extension agent (earendil-works/pi), vendored under
# adapters/pi/ with a bash installer (adapters/pi.sh). There is no audio path
# to exercise here (the extension shells out to peon.sh/peon.ps1 at runtime),
# so this suite asserts the installer and extension *structure*.

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  PI_SH="$REPO_ROOT/adapters/pi.sh"
  PI_TS="$REPO_ROOT/adapters/pi/peon-ping.ts"
}

# ============================================================
# Installer (adapters/pi.sh)
# ============================================================

@test "installer has valid bash syntax" {
  run bash -n "$PI_SH"
  [ "$status" -eq 0 ]
}

@test "installer targets ~/.pi/agent/extensions" {
  run grep -q 'agent/extensions' "$PI_SH"
  [ "$status" -eq 0 ]
}

@test "installer supports --uninstall" {
  run grep -q -- '--uninstall' "$PI_SH"
  [ "$status" -eq 0 ]
}

@test "installer copies the local vendored extension or falls back to curl" {
  run grep -Eq 'cp "\$LOCAL_EXTENSION"|curl -fsSL "\$PLUGIN_URL"' "$PI_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Extension (adapters/pi/peon-ping.ts)
# ============================================================

@test "extension file exists" {
  [ -f "$PI_TS" ]
}

@test "extension exports a default factory" {
  run grep -Eq 'export default function' "$PI_TS"
  [ "$status" -eq 0 ]
}

@test "extension subscribes via pi.on" {
  run grep -q 'pi.on(' "$PI_TS"
  [ "$status" -eq 0 ]
}

@test "extension maps session_start to SessionStart" {
  run grep -q 'session_start' "$PI_TS"
  [ "$status" -eq 0 ]
  run grep -q '"SessionStart"' "$PI_TS"
  [ "$status" -eq 0 ]
}

@test "extension maps agent_end to Stop" {
  run grep -q 'agent_end' "$PI_TS"
  [ "$status" -eq 0 ]
  run grep -q '"Stop"' "$PI_TS"
  [ "$status" -eq 0 ]
}

@test "extension maps a failed tool_result to PostToolUseFailure" {
  run grep -q 'tool_result' "$PI_TS"
  [ "$status" -eq 0 ]
  run grep -q 'PostToolUseFailure' "$PI_TS"
  [ "$status" -eq 0 ]
}

@test "extension tags session id with pi- prefix" {
  run grep -q 'pi-' "$PI_TS"
  [ "$status" -eq 0 ]
}

@test "extension does not throw into the agent on spawn failure" {
  run grep -q 'catch' "$PI_TS"
  [ "$status" -eq 0 ]
}
