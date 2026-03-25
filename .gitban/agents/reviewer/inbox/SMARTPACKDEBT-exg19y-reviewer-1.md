---
verdict: APPROVAL
card_id: exg19y
review_number: 1
commit: 4126d41152221fd6db1a3fadb6fbf2e4b2c99024
date: 2026-03-15
has_backlog_items: true
---

## Summary

Card exg19y addresses two edge cases in the Windows PowerShell state management code flagged during the SMARTPACK sprint review:

1. **L1 -- PS 7+ atomic overwrite in `Write-StateAtomic`**: Adds a `$PSVersionTable.PSVersion.Major -ge 7` branch that uses `Move-Item -Force` for a truly atomic overwrite with no delete gap. The PS 5.1 delete-then-move fallback is preserved in the else branch.

2. **L2 -- Orphaned `.tmp` cleanup in `Read-StateWithRetry`**: Adds a cleanup block at the top of `Read-StateWithRetry` that scans for `$base.*.tmp` files and removes them. This guards against partial writes left behind when the safety timer fires `[Environment]::Exit(1)`.

The source commit is `b31ed71` (35 lines, 3 files). It was merged into the sprint branch via `4126d41`, a merge commit that also incorporated the inexon card. All exg19y changes survived the merge intact.

## Assessment

**L1 -- Write-StateAtomic PS version branch**: Correct implementation. `Move-Item -Force` on PS 7+ is the right call -- it delegates to `System.IO.File.Move(src, dst, overwrite: true)` in .NET Core, which is a single rename syscall on NTFS. The PS 5.1 fallback preserves the existing behavior with a clear comment documenting the sub-millisecond gap. The version check is clean and standard.

**L2 -- Orphaned `.tmp` cleanup**: The glob pattern `$base.*.tmp` correctly matches PID-scoped temp files (`$Path.$PID.tmp`) without being overly broad. The cleanup runs at startup before the retry loop, which is the right sequencing. `SilentlyContinue` on both the Get-ChildItem and Remove-Item is appropriate since the cleanup is best-effort.

**Tests**: Three new Pester tests verify the PS 7+ branch exists, the PS 5.1 fallback is preserved, and the `.tmp` cleanup logic is present. These are static content tests (regex matching against the embedded hook script), which is consistent with the existing test patterns in this file. They verify the structural presence of the code paths but not runtime behavior.

**Checkbox integrity**: All four acceptance criteria boxes are checked and truthful:
- L1 PS version check: present at line 794
- L2 .tmp cleanup: present at lines 809-816
- Pester tests pass: card claims 207/207 (note: the merge commit log shows 222, which includes the inexon card's additions)
- PS 5.1 path preserved: delete-then-move retained in the else branch at lines 799-800

## BLOCKERS

None.

## BACKLOG

**L1**: The static Pester tests verify code structure but not runtime behavior. A functional test that actually creates a `.tmp` file and verifies `Read-StateWithRetry` removes it would add meaningful coverage. This is consistent with the existing test style in this codebase (most Pester tests are structural), so it is not a blocker, but worth noting for the state helper DRY-up card (lyq5ta) which could introduce proper integration tests for state I/O.
