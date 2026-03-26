# Smoke Test: HOOKLOG on Windows 10

## Task Overview

* **Task Description:** Manual smoke test of the full debug logging flow (v2.17.0 / HOOKLOG sprint) on a real Windows 10 machine before merging PR #405.
* **Motivation:** CI validates syntax and patterns, but can't test the actual end-to-end hook flow — real events, real audio, real log files. Need to verify on the target platform before merge.
* **Scope:** Debug toggle, log generation from live hooks, log filtering, suppression logging, rotation, env var override, verbose status output.
* **Related Work:** PR #405 (sprint/HOOKLOG), ADR-002, v2/m4 roadmap milestone.

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
|:-----|:---------------|:---------------:|
| **1. Setup** | Install from sprint/HOOKLOG, verify version | - [x] Done |
| **2. Debug toggle** | on/off/status cycle | - [x] Done |
| **3. Log generation** | Live hook events produce structured logs | - [x] Done |
| **4. Log filtering** | --last N and --session work | - [x] Done |
| **5. Suppression logging** | Muted events log reason | - [x] Done (with finding) |
| **6. Rotation/cleanup** | --prune, --clear, daily naming | - [x] Done (with finding) |
| **7. Env var override** | PEON_DEBUG=1 works with debug=false | - [x] Done |
| **8. Verbose status** | Default concise, --verbose full | - [x] Done (with finding) |

### Setup

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 0 | `powershell -File install.ps1` from sprint/HOOKLOG | Updated peon.ps1 deployed | - [x] Done — "peon-ping updated!", 10 packs cached, 225 sounds, hooks registered. Minor `Invalid parameter "(RX)"` warning (non-blocking). |
| 1 | `peon --status` | Shows version 2.17.0 | - [x] **ISSUE:** No version shown in default or verbose output. Default shows pack/volume/count. Verbose adds notifications, headphones, path rules — but no version line and no debug state line. Unix (`peon.sh`) has both. Windows `--status` handler (install.ps1:593-668) is missing them. |
| 2 | `peon debug status` | Reports disabled, shows log dir path | - [x] Done — "debug disabled", log dir shown, 0 files/0 bytes. |

### 1. Debug toggle

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 1 | `peon debug on` | Reports debug enabled | - [x] Done |
| 2 | `peon debug status` | Shows enabled, log dir, 0 files | - [x] Done |
| 3 | `peon debug off` | Reports debug disabled | - [x] Done |
| 4 | `peon debug status` | Shows disabled | - [x] Done |

### 2. Log generation from live hooks

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 1 | `peon debug on` | Enabled | - [x] Done |
| 2 | Start Claude Code, trigger a few events (chat, tool use, stop) | Hooks fire, sounds play normally | - [x] Done — 5 invocations captured (Stop, SessionStart, Stop, Stop, Notification) |
| 3 | `peon logs` | Structured log with phases: [hook], [config], [state], [route], [sound], [play], [exit] | - [x] Done — all 9 phases present. Notification-only event correctly omits [route]/[sound]/[play]. |
| 4 | Check `inv=` IDs | Consistent 4-char hex within each invocation | - [x] Done — 9afe, fd0b, d498, 91f1, 10c0, all unique and consistent. |
| 5 | Check `duration_ms` in [exit] lines | Non-zero, plausible values | - [x] Done — 493ms, 984ms, 621ms, 502ms, 409ms. |

### 3. Log filtering

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 1 | `peon logs --last 10` | Exactly 10 most recent lines | - [x] Done — 10 lines returned, most recent entries |
| 2 | Copy a session ID from output | Have a real session ID | - [x] Done — 664fab4c-856a-460c-9aca-ae4a01eeacdb |
| 3 | `peon logs --session <ID>` | Only entries for that session | - [x] Done — returned 2 matching lines (SessionStart + Stop). Note: only matches [hook] lines containing `session=`, not all phases for those invocations. |

### 4. Suppression logging

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 1 | `peon --pause` | Muted | - [x] Done |
| 2 | Trigger a hook event | Hook fires, sound suppressed | - [x] Done — started and exited a Claude Code session while paused |
| 3 | `peon logs` | [route] with `suppressed=True` and reason | - [x] **ISSUE:** No log entries generated while paused. The `enabled` check (install.ps1:1683) exits before logging infra is initialized (line 1685+). The `[hook]` line hardcodes `paused=False`. Paused events are invisible to the log. |
| 4 | `peon --resume` | Unmuted | - [x] Done |

### 5. Log rotation and cleanup

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 1 | Check log dir | File named `peon-ping-YYYY-MM-DD.log` | - [x] Done — `peon-ping-2026-03-26.log` (23,772 bytes) |
| 2 | `peon logs --prune` | Reports pruning | - [x] **ISSUE:** `--prune` not implemented on Windows. Prints usage. Only exists in peon.sh. |
| 3 | `peon logs --clear` | Deletes all log files | - [x] Done — "cleared 1 log file(s)" |
| 4 | `peon debug status` | Shows 0 files | - [x] Done — shows 1 file / 867 bytes (new log created by this session's hooks after clear). Correct behavior. |

### 6. PEON_DEBUG env var override

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 1 | `peon debug off` | Disabled | - [x] Done |
| 2 | Set `$env:PEON_DEBUG = "1"`, trigger a hook | Log file created despite debug=false | - [x] Done — config says "debug disabled" but log grew to 2.3 KB. Override works. |
| 3 | Unset env var, trigger another hook | No new log entries | - [x] Done — started/stopped Claude after removing env var. Last 3 log lines still from PEON_DEBUG=1 session (inv=eef6). No new entries written. |

### 7. Verbose status output

| Step | Action | Expected | Status/Details |
|:-----|:-------|:---------|:--------------:|
| 1 | `peon --status` | Concise — no debug/headphones/path rules lines | - [x] Done — 3 lines: state/pack/volume, pack count, verbose hint. |
| 2 | `peon --status --verbose` | Full output including debug state | - [x] **PARTIAL:** Shows notifications, headphones, path rules. Missing version and debug state lines (see Setup step 1 finding). |

---

## Completion & Follow-up

| Task | Detail/Link |
|:-----|:------------|
| **Changes Made** | N/A — testing only |
| **Pull Request** | PR #405 |
| **Testing Performed** | All scenarios above |

### Verdict

- [x] **PASS** — merge PR #405. Core logging works end-to-end. Three minor parity gaps found, none are blockers.
- [x] **FAIL** — N/A, verdict is PASS. Three minor parity gaps tracked as cards r0qoai, ki3aim, oln59n.

### Findings

| Finding | Severity | Action |
|:--------|:---------|:-------|
| `peon --status` missing version and debug state lines (both default and verbose) | Low | Follow-up card: add version + debug state to Windows status handler |
| Paused hooks exit before logging initializes — invisible to debug log | Low | Follow-up card: emit `[hook] paused=True` + `[exit]` before early exit |
| `peon logs --prune` not implemented on Windows | Low | Follow-up card: port from peon.sh |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
|:------|:------------------------|
| **Issues Found?** | 3 minor parity gaps (see Findings above) |
| **Follow-up Work Required?** | Yes — 3 follow-up cards for Windows parity fixes |
