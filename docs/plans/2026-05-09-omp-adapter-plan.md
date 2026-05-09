# omp (oh-my-pi) Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a peon-ping adapter so [oh-my-pi](https://github.com/can1357/oh-my-pi) (`omp`) users get sounds, notifications, trainer reminders, mobile push, SSH/devcontainer relay, and tab-title updates — exactly like every other supported IDE.

**Architecture:** A thin TypeScript extension (`adapters/omp/peon-ping.ts`) subscribes to omp's `ExtensionAPI` lifecycle events and `spawn`s `peon.sh` with CESP-shaped JSON on stdin (`source: "omp"`, session-id prefix `omp-`). Three small additions to `peon.sh`'s IDE-resolution tables (`IDE_ALIASES`, `IDE_DISPLAY_NAMES`, `prefix_map`) let the existing routing recognize omp. A shell installer (`adapters/omp.sh`) drops the extension into `~/.omp/agent/extensions/peon-ping/`.

**Tech Stack:** TypeScript (Node-compatible — type-only import of `@oh-my-pi/pi-coding-agent`), Bash, Python (inside `peon.sh`), BATS for tests.

**Spec:** [`docs/designs/2026-05-09-omp-adapter-design.md`](../designs/2026-05-09-omp-adapter-design.md).

**Out of scope (per design):** Windows-native `omp.ps1`, `PermissionRequest` mapping, branch/tree/TTSR events, user-visible `--local` installer flag, version bump, cross-repo (homebrew-tap, peonping-x-bot) updates — these happen at release time, not in this PR.

---

## File Structure

| File                                    | Purpose                                                                                | Status   |
|-----------------------------------------|----------------------------------------------------------------------------------------|----------|
| `adapters/omp/peon-ping.ts`             | TS extension: subscribes to omp events, spawns `peon.sh` with CESP payload             | Create   |
| `adapters/omp/package.json`             | omp directory-extension manifest pointing at `peon-ping.ts`                            | Create   |
| `adapters/omp.sh`                       | Installer: copies adapter into `~/.omp/agent/extensions/peon-ping/`; supports `--uninstall` | Create   |
| `tests/omp.bats`                        | BATS coverage for IDE-table wiring + installer behavior                                | Create   |
| `peon.sh`                               | Add `omp` to `IDE_ALIASES`, `IDE_DISPLAY_NAMES`, and `prefix_map` (3 tiny edits)       | Modify   |
| `README.md`                             | Add omp badge, Multi-IDE table row, `### omp setup` section                            | Modify   |
| `README_zh.md`, `README_ko.md`, `README_ja.md` | Mirror the README changes                                                       | Modify   |
| `docs/public/llms.txt`                  | Add omp adapter line                                                                   | Modify   |
| `CHANGELOG.md`                          | Add `### Added` entry to a new `[Unreleased]` section if missing                       | Modify   |

---

## Task 1: Wire omp into `peon.sh` IDE-resolution tables (TDD)

**Files:**
- Create: `tests/omp.bats`
- Modify: `peon.sh:4887-4967`

The end-to-end goal of this task: synthetic events with `source: "omp"` (or session-id `omp-…`) get recognized, displayed as `oh-my-pi`, and routed through existing peon-ping logic. Tests come first.

- [ ] **Step 1: Create `tests/omp.bats` with three failing tests covering IDE detection**

```bash
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
  rm -rf "$TEST_DIR"
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
  grep -q "myproject - oh-my-pi" "$TEST_DIR/terminal_notifier.log"
}

@test "omp- session-id prefix falls back to omp when source missing" {
  run_peon '{"hook_event_name":"Stop","cwd":"/tmp/myproject","session_id":"omp-456","permission_mode":"default"}'
  [ "$PEON_EXIT" -eq 0 ]
  grep -q "myproject - oh-my-pi" "$TEST_DIR/terminal_notifier.log"
}
```

- [ ] **Step 2: Run the new tests and confirm they fail**

Run: `bats tests/omp.bats`
Expected: all three tests FAIL (assertion `grep -q "myproject - oh-my-pi"` returns non-zero, because `peon.sh` currently has no `omp` entry — the unknown-source fallback titlecases it as `Omp` or similar, not `oh-my-pi`).

- [ ] **Step 3: Add `omp` to `peon.sh` `IDE_ALIASES` block**

