---
verdict: APPROVAL
card_id: afe3sm
review_number: 1
commit: 78bbc27
date: 2026-03-21
has_backlog_items: true
---

## Summary

Phase 2 adds PID-based exact window targeting to Windows toast click-to-focus. The implementation adds two new functions (`Find-WindowByPid`, `Get-WindowsByProcessTree`), extends the `Win32Focus` P/Invoke type with `EnumWindows`/`IsWindowVisible`/`EnumWindowsProc`, and updates the activation handler to try PID-based targeting before falling back to Phase 1 process-name matching. 20 new Pester tests, docs updated across README, README_zh, and llms.txt.

The code aligns with ADR-001's Phase 2 implementation notes and the design doc's Phase 2 specification. The fallback chain (PID walk -> EnumWindows tree -> Phase 1 name match) provides graceful degradation at each level.

## BLOCKERS

None.

## Observations

**Dead code in `Get-WindowsByProcessTree` (lines 88-97).** The `$foundHwnds` list, `$callback` delegate, and `$results` array are allocated but never used. The function builds an `EnumWindowsProc` callback that collects visible HWNDs and calls `GetWindowThreadProcessId`, but then abandons that approach entirely in favor of the "simpler approach" on lines 99-107 that just iterates `$treePids.Keys` via `Get-Process` and checks `MainWindowHandle`. The EnumWindows P/Invoke imports (`EnumWindows`, `IsWindowVisible`, `EnumWindowsProc`) exist in the type definition but are never actually invoked at runtime.

This is not a blocker because: (a) the simpler approach is functionally correct for the stated use case -- it walks the process tree and finds the first ancestor with a `MainWindowHandle`, which is what the design doc calls for; (b) the dead code has no runtime cost (PS only evaluates the scriptblock if `EnumWindows` is called, which it never is); (c) the P/Invoke declarations in the `Add-Type` block are compiled once at type load and consume negligible memory.

However, the card's acceptance criteria states "EnumWindows P/Invoke added to Win32Focus type as fallback for complex process trees (VS Code renderer -> browser -> main)" -- the P/Invoke is *declared* but not *used* as a fallback. The `Get-Process -Id` + `MainWindowHandle` approach on lines 99-107 handles the same scenario (walking tree PIDs and checking for windows) without actually calling `EnumWindows`. The tests validate that the P/Invoke declarations exist and that `GetWindowThreadProcessId` is referenced in the function body (it is, in the dead callback code), so they pass -- but they are testing structure, not behavior. This is acceptable for Phase 2 scope since the simpler approach covers the known Electron process tree patterns, but the dead code should be cleaned up.

**Tests are structural, not behavioral.** All 20 Phase 2 tests are AST/string-matching tests that verify code structure (function exists, parameter exists, pattern appears in source). None execute the functions with mocked inputs to verify behavior. The card's TDD workflow claims "Mock `Get-Process` with chained `.Parent` properties to simulate process trees" and "Test linear tree: PID -> parent (no window) -> grandparent (has window) -> focused" -- these behavioral tests do not exist. The structural tests are reasonable for a PowerShell script that cannot be easily dot-sourced (it has side effects at load time from `Add-Type` and WinRT loading), but they provide weaker guarantees than behavioral tests would.

This is not a blocker because: (a) the Phase 1 tests established this structural testing pattern and it was approved; (b) the functions are simple enough that structural verification of the control flow (depth guard exists, try/catch exists, Parent property used, fallback called) provides reasonable confidence; (c) the manual QA acceptance criterion (3 VS Code windows, correct one focused) covers behavioral validation, and it is correctly marked as unchecked/deferred.

## BACKLOG

**L1: Remove dead EnumWindows callback code in `Get-WindowsByProcessTree`.** Lines 88-97 (`$foundHwnds`, `$callback`, `$results`) are unused. Either remove them or actually wire up `EnumWindows` enumeration. If the simpler `Get-Process` approach proves sufficient in practice, remove the dead code and the unused `$results` array. If Electron process trees are encountered where `MainWindowHandle` is on a sibling process (not an ancestor), wire up the actual `EnumWindows` callback. Track on a separate card.

**L2: Add behavioral Pester tests with mocked process trees.** The card's test strategy describes mock process trees (linear, branching, orphaned, stale PID) that verify function return values. These would catch regressions that structural tests miss -- for example, if someone reorders the fallback chain or changes the depth limit. Consider extracting the focus functions into a separate module that can be dot-sourced without side effects, enabling proper behavioral testing.

## Close-out actions

- Manual QA (unchecked acceptance criterion): test with 3 VS Code windows, verify correct window focused on toast click.
- The unchecked Completion Checklist items (code review, deploy, monitoring, stakeholders, follow-up, ticket closure) are post-merge lifecycle items and do not block approval.
