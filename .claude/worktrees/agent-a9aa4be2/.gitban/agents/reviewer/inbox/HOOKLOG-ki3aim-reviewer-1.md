---
verdict: APPROVAL
card_id: ki3aim
review_number: 1
commit: 0fee5a7
date: 2026-03-26
has_backlog_items: false
---

## Summary

This card moves the `enabled` check in `install.ps1` to after logging infrastructure initialization, so that paused (muted) invocations emit structured log entries before exiting. Previously, `peon.ps1` exited at the enabled check before `$peonLog` was initialized, making paused invocations invisible in debug logs. This aligns Windows behavior with Unix (`peon.sh`), where paused invocations are always logged.

## Analysis

**Reorder of enabled check (install.ps1)**

The original `if (-not $config.enabled) { exit 0 }` at line ~1694 is replaced with a comment noting the move. The new paused block at line ~1752 fires after logging infrastructure is set up and emits three structured log entries: `[config]` with `enabled=False`, `[hook]` with `paused=True`, and `[exit]` with `reason=paused` plus `duration_ms`. This mirrors the Unix behavior where `peon.sh` logs the hook phase and route suppression before exiting.

The paused block correctly calls `Get-ActivePack` to populate the config log line, which is consistent with the normal (non-paused) config logging path below it.

The `$_isPaused` variable at the normal hook log line (line ~1809) will always evaluate to `'False'` at that point, since the early-exit above guarantees `$config.enabled` is truthy when execution reaches that line. This is technically dead logic -- it could simply be hardcoded `'False'` as before -- but the defensive derivation from `$config.enabled` is harmless and arguably more self-documenting if future refactoring removes the early exit. Not a blocker.

**Test coverage (hook-logging-windows.Tests.ps1)**

Six new Pester tests in a dedicated `Describe` block cover:
1. Log file creation when paused with `debug=true`
2. `[hook]` phase contains `paused=True`
3. `[exit]` phase contains `reason=paused`
4. `[config]` phase shows `enabled=False`
5. `[exit]` includes `duration_ms`
6. No `sound` or `play` phases are logged when paused

These tests define the contract (what log entries must appear and what must be absent) rather than testing implementation details. The tests use `New-PeonTestEnvironment -ConfigOverrides @{ debug = $true; enabled = $false }` which exercises the actual code path. The shared fixture test was updated from asserting "no log file" to asserting the correct log content, which is the correct behavior change.

The test structure is TDD-consistent: the tests specify observable behaviors (log line content, phase presence/absence) and cover both positive assertions (paused entries exist) and negative assertions (no sound/play phases). The card reports 35/35 tests passing.

**Parity with Unix**

On Unix, `peon.sh` logs `[hook] paused=True/False` and later `[route] suppressed=True reason=paused`. The Windows implementation logs `[hook] paused=True` and `[exit] reason=paused` -- slightly different structure (no separate `[route]` phase) but equivalent diagnostic value. The paused early-exit in Windows is structurally different from Unix (which continues through the Python block), so this is an appropriate platform-specific adaptation rather than a parity gap.

## BLOCKERS

None.

## FOLLOW-UP

None.

## Close-out

- All acceptance criteria checked boxes are truthful against the diff.
- No documentation updates required (internal logging behavior, no user-facing change).
- No new CLI commands, config keys, or CESP categories introduced.