Open `peon.sh` and locate the `IDE_ALIASES` dict at line ~4887 (right after `'rovodev': 'rovodev',`). Append the omp entries before the closing `}`:

```python
    'rovodev': 'rovodev',
    'rovo': 'rovodev',
    'omp': 'omp',
    'oh-my-pi': 'omp',
    'oh_my_pi': 'omp',
    'pi': 'omp',
}
```

- [ ] **Step 4: Add `('omp-', 'omp')` to the `prefix_map` tuple inside `detect_session_ide`**

Locate `prefix_map = (` at line ~4931. Append after `('rovodev-', 'rovodev'),`:

```python
        ('rovodev-', 'rovodev'),
        ('omp-', 'omp'),
    )
```

- [ ] **Step 5: Add `'omp': 'oh-my-pi'` to `IDE_DISPLAY_NAMES`**

Locate `IDE_DISPLAY_NAMES = {` at line ~4952. Append before the closing `}`:

```python
    'rovodev': 'Rovo Dev CLI',
    'omp': 'oh-my-pi',
}
```

- [ ] **Step 6: Re-run the tests and confirm they pass**

Run: `bats tests/omp.bats`
Expected: all three IDE-detection tests PASS.

- [ ] **Step 7: Run the full `peon.bats` suite to confirm no regressions**

Run: `bats tests/peon.bats`
Expected: PASS at the same green-count as before the change. (No `peon.bats` test references `omp`/`oh-my-pi`; this is a guard against accidental table-syntax breakage.)

- [ ] **Step 8: Commit**

```bash
git add peon.sh tests/omp.bats
git commit -m "feat(adapters): recognize 'omp' source in peon.sh IDE tables

Adds omp (oh-my-pi) entries to IDE_ALIASES, IDE_DISPLAY_NAMES, and the
session-id-prefix fallback in detect_session_ide so events with
source='omp' or session_id starting with 'omp-' resolve correctly and
render as 'oh-my-pi' in desktop notifications.

Part 1/5 of the omp adapter rollout.
See docs/designs/2026-05-09-omp-adapter-design.md."
```

---

## Task 2: Create the omp extension files

**Files:**
- Create: `adapters/omp/peon-ping.ts`
- Create: `adapters/omp/package.json`

This task ships the actual extension. It has no automated test of its own (peon-ping CI doesn't run TS); the manual smoke test is `bun build` (verifies type compatibility) plus the BATS coverage in Task 3 that exercises the installer copying these files.

- [ ] **Step 1: Create `adapters/omp/peon-ping.ts`**

```ts
/**
 * peon-ping for oh-my-pi (omp) — Thin Adapter
 *
 * Routes omp ExtensionAPI events through peon.sh instead of re-implementing
 * sound playback, notifications, and trainer features in TypeScript.
 *
 * This gives omp users access to ALL peon-ping features:
 * - Sound packs & rotation
 * - Desktop notifications
 * - Trainer reminders (pushups, squats, etc.)
 * - Spam detection
 * - SSH/devcontainer relay
 * - All config options via `peon` CLI
 * - Tab title updates
 *
 * Event mapping (omp ExtensionAPI → peon.sh hook_event_name):
 *   session_start                       → SessionStart
 *   turn_start                          → UserPromptSubmit
 *   turn_end                            → Stop
 *   tool_result (event.isError === true) → PostToolUseFailure
 *   auto_compaction_start               → PreCompact
 *   session_shutdown                    → SessionEnd
 *
 * Requires peon-ping installed: brew install PeonPing/tap/peon-ping
 *   or: curl -fsSL peonping.com/install | bash
 */

import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { spawn } from "node:child_process"
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent"

const PEON_SH_PATHS = [
  path.join(os.homedir(), ".claude", "hooks", "peon-ping", "peon.sh"),
  path.join(os.homedir(), ".openclaw", "hooks", "peon-ping", "peon.sh"),
]

function findPeonSh(): string | null {
  for (const p of PEON_SH_PATHS) {
    try {
      if (fs.existsSync(p)) return p
    } catch {}
  }
  return null
}

function setTabTitle(title: string): void {
  process.stdout.write(`\x1b]0;${title}\x07`)
}

export default function peonPingExtension(pi: ExtensionAPI): void {
  const peonSh = findPeonSh()
  if (!peonSh) {
    console.warn("[peon-ping] peon.sh not found. Install peon-ping first:")
    console.warn("  brew install PeonPing/tap/peon-ping")
    console.warn("  # or: curl -fsSL peonping.com/install | bash")
    return
  }

  const cwd = process.cwd()
  const projectName = path.basename(cwd) || "omp"
  const sessionId = `omp-${Date.now()}`

  function firePeon(event: string): void {
    const payload = JSON.stringify({
      hook_event_name: event,
      notification_type: "",
      cwd,
      session_id: sessionId,
      permission_mode: "",
      source: "omp",
    })

    try {
      const proc = spawn("bash", [peonSh], {
        stdio: ["pipe", "ignore", "ignore"],
      })
      proc.stdin.write(payload)
      proc.stdin.end()
      proc.unref()
    } catch {}
  }

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.hasUI) setTabTitle(`${projectName}: ready`)
    firePeon("SessionStart")
  })

  pi.on("turn_start", async (_event, ctx) => {
    if (ctx.hasUI) setTabTitle(`${projectName}: working`)
    firePeon("UserPromptSubmit")
  })

  pi.on("turn_end", async (_event, ctx) => {
    if (ctx.hasUI) setTabTitle(`\u25cf ${projectName}: done`)
    firePeon("Stop")
  })

  pi.on("tool_result", async (event, ctx) => {
    if (!event.isError) return
    if (ctx.hasUI) setTabTitle(`\u25cf ${projectName}: error`)
    firePeon("PostToolUseFailure")
  })

  pi.on("auto_compaction_start", async () => {
    firePeon("PreCompact")
  })

  pi.on("session_shutdown", async () => {
    firePeon("SessionEnd")
  })
}
```

