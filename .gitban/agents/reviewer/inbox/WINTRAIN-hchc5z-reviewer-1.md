---
verdict: APPROVAL
card_id: hchc5z
review_number: 1
commit: 5b32211
date: 2026-03-22
has_backlog_items: true
---

## Summary

This card adds 28 Pester tests for the Windows trainer feature (CLI subcommands and hook reminder logic) and fixes a real bug where three helper functions (`ConvertTo-Hashtable`, `Write-StateAtomic`, `Read-StateWithRetry`) were defined after the CLI block's `return` in `peon.ps1`, making them unreachable during CLI execution.

The test file is well-structured, the bug fix is surgical and correct, and the implementation aligns with ADR-002's decision to keep trainer logic inline in `peon.ps1`.

## Review

### install.ps1: Function relocation (bug fix)

The three functions were at lines 1220-1296 in the old revision, well past the CLI block at line 414 which contains `return` statements. Moving them to lines 413-491 (before `if ($Command)`) is the correct fix. The function bodies are byte-identical to the originals -- only clarifying comments were added ("Defined here (before CLI block) so both CLI commands and hook mode can use it/them."). This is a clean, zero-risk refactor.

The troubleshooting log on the card documents this clearly, explaining it was a latent bug from step 1 (yq8iba) that went undetected because CLI errors were silently swallowed. Good root-cause documentation.

### tests/trainer-windows.Tests.ps1: Test quality

**Test infrastructure** -- The `New-TestInstall` factory, `Invoke-PeonCli`, `Invoke-PeonHook`, `Get-TestConfig`, and `Get-TestState` helpers in `BeforeAll` are well-designed. Each test gets an isolated temp directory with fresh fixtures, properly cleaned up in `finally` blocks. The `Invoke-PeonHook` function correctly works around the PowerShell pipeline vs. console stdin issue using `cmd.exe /c "type ... | powershell.exe -File ..."` -- this matches the troubleshooting log and shows the executor understood the platform constraints.

**Scenario coverage** -- The 28 tests cover:
- All 6 CLI subcommands with both happy path and error cases
- Both `--trainer` and `trainer` prefix forms (ADR-002 specifies both should work)
- Hook reminder logic: interval elapsed, interval not elapsed, all exercises complete, date reset, disabled overhead
- Edge cases: reps exceeding goal (overflow), accumulated reps across multiple calls
- Input validation: unknown exercise, non-numeric count, missing arguments
- Syntax validation of the extracted peon.ps1
- Performance assertion (under 5s with warmup)

This is genuine contract-first testing. The tests define behaviors ("logged 25 pushups", "75/300", "trainer not enabled") and verify state file mutations, not internal implementation details.

**TDD compliance** -- This is a test card for functionality implemented in steps 1 and 2. The test scenarios map directly to the card's 16 planned scenarios. The bug fix emerged from writing these tests (functions unreachable in CLI mode), which is exactly how test-driven validation should work: the tests exposed a defect in the implementation.

**Performance test** -- The 5s threshold (relaxed from the card's 500ms aspiration) with a warmup run is pragmatic for CI. The comment "the main check is that it does not hang" is honest about what the test actually validates.

### ADR-002 compliance

The tests validate the inline architecture decision: `peon.ps1` is extracted from the `install.ps1` here-string and tested as the installed artifact. The `Get-PeonPs1Content` function correctly handles the extraction. This matches ADR-002's point that "Pester tests should validate the behavior of the installed peon.ps1, not unit-test internal functions."

### Checkbox audit

All checked boxes are verified true:
- Test file exists at `tests/trainer-windows.Tests.ps1`
- Fixtures are per-test via `New-TestInstall`
- Happy path, edge case, error handling, and performance tests all present
- Card reports 28 tests passing in 26s (under the 30s CI budget)
- Test file has clear docstring header and structured `Describe` blocks

## BACKLOG

**L1: Performance test threshold drift.** The card spec says 500ms, the test asserts 5000ms. The 10x gap is understandable for CI stability but should be tracked. Consider a separate local-only performance benchmark that enforces the tighter threshold, or add a comment to the test noting the CI-relaxed value vs. the design target.

**L2: `Invoke-PeonCli` argument quoting.** The helper constructs args via string concatenation: `"'" + $_ + "'"`. If any argument ever contains a single quote, this breaks. Not a problem today (exercise names and numbers are simple), but a fragility worth noting. A future refactoring could use `& powershell.exe -File $script -args` with proper array splatting.

## Close-out

No blocking issues. The bug fix and test suite are both solid. The card can proceed.
