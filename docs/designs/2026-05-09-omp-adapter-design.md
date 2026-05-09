# omp (oh-my-pi) Adapter

**Date:** 2026-05-09
**Status:** Approved
**Type:** New Adapter + minor `peon.sh` wiring + docs

## Problem Statement

[oh-my-pi](https://github.com/can1357/oh-my-pi) (CLI binary `omp`) is a bun/TypeScript coding-agent CLI. peon-ping currently has no adapter for it, so omp users get no sound, notification, trainer, or relay support — even though every primitive peon-ping needs is already in place. The work is purely the adapter layer.

## Background

### How omp exposes lifecycle

omp ships an `ExtensionAPI` (and a deprecated-but-supported `HookAPI` superset) that fires typed lifecycle events. Extensions are `default`-exporting TS modules auto-discovered from:

1. `<cwd>/.omp/extensions/` (project scope)
2. `~/.omp/agent/extensions/` (user scope)
3. `~/.omp/plugins/node_modules/` (marketplace plugins)
4. `omp --extension <path>` / `omp --hook <path>` (CLI override)

A directory entry is resolved as `package.json` (with `omp.extensions` field) → `index.ts` → `index.js` → directory scan.

Relevant events for an audio adapter (full catalog: `docs/skills/authoring-hooks.md`):

| Event                              | Fires                                       |
|------------------------------------|---------------------------------------------|
| `session_start`                    | once on session load                        |
| `turn_start` / `turn_end`          | per user→agent turn                         |
| `tool_call` / `tool_result`        | wrapping every tool execution               |
| `auto_compaction_start`            | before automatic compaction                 |
| `session_shutdown`                 | on session close                            |

### How peon-ping accepts events

`peon.sh` reads JSON on stdin and dispatches on `hook_event_name` + `source`. Existing adapters (Codex, Cursor, OpenCode, Kilo, Kiro, Gemini, Copilot, Windsurf, Antigravity, Amp, DeepAgents, OpenClaw, Rovodev) all share the same shape: receive IDE events, translate, spawn `peon.sh` with a CESP-shaped payload.

`peon.sh` already has IDE-aware tables that need an `omp` entry to display correctly:
- `IDE_ALIASES` (line 4887) — normalizes `source` field strings
- `IDE_DISPLAY_NAMES` (line 4952) — human-readable label
- `prefix_map` inside `detect_session_ide` (line 4931) — fallback IDE detection from session-id prefix

### Closest precedent

`adapters/opencode/peon-ping.ts` is a thin TS plugin (~160 lines) that subscribes to OpenCode events and `spawn`s `peon.sh` with `{ hook_event_name, source: "opencode", session_id, cwd }`. The omp adapter follows the same shape, swapping the event surface.

## Proposed Solution

Add a thin omp extension that mirrors the OpenCode adapter, plus the small `peon.sh` table updates so the existing IDE-detection paths recognize `omp`.

### Architecture

```
omp session
  │
  │  omp ExtensionAPI events (session_start, turn_start, turn_end,
  │                            tool_result, auto_compaction_start,
  │                            session_shutdown)
  ▼
adapters/omp/peon-ping.ts
  │
  │  spawn("bash", [peon.sh]) with stdin =
  │    { hook_event_name, source: "omp", session_id: "omp-…",
  │      cwd, notification_type, permission_mode }
  ▼
peon.sh  →  IDE_ALIASES["omp"] → "omp"
         →  IDE_DISPLAY_NAMES["omp"] → "oh-my-pi"
         →  existing routing: sounds, notifications, trainer, relay
```

The adapter does **no** event-translation logic that peon-ping doesn't already do for other IDEs. It is purely a transport.

## Implementation Plan

### 1. New files

#### `adapters/omp/peon-ping.ts` (the extension)

Default-exports an `ExtensionAPI` factory. On load:

1. Locate `peon.sh` from the same candidate paths as the OpenCode adapter:
   - `~/.claude/hooks/peon-ping/peon.sh`
   - `~/.openclaw/hooks/peon-ping/peon.sh`
2. If not found, log a one-line warning with install instructions and return without registering handlers.
3. Generate `sessionId = "omp-" + Date.now()` so `peon.sh`'s prefix-based IDE detection fires correctly even if `source` somehow gets dropped.
4. Register handlers:

| omp event                                    | `hook_event_name` fired |
|----------------------------------------------|--------------------------|
| `session_start`                              | `SessionStart`           |
| `turn_start`                                 | `UserPromptSubmit`       |
| `turn_end`                                   | `Stop`                   |
| `tool_result` with `event.isError === true`  | `PostToolUseFailure`     |
| `auto_compaction_start`                      | `PreCompact`             |
| `session_shutdown`                           | `SessionEnd`             |

Unlike the OpenCode adapter (which fires an extra `setTimeout`-delayed `SessionStart` because OpenCode's `session.created` event fires before the plugin can subscribe), omp's documented lifecycle delivers `session_start` *after* all extensions load — registering the handler synchronously during the factory call is sufficient. No initial-fire timeout.

5. `firePeon(event)` shape (identical to the OpenCode adapter):

```ts
const proc = spawn("bash", [peonSh], { stdio: ["pipe", "ignore", "ignore"] });
proc.stdin.write(JSON.stringify({
  hook_event_name: event,
  notification_type: "",
  cwd,
  session_id: sessionId,
  permission_mode: "",
  source: "omp",
}));
proc.stdin.end();
proc.unref();
```

6. Use only `node:*` modules + the omp `ExtensionAPI` type — no third-party deps. Tab title is set via OSC-0 `\x1b]0;…\x07`, guarded on `ctx.hasUI` so headless/subagent runs don't paint over each other's TTY.

**Imports:**

```ts
import * as fs from "node:fs"
import * as path from "node:path"
import * as os from "node:os"
import { spawn } from "node:child_process"
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent"
```

The `ExtensionAPI` type is imported `type`-only, so the file resolves without that package being installed at runtime — omp itself supplies the value at extension-load time.

#### `adapters/omp/package.json` (the manifest)

Directory-style omp extensions need a `package.json` with the `omp.extensions` field so omp's directory loader picks the entry point reliably (per `docs/skills/authoring-extensions.md`):

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

This also lets us ship the adapter as a marketplace plugin later without restructuring.

#### `adapters/omp.sh` (the installer)

Same shape as `adapters/opencode.sh`:

1. Preflight: locate `peon.sh` (candidates above); fail with install instructions if missing.
2. Create `~/.omp/agent/extensions/peon-ping/`.
3. Download `peon-ping.ts` and `package.json` from `raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/omp/…`.
4. Print success block with paths and "Restart omp to activate".
5. `--uninstall` flag removes the extension directory.

No PowerShell installer for v1 (see Non-Goals).

### 2. `peon.sh` table updates

Three small additions in the IDE-resolution block (lines 4887–4967):

```python
IDE_ALIASES = {
    # ...existing entries...
    'omp': 'omp',
    'oh-my-pi': 'omp',
    'oh_my_pi': 'omp',
    'pi': 'omp',
}

# inside detect_session_ide, prefix_map tuple:
('omp-', 'omp'),

IDE_DISPLAY_NAMES = {
    # ...existing entries...
    'omp': 'oh-my-pi',
}
```

These three edits are the entire `peon.sh` change.

### 3. README + docs

- `README.md` — add omp badge in the badges row, add `omp` row to the Multi-IDE support section, point users at `bash adapters/omp.sh` (or `curl …/adapters/omp.sh | bash`).
- `README_zh.md`, `README_ko.md`, `README_ja.md` — equivalent translations.
- `docs/public/llms.txt` — add omp adapter line.
- `CLAUDE.md`-mandated cross-repo updates (see "Change Enforcement Rules" at the top of `CLAUDE.md`):
  - `../homebrew-tap/Formula/peon-ping.rb` — only if a phase needs to detect omp; for an installer-only adapter no formula change is needed. Verify before claiming this is done.
  - `../peonping-x-bot/workspace/SOUL.md` — bump supported-tools count.
  - Version bump: minor (new adapter).

### 4. Tests

#### `tests/omp.bats` — installer + IDE-table tests

- Installer: with mocked `HOME` and a stubbed `curl` (or `PEON_PING_LOCAL_ADAPTER_DIR` env var pointing at the working tree's `adapters/omp/`), `bash adapters/omp.sh` writes `peon-ping.ts` and `package.json` into `<HOME>/.omp/agent/extensions/peon-ping/`; second run is idempotent; `--uninstall` removes the directory.
- IDE detection: pipe `{"hook_event_name":"Stop","source":"omp","session_id":"omp-123","cwd":"/tmp"}` through `peon.sh` against a mocked manifest; assert that the resolved IDE in logs/state is `omp` and the display name is `oh-my-pi`.
- Session-id-prefix fallback: pipe the same event with `source: ""` (empty) but `session_id: "omp-456"`; assert IDE still resolves to `omp` via the prefix table.

#### `adapters/omp/peon-ping.ts` runtime smoke test

Out-of-scope for the BATS suite (peon-ping CI doesn't run TS), but the file must:
- Compile cleanly with `bun build --target=node` (manual verification step in PR).
- Match the type contract documented in `docs/skills/authoring-extensions.md`.

### 5. Things explicitly **not** in scope (YAGNI)

- **Windows-native `omp.ps1`.** omp on Windows runs through bun, which calls into the same `bash` `peon.sh` if it's on `PATH`. A real PowerShell installer can be added when a user reports needing it.
- **Permission-prompt mapping (`PermissionRequest`).** omp's `tool_call` blocking is a hook-author surface, not a user-facing permission UI. There is no clean signal to fire `PermissionRequest`; defer until omp exposes one.
- **Subagent suppression beyond the existing `suppress_delegate_sessions` config.** omp's subagent surface is `ctx.hasUI === false`; we can use that to skip tab-title writes, but we don't try to invent a per-session suppression scheme. Users who care set `suppress_delegate_sessions: true`.
- **Branch / tree / TTSR events.** Out of scope for an audio adapter.
- **A `--local` flag for the installer that copies from a checkout instead of downloading.** Other adapter installers don't have one; tests instead use the `PEON_PING_LOCAL_ADAPTER_DIR` test-only env var (set in the BATS harness only) to redirect the source. No production user-visible flag.

## Testing Strategy

### Automated (BATS)

Three new tests under `tests/omp.bats`:

1. **Installer happy path**: empty `~/.omp/`, run installer, assert files exist with expected contents (use `grep` for the `omp.extensions` field and `source: "omp"` literal).
2. **IDE alias + display**: drive `peon.sh` with a synthetic stdin event, assert log contains `ide=omp` and (where exposed) display `oh-my-pi`.
3. **Session-id prefix fallback**: as above with empty `source`, assert IDE still resolves to `omp`.

### Manual

- `bun build --target=node adapters/omp/peon-ping.ts` succeeds (verifies type compatibility with `@oh-my-pi/pi-coding-agent` ExtensionAPI).
- Drop the built file into `~/.omp/agent/extensions/peon-ping/peon-ping.ts`, start omp, send a prompt, hear the existing peon-ping pack play, check tab title updates.

### CI

GitHub Actions BATS job (`macos-latest`) will pick up `tests/omp.bats` automatically — no workflow changes.

## Files Changed

### New
- `adapters/omp/peon-ping.ts`
- `adapters/omp/package.json`
- `adapters/omp.sh`
- `tests/omp.bats`

### Modified
- `peon.sh` (3 small additions to IDE-resolution tables)
- `README.md` (badge + adapter row + install snippet)
- `README_zh.md`, `README_ko.md`, `README_ja.md` (translations)
- `docs/public/llms.txt` (adapter line)
- `CHANGELOG.md` (Unreleased / Added)
- `VERSION` (minor bump)
- `../peonping-x-bot/workspace/SOUL.md` (supported-tools count) — verify presence before editing

### Verified-not-modified
- `peon.ps1` (does not exist in this tree; CLAUDE.md mention appears stale)
- `../homebrew-tap/Formula/peon-ping.rb` (no formula change needed for an installer-only adapter; verify by re-reading the Phase 4 hook list before claiming done)

## Success Criteria

1. ✅ `bash adapters/omp.sh` installs the extension into `~/.omp/agent/extensions/peon-ping/` on a clean machine that has peon-ping already installed.
2. ✅ With the extension active, an omp session fires existing peon-ping sounds on session start, turn end, tool error, compaction, and session shutdown — verified manually.
3. ✅ `peon.sh` recognizes `source: "omp"` (and `omp-…` session-id fallback) and displays `oh-my-pi` as the IDE name.
4. ✅ All `tests/omp.bats` cases pass; existing tests remain green.
5. ✅ README badges + Multi-IDE matrix include omp, with translations updated.

## Open Questions / Risks

- **Type-only import resilience.** If omp's `@oh-my-pi/pi-coding-agent` ever moves the `ExtensionAPI` symbol, the adapter's `import type` will fail at install time. Mitigation: keep the adapter on the documented public type path; if it breaks, fall back to a structural type definition inline (no import) — same workaround Kilo uses for OpenCode.
- **`turn_start` vs. `before_agent_start`.** Both fire near the start of a turn. Approved mapping uses `turn_start` because it's the documented stable surface; `before_agent_start` is more about message injection. If field testing shows `turn_start` fires too eagerly (e.g., on continuations after compaction), we can switch — single-line change, no schema impact.
- **Tab-title contention.** Writing OSC-0 from a backgrounded extension while omp itself owns the TTY can flicker. Adapter writes are guarded on `ctx.hasUI` so headless / subagent runs don't compete for the TTY; the interactive case has been stable in practice for the OpenCode adapter using the same approach.

## References

- omp extension authoring: `../oh-my-pi/docs/skills/authoring-extensions.md`
- omp hook event catalog: `../oh-my-pi/docs/skills/authoring-hooks.md`
- omp extension loading: `../oh-my-pi/docs/extension-loading.md`
- Closest precedent: `adapters/opencode/peon-ping.ts`, `adapters/opencode.sh`
- peon.sh IDE-resolution tables: `peon.sh` lines 4887–4967
- CESP v1.0: https://github.com/PeonPing/openpeon