- [ ] **Step 2: Create `adapters/omp/package.json`**

```json
{
  "name": "peon-ping",
  "version": "1.0.0",
  "description": "peon-ping adapter for oh-my-pi (omp) — routes lifecycle events through peon.sh.",
  "omp": {
    "extensions": ["./peon-ping.ts"]
  }
}
```

- [ ] **Step 3: Smoke-test the TypeScript with `bun build`**

This verifies the file parses and resolves its type-only import without bundling — the `--target=node` flag matches how omp will load it (the runtime is bun under the hood, but the extension is loaded as a Node-compatible module).

Run: `cd /tmp && bun build --target=node /Users/$USER/workspace/peon-ping/adapters/omp/peon-ping.ts --outfile=/tmp/peon-ping-omp-smoke.js && rm /tmp/peon-ping-omp-smoke.js`
Expected: exit 0, no errors. (`bun build` on a `.ts` with type-only imports does not require the imported package to be installed.)

If `bun` is not on PATH, fall back to: `node --check adapters/omp/peon-ping.ts` will fail because Node can't parse TS — instead use `npx -p typescript@latest tsc --noEmit --target ES2022 --module nodenext --moduleResolution nodenext --skipLibCheck --allowImportingTsExtensions adapters/omp/peon-ping.ts`. Either succeeds; pick whichever is available locally and document the choice in the commit message.

- [ ] **Step 4: Commit**

```bash
git add adapters/omp/peon-ping.ts adapters/omp/package.json
git commit -m "feat(adapters): add omp (oh-my-pi) ExtensionAPI extension

Subscribes to omp lifecycle events (session_start, turn_start, turn_end,
tool_result, auto_compaction_start, session_shutdown) and pipes
CESP-shaped JSON to peon.sh with source='omp'.

Type-only import of @oh-my-pi/pi-coding-agent — the package supplies the
ExtensionAPI value at runtime via omp's extension loader.

Part 2/5 of the omp adapter rollout."
```

---

## Task 3: Installer with TDD coverage

**Files:**
- Modify: `tests/omp.bats` (append installer tests)
- Create: `adapters/omp.sh`

- [ ] **Step 1: Append failing installer tests to `tests/omp.bats`**

Add these blocks after the IDE-detection tests already in `tests/omp.bats`. They use a separate `setup_installer_env` helper because the installer tests need a clean `HOME` and mocked `curl`, while the IDE tests need the full `setup_test_env` mock world. The two test groups must not share `setup`/`teardown`; we accomplish this by using bats' per-test `setup` only for the IDE tests above and explicit `setup_installer_env` calls inside each installer test.

