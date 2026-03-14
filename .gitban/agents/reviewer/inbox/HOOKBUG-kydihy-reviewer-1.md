---
verdict: APPROVAL
card_id: kydihy
review_number: 1
commit: 5ed2ca7
date: 2026-03-14
has_backlog_items: true
---

## Summary

This card implements Phase 2 of ADR-001: atomic state writes and retry-on-read for `.state.json` on both Windows (PowerShell) and Unix (Python). The implementation replaces all raw `json.dump(state, open(..., 'w'))` calls in `peon.sh` (6 in the main Python block, 2 in trainer blocks) and both `Set-Content $StatePath` calls in `install.ps1` with atomic temp-file-then-rename helpers. Retry-on-read with 50/100/200ms backoff is added on both platforms with graceful fallback to empty defaults.

The diff also includes Phase 1 changes (async audio delegation, MediaPlayer removal, 8-second self-timeout) which were approved in a prior review for card d5wz2f, plus the `active_pack` to `default_pack` config rename from card aodz7v. This review focuses on the Phase 2 atomic state work specific to card kydihy.

## Assessment

**ADR Compliance**: The implementation faithfully follows ADR-001 Phase 2. Python uses `tempfile.mkstemp()` + `os.replace()` (atomic on POSIX). PowerShell uses `$Path.$PID.tmp` + `[System.IO.File]::Delete()` + `[System.IO.File]::Move()` with a documented comment explaining why the two-step delete+move is needed for PS 5.1 compatibility (3-param Move with overwrite requires .NET Core/PS 7+).

**Correctness**:

- `write_state()` / `Write-StateAtomic` both write to a temp file in the same directory as the target (required for atomic rename on both POSIX and NTFS), then rename. Failure paths clean up the temp file. The `raise` after cleanup in Python is correct -- callers wrap in `try/except` or `try {}catch{}` and continue.

- `read_state()` / `Read-StateWithRetry` retry 3 times with backoff on any exception, then return empty defaults. The broad `except Exception` catch is appropriate here -- the contention scenario involves partial reads, corrupt JSON, and locked files, all of which are different exception types.

- The PowerShell delete+move sequence has a theoretical race window (another process could write between the delete and the move), but this is the same pattern used by the PowerShell ecosystem for PS 5.1 compatibility. The ADR documents this tradeoff, and the retry-on-read provides the safety net.

**TDD**: Two new BATS tests cover the critical behaviors: corrupted state recovery (verifies the hook produces sound and writes valid JSON afterward) and concurrent Stop event safety (fires 5 parallel events and asserts valid JSON state). The Pester test update (`5ed2ca7`) correctly changes the assertion from `ConvertTo-Json.*Set-Content $StatePath` to `Write-StateAtomic` to match the refactored code.

**DRY**: The `_write_state`/`_read_state` helpers are duplicated across three separate Python blocks (main hook, trainer status, trainer log). The card's work summary documents this is intentional -- the trainer commands are separate `python3 -c` invocations with no shared module scope. The functions are small (15 lines each) and identical. While this is technically tripled code, the architectural constraint (inline Python in a shell script with no importable module) makes this the least-bad option. A shared Python module would add install complexity for a CLI tool that currently has zero Python dependencies. This belongs in backlog, not as a blocker.

**Security**: No new attack surface. Temp files use `mkstemp` (secure on POSIX) and PID-based naming on Windows. No secrets exposed. State files contain only internal runtime data (timestamps, sound indices, session IDs).

**Documentation**: The card correctly marks documentation as internal-only. No user-facing behavior changes -- the atomic writes are invisible to users. ADR-001 Phase 2 section covers the design rationale.

**Checkbox Integrity**: The two unchecked acceptance criteria ("All existing Pester tests pass" and "All existing BATS tests pass") are appropriately unchecked -- the card notes these require CI runners not available in the worktree environment. The TDD section similarly has unchecked "Full Regression Suite" and "Performance Testing" boxes with honest status notes. No checked boxes are misleading.

## BACKLOG

**L1**: The three copies of `_write_state`/`_read_state` in `peon.sh` (lines 2586, 2671, 2865) are identical. If the retry delays, temp file strategy, or error handling ever need to change, all three must be updated in sync. Consider extracting a shared Python snippet file that gets inlined during install (similar to how the embedded peon.ps1 works in install.ps1), or refactoring the trainer commands to share the main Python block's helpers via a different execution model.

**L2**: `read_state()` retries on `FileNotFoundError` (file does not exist), adding up to 350ms of unnecessary delay on a clean first run when no `.state.json` exists yet. Consider checking `os.path.exists(path)` before the retry loop, or catching only `json.JSONDecodeError` and `IOError`/`PermissionError` in the retry path while letting `FileNotFoundError` fall through to return `{}` immediately. This is a minor performance concern -- first-run latency is dominated by PowerShell startup on Windows and is a one-time cost on Unix.