```bash
# ============================================================
# Installer
# ============================================================

setup_installer_env() {
  # Reset any state from the IDE-detection group that might still be set
  unset CLAUDE_PEON_DIR PEON_TEST TEST_DIR

  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"

  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  OMP_SH="$REPO_ROOT/adapters/omp.sh"

  unset XDG_CONFIG_HOME
  EXT_DIR="$TEST_HOME/.omp/agent/extensions/peon-ping"

  # Mock peon.sh — satisfies preflight check
  mkdir -p "$TEST_HOME/.claude/hooks/peon-ping"
  cat > "$TEST_HOME/.claude/hooks/peon-ping/peon.sh" <<'SCRIPT'
#!/bin/bash
exit 0
SCRIPT
  chmod +x "$TEST_HOME/.claude/hooks/peon-ping/peon.sh"

  # Mock bin directory
  MOCK_BIN_INSTALLER="$(mktemp -d)"

  # Mock curl — return canned content for adapter URLs
  cat > "$MOCK_BIN_INSTALLER/curl" <<'MOCK_CURL'
#!/bin/bash
url=""
output=""
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  case "${args[$i]}" in
    -o) output="${args[$((i+1))]}" ;;
    http*) url="${args[$i]}" ;;
  esac
done

case "$url" in
  *adapters/omp/peon-ping.ts)
    [ -n "$output" ] && echo '// peon-ping adapter for oh-my-pi (omp)' > "$output"
    ;;
  *adapters/omp/package.json)
    [ -n "$output" ] && cat > "$output" <<'EOF'
{ "name": "peon-ping", "omp": { "extensions": ["./peon-ping.ts"] } }
EOF
    ;;
  *)
    [ -n "$output" ] && echo "mock" > "$output"
    ;;
esac
exit 0
MOCK_CURL
  chmod +x "$MOCK_BIN_INSTALLER/curl"

  export PATH="$MOCK_BIN_INSTALLER:$PATH"
}

teardown_installer_env() {
  rm -rf "$TEST_HOME" "$MOCK_BIN_INSTALLER" 2>/dev/null
}

@test "installer: script has valid bash syntax" {
  setup_installer_env
  run bash -n "$OMP_SH"
  [ "$status" -eq 0 ]
  teardown_installer_env
}

@test "installer: fails when peon.sh is not found" {
  setup_installer_env
  rm -f "$TEST_HOME/.claude/hooks/peon-ping/peon.sh"
  run bash "$OMP_SH"
  [ "$status" -ne 0 ]
  [[ "$output" == *"peon.sh not found"* ]]
  teardown_installer_env
}

@test "installer: fresh install writes extension files" {
  setup_installer_env
  run bash "$OMP_SH"
  [ "$status" -eq 0 ]
  [ -f "$EXT_DIR/peon-ping.ts" ]
  [ -f "$EXT_DIR/package.json" ]
  grep -q "peon-ping adapter for oh-my-pi" "$EXT_DIR/peon-ping.ts"
  grep -q "\"omp\"" "$EXT_DIR/package.json"
  teardown_installer_env
}

@test "installer: re-install is idempotent and overwrites stale content" {
  setup_installer_env
  bash "$OMP_SH"
  echo "// stale" > "$EXT_DIR/peon-ping.ts"
  bash "$OMP_SH"
  grep -q "peon-ping adapter for oh-my-pi" "$EXT_DIR/peon-ping.ts"
  teardown_installer_env
}

@test "installer: --uninstall removes extension directory" {
  setup_installer_env
  bash "$OMP_SH"
  [ -d "$EXT_DIR" ]
  run bash "$OMP_SH" --uninstall
  [ "$status" -eq 0 ]
  [ ! -d "$EXT_DIR" ]
  teardown_installer_env
}

@test "installer: PEON_PING_LOCAL_ADAPTER_DIR env var copies from local path instead of curl" {
  setup_installer_env
  # Pretend we're running from a checkout
  LOCAL_SRC="$(mktemp -d)"
  mkdir -p "$LOCAL_SRC/adapters/omp"
  echo '// local checkout content' > "$LOCAL_SRC/adapters/omp/peon-ping.ts"
  echo '{"name":"peon-ping","omp":{"extensions":["./peon-ping.ts"]}}' \
    > "$LOCAL_SRC/adapters/omp/package.json"
  # Break curl so we know it wasn't used
  cat > "$MOCK_BIN_INSTALLER/curl" <<'BREAK'
#!/bin/bash
exit 99
BREAK
  chmod +x "$MOCK_BIN_INSTALLER/curl"

  PEON_PING_LOCAL_ADAPTER_DIR="$LOCAL_SRC/adapters/omp" run bash "$OMP_SH"
  [ "$status" -eq 0 ]
  grep -q "local checkout content" "$EXT_DIR/peon-ping.ts"
  rm -rf "$LOCAL_SRC"
  teardown_installer_env
}
```

- [ ] **Step 2: Run the new tests and confirm all six fail (or error) cleanly**

Run: `bats tests/omp.bats`
Expected: the three IDE-detection tests from Task 1 still PASS; the six new installer tests FAIL because `adapters/omp.sh` does not exist yet (`bash: adapters/omp.sh: No such file or directory`).

- [ ] **Step 3: Implement `adapters/omp.sh`**

```bash
#!/bin/bash
# peon-ping adapter for oh-my-pi (omp)
# Installs the thin TypeScript adapter that routes events through peon.sh.
#
# Requires peon-ping installed first:
#   brew install PeonPing/tap/peon-ping
#   # or: curl -fsSL peonping.com/install | bash
#
# Install this adapter:
#   bash adapters/omp.sh
#
# Or directly:
#   curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp.sh | bash
#
# Uninstall:
#   bash adapters/omp.sh --uninstall

set -euo pipefail

ADAPTER_TS_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp/peon-ping.ts"
ADAPTER_PKG_URL="https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp/package.json"
OMP_EXT_DIR="$HOME/.omp/agent/extensions/peon-ping"
PEON_SH_CANDIDATES=(
  "$HOME/.claude/hooks/peon-ping/peon.sh"
  "$HOME/.openclaw/hooks/peon-ping/peon.sh"
)

BOLD=$'\033[1m' DIM=$'\033[2m' RED=$'\033[31m' GREEN=$'\033[32m' YELLOW=$'\033[33m' RESET=$'\033[0m'

info()  { printf "%s>%s %s\n" "$GREEN" "$RESET" "$*"; }
warn()  { printf "%s!%s %s\n" "$YELLOW" "$RESET" "$*"; }
error() { printf "%sx%s %s\n" "$RED" "$RESET" "$*" >&2; }

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
  if [ -d "$OMP_EXT_DIR" ]; then
    rm -rf "$OMP_EXT_DIR"
    info "Removed $OMP_EXT_DIR"
  else
    info "Nothing to uninstall (extension directory not present)."
  fi
  exit 0
fi

# --- Preflight: find peon.sh ---
PEON_SH=""
for candidate in "${PEON_SH_CANDIDATES[@]}"; do
  if [ -f "$candidate" ]; then
    PEON_SH="$candidate"
    break
  fi
done

if [ -z "$PEON_SH" ]; then
  error "peon.sh not found at any of:"
  for candidate in "${PEON_SH_CANDIDATES[@]}"; do
    error "  $candidate"
  done
  error ""
  error "Install peon-ping first:"
  error "  brew install PeonPing/tap/peon-ping"
  error "  # or: curl -fsSL peonping.com/install | bash"
  exit 1
fi

# --- Install adapter ---
info "Installing peon-ping adapter for oh-my-pi (omp)..."

mkdir -p "$OMP_EXT_DIR"
# Defensive: if a stale symlink lives where peon-ping.ts should be, rm it
rm -f "$OMP_EXT_DIR/peon-ping.ts" "$OMP_EXT_DIR/package.json"

if [ -n "${PEON_PING_LOCAL_ADAPTER_DIR:-}" ]; then
  # Test-only path: copy from a local checkout instead of downloading
  info "Using local adapter dir: $PEON_PING_LOCAL_ADAPTER_DIR"
  cp "$PEON_PING_LOCAL_ADAPTER_DIR/peon-ping.ts" "$OMP_EXT_DIR/peon-ping.ts"
  cp "$PEON_PING_LOCAL_ADAPTER_DIR/package.json" "$OMP_EXT_DIR/package.json"
else
  if ! command -v curl &>/dev/null; then
    error "curl is required but not found on PATH."
    exit 1
  fi
  info "Downloading adapter..."
  curl -fsSL "$ADAPTER_TS_URL" -o "$OMP_EXT_DIR/peon-ping.ts"
  curl -fsSL "$ADAPTER_PKG_URL" -o "$OMP_EXT_DIR/package.json"
fi

info "Adapter installed to $OMP_EXT_DIR/"

# --- Done ---
echo ""
info "${BOLD}peon-ping adapter installed for oh-my-pi (omp)!${RESET}"
echo ""
printf "  %sExtension:%s %s\n" "$DIM" "$RESET" "$OMP_EXT_DIR/peon-ping.ts"
printf "  %sManifest:%s  %s\n" "$DIM" "$RESET" "$OMP_EXT_DIR/package.json"
printf "  %speon.sh:%s   %s\n" "$DIM" "$RESET" "$PEON_SH"
echo ""
info "Restart omp to activate. All peon-ping features now available."
info "Configure: peon config | peon trainer on | peon packs list"
```

- [ ] **Step 4: Make the installer executable**

Run: `chmod +x adapters/omp.sh`
Expected: no output, exit 0.

- [ ] **Step 5: Re-run the installer tests and confirm all six pass**

Run: `bats tests/omp.bats`
Expected: all nine tests in `tests/omp.bats` PASS (3 IDE-detection + 6 installer).

- [ ] **Step 6: Commit**

```bash
git add adapters/omp.sh tests/omp.bats
git commit -m "feat(adapters): add omp (oh-my-pi) installer

bash adapters/omp.sh drops the extension into
~/.omp/agent/extensions/peon-ping/. Supports --uninstall and the
PEON_PING_LOCAL_ADAPTER_DIR env var for tests / local checkouts.

Part 3/5 of the omp adapter rollout."
```

---

## Task 4: README + docs updates

**Files:**
- Modify: `README.md`
- Modify: `README_zh.md`, `README_ko.md`, `README_ja.md`
- Modify: `docs/public/llms.txt`

This task is documentation. No automated tests; the verification is "the new section reads correctly and links resolve".

- [ ] **Step 1: Add omp badge to `README.md` adapter badges row (line 9)**

Locate the existing badge line at `README.md:9` (starts with `![Claude Code]`). Append the omp badge at the end before the trailing newline, between `![DeepAgents]…` and the line break:

```markdown
![DeepAgents](https://img.shields.io/badge/DeepAgents-adapter-ffab01) ![oh-my-pi](https://img.shields.io/badge/oh--my--pi-adapter-ffab01)
```

- [ ] **Step 2: Add omp row to the Multi-IDE Support table in `README.md`**

Locate the `## Multi-IDE Support` section table (table starts ~line 715). After the `**DeepAgents**` row (line ~730), insert:

```markdown
| **oh-my-pi (omp)** | Adapter | `bash adapters/omp.sh` ([setup](#oh-my-pi-omp-setup)) |
```

- [ ] **Step 3: Add the `### oh-my-pi (omp) setup` subsection in `README.md`**

After the existing `### DeepAgents setup` section (find the right anchor by searching for the next `### ` heading after DeepAgents), insert:

````markdown
### oh-my-pi (omp) setup

A native TypeScript extension for [oh-my-pi](https://github.com/can1357/oh-my-pi) (`omp`) with full [CESP v1.0](https://github.com/PeonPing/openpeon) conformance. Subscribes to omp's `ExtensionAPI` lifecycle events and routes them through `peon.sh` so omp users get every peon-ping feature: sound packs, desktop notifications, trainer reminders, mobile push, SSH/devcontainer relay, and tab-title updates.

**Quick install:**

```bash
curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp.sh | bash
```

The installer copies `peon-ping.ts` and `package.json` to `~/.omp/agent/extensions/peon-ping/`. Restart omp afterward.

**Event mapping:**

| omp event                              | peon-ping event       |
|----------------------------------------|-----------------------|
| `session_start`                        | `SessionStart`        |
| `turn_start`                           | `UserPromptSubmit`    |
| `turn_end`                             | `Stop`                |
| `tool_result` with `isError: true`     | `PostToolUseFailure`  |
| `auto_compaction_start`                | `PreCompact`          |
| `session_shutdown`                     | `SessionEnd`          |

**Uninstall:**

```bash
bash ~/.claude/hooks/peon-ping/adapters/omp.sh --uninstall
```
````

- [ ] **Step 4: Mirror Steps 1-3 into `README_zh.md`, `README_ko.md`, `README_ja.md`**

Each translation file has the same overall structure (badges row, Multi-IDE Support section, per-IDE setup subsections). Apply equivalent additions in the corresponding language. The Chinese, Korean, and Japanese translations should follow the same idiomatic phrasing used by the existing OpenCode and DeepAgents sections in each file — match the surrounding voice, do not machine-translate without checking the existing tone.

For each translation:
1. Add the same `![oh-my-pi]` badge to the badges row (badge text stays English; this matches existing badges).
2. Add the same Multi-IDE Support table row, translating only the column-3 phrase (`Adapter` and the install command stay English; only the trailing `[setup]` link text translates).
3. Translate the prose of the `### oh-my-pi (omp) setup` section, preserving code blocks and the event-mapping table verbatim.

For the actual translated prose, use the same phrasing the existing `### OpenCode setup` section uses in each language file — adapt that to omp by substituting the project name and event mapping.

- [ ] **Step 5: Update `docs/public/llms.txt`**

Open `docs/public/llms.txt` and locate the adapter list (search for `opencode` or `kilo` to find the relevant section). Append an omp entry consistent with the existing format. Read the file first; if it already has a structured "Supported IDEs" / "Adapters" list, append; if it's prose-only, add a sentence like:

```
- oh-my-pi (omp): TypeScript extension at adapters/omp/peon-ping.ts; install with `bash adapters/omp.sh`. Maps omp ExtensionAPI events (session_start, turn_start, turn_end, tool_result, auto_compaction_start, session_shutdown) to CESP via source: "omp".
```

- [ ] **Step 6: Visually verify all four READMEs render correctly**

Run: `grep -l "oh-my-pi" README.md README_zh.md README_ko.md README_ja.md`
Expected: all four filenames listed.

Run: `grep -c "oh-my-pi" README.md`
Expected: ≥ 3 (badge, table row, section heading).

- [ ] **Step 7: Commit**

```bash
git add README.md README_zh.md README_ko.md README_ja.md docs/public/llms.txt
git commit -m "docs: announce omp (oh-my-pi) adapter

Adds badge, Multi-IDE Support table row, and setup subsection to all
README variants (en/zh/ko/ja) plus the llms.txt context file.

Part 4/5 of the omp adapter rollout."
```

---

## Task 5: CHANGELOG entry

**Files:**
- Modify: `CHANGELOG.md`

This task records the change in the unreleased section so the next release picks it up. **Do not bump VERSION** — that happens at release time, not in this PR (per peon-ping's `RELEASING.md`).

- [ ] **Step 1: Inspect the current top of `CHANGELOG.md`**

Run: `head -3 CHANGELOG.md`
Expected output starts with `## v2.27.0 (2026-05-05)` (or a newer released version) — i.e. there is currently no `[Unreleased]` section.

- [ ] **Step 2: Insert an `[Unreleased]` section at the very top of `CHANGELOG.md`**

Prepend (use an editor or `edit` tool — the new content goes before line 1):

```markdown
## [Unreleased]

### Added
- **oh-my-pi (omp) adapter.** New TypeScript extension at `adapters/omp/peon-ping.ts` plus shell installer at `adapters/omp.sh` route omp's `ExtensionAPI` lifecycle events (`session_start`, `turn_start`, `turn_end`, `tool_result` with `isError`, `auto_compaction_start`, `session_shutdown`) through `peon.sh` so omp users get every peon-ping feature: packs, desktop notifications, trainer, mobile push, SSH/devcontainer relay, tab titles. `peon.sh` recognizes `source: "omp"` (and `omp-…` session-id-prefix fallback) and renders as `oh-my-pi` in notifications. Install with `bash adapters/omp.sh`.

```

(Leave a blank line between the new `[Unreleased]` section and the existing `## v2.27.0 …` heading.)

- [ ] **Step 3: Verify the diff looks right**

Run: `git diff CHANGELOG.md | head -20`
Expected: the diff shows only an addition at the top, no edits to the existing `## v2.27.0` block.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): add [Unreleased] entry for omp adapter

Part 5/5 of the omp adapter rollout. VERSION bump deferred to release
time per RELEASING.md."
```

---

## Final verification

After all five tasks land:

- [ ] **Run the full BATS suite**

Run: `bats tests/`
Expected: all tests PASS, including the new `tests/omp.bats`. Note: peon-ping CI runs only `bats tests/` on macOS and `Pester` on Windows — there is no TypeScript test job, so the adapter's TS file is verified manually via `bun build` (Task 2 Step 3).

- [ ] **Confirm all five commits are present and ordered**

Run: `git log --oneline -8`
Expected: the bottom of the log shows 5 commits in order:
1. `feat(adapters): recognize 'omp' source in peon.sh IDE tables`
2. `feat(adapters): add omp (oh-my-pi) ExtensionAPI extension`
3. `feat(adapters): add omp (oh-my-pi) installer`
4. `docs: announce omp (oh-my-pi) adapter`
5. `docs(changelog): add [Unreleased] entry for omp adapter`

(The earlier `docs: add omp (oh-my-pi) adapter design` commit is already on the branch from the brainstorming phase.)

- [ ] **Sanity-check the cross-repo TODOs that this plan does NOT do**

Per `CLAUDE.md`'s "If you add a new IDE adapter" rule, the following live in *other* repos and must be done at release time, not as part of this PR:
- `../homebrew-tap/Formula/peon-ping.rb` — verify whether the formula needs an `omp` mention; Phase 4's hook list and detection block are the relevant areas. For an installer-only adapter (no shell hook to register), no formula edit is typically needed.
- `../peonping-x-bot/workspace/SOUL.md` — bump the supported-tools count.
- `VERSION` — minor bump (e.g. `2.28.0`).

Document these as release-time TODOs in the PR description; do not silently include them.

---

## Self-Review

**1. Spec coverage check:**

| Spec section                              | Plan task                                        |
|-------------------------------------------|--------------------------------------------------|
| `adapters/omp/peon-ping.ts` (extension)   | Task 2 Step 1                                    |
| `adapters/omp/package.json` (manifest)    | Task 2 Step 2                                    |
| `adapters/omp.sh` (installer)             | Task 3 Step 3                                    |
| `peon.sh` IDE_ALIASES + DISPLAY + prefix  | Task 1 Steps 3-5                                 |
| README en/zh/ko/ja                        | Task 4 Steps 1-4                                 |
| `docs/public/llms.txt`                    | Task 4 Step 5                                    |
| BATS tests (3 IDE + 3 installer per spec) | Task 1 Step 1 (3 IDE) + Task 3 Step 1 (6 installer — one extra over spec, covering `--uninstall` and bash-syntax) |
| CHANGELOG `[Unreleased]`                  | Task 5                                           |
| `VERSION` bump (release-time)             | Final verification step explicitly defers        |
| Cross-repo (homebrew-tap, SOUL.md)        | Final verification step explicitly defers        |
| Event mapping (6 events)                  | Task 2 Step 1 code includes all 6 handlers       |
| Type-only `ExtensionAPI` import           | Task 2 Step 1 code uses `import type`            |
| `ctx.hasUI` guard on tab title            | Task 2 Step 1 code guards 3 of 4 setTabTitle calls (auto_compaction and session_shutdown don't write the title at all) |
| Initial `setTimeout` (DROPPED in design)  | Plan correctly omits — design was amended        |

No spec gap.

**2. Placeholder scan:** searched the plan for `TBD`, `TODO`, `implement later`, `add appropriate error handling`, `fill in details`, `Similar to Task N`. None found. The translation step (Task 4 Step 4) is explicit about *what* to translate (the prose) and *what to keep verbatim* (code blocks and event mapping table), so it's not a placeholder; it's a deliberate human-judgment delegation.

**3. Type/name consistency:**
- Symbol `peonPingExtension` (Task 2 Step 1) — internal-only, never referenced from another task. OK.
- `ExtensionAPI` from `@oh-my-pi/pi-coding-agent` — used consistently.
- Env var `PEON_PING_LOCAL_ADAPTER_DIR` — defined in Task 3 Step 1 (test) and consumed in Task 3 Step 3 (installer); names match.
- Path `~/.omp/agent/extensions/peon-ping/` — used identically in design, installer code (`OMP_EXT_DIR`), test (`EXT_DIR`), and README copy.
- File names: `peon-ping.ts` and `package.json` — used identically across all references.
- `firePeon`, `findPeonSh`, `setTabTitle` — defined in Task 2 Step 1 only; not referenced elsewhere.
- BATS helper names (`setup_test_env`, `run_peon`, `setup_installer_env`, `teardown_installer_env`) — `setup_test_env` and `run_peon` are existing repo helpers (verified in `tests/setup.bash`); `setup_installer_env`/`teardown_installer_env` are new and defined within `tests/omp.bats` itself.

No inconsistencies.
