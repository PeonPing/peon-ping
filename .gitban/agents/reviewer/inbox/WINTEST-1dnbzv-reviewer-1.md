---
verdict: APPROVAL
card_id: 1dnbzv
review_number: 1
commit: 91d1774e2a956b9c902024e0219edfe3bb3b7933
date: 2026-03-15
has_backlog_items: true
---

## Summary

This commit adds 17 test scenarios (503 lines) to `tests/peon-engine.Tests.ps1`, covering event routing (7 scenarios), config behavior (4 scenarios), and state management (6 scenarios). The tests exercise the real `peon.ps1` engine extracted from `install.ps1`, running in isolated temp directories created by the shared harness from step 1 (card q52ygy).

The implementation is thorough and well-structured. Every scenario maps directly to an acceptance criterion on the card, tests verify behavior rather than implementation details, and the one scenario that cannot pass due to a production bug is properly skipped with a clear explanation and a tracked follow-up card (`8ny6qr`).

Key observations:

**Test design quality.** The scenarios are meaningfully distinct -- each one tests a specific production behavior path (event routing switch branch, config flag, state mutation). There is no duplication between these 17 scenarios and the 8 smoke tests already in the file. The smoke tests validate the harness infrastructure; these scenarios validate engine behavior. The boundary is clean.

**Deterministic state testing.** The debounce test (Scenario 12) uses state pre-seeding with stale `last_stop_time` epochs instead of `Start-Sleep`, and the no-repeat test (Scenario 13) uses a 2-sound fixture to force deterministic alternation. Both are correct approaches that keep tests fast and non-flaky.

**BeforeEach vs BeforeAll scoping.** Scenario 7 (Cursor camelCase remap) correctly uses `BeforeEach`/`AfterEach` to create a fresh environment per sub-test, because the camelCase remaps for `stop` and `subagentStop` both resolve to `Stop`, which has a 5-second debounce. Without fresh environments, the second sub-test would be silently suppressed. This is a thoughtful decision documented in the test comment.

**Scenario 14 skip.** The spam detection test is skipped with `-Skip:$true` and includes a thorough explanation of the `ConvertTo-Hashtable` array corruption bug. The test body is fully written (not a placeholder), so when the production bug is fixed, removing the skip flag is all that is needed. The bug is tracked on card `8ny6qr` (confirmed to exist in draft status).

**Scenario 17 empty stdin.** This test correctly uses raw `ProcessStartInfo` instead of `Invoke-PeonHook` because the helper's `Mandatory` parameter rejects empty strings. The approach is appropriate -- it tests a real edge case (hook invoked with no stdin) at the process level.

**Overlap with smoke tests.** Scenarios 1, 2, and 8 cover the same events as the existing smoke tests (SessionStart, Stop, disabled config). However, the new scenarios are more precise: they assert specific sound filenames via regex (`Hello[12]\.wav`, `Done[12]\.wav`) and verify exact audio log counts (`Should -Be 1` vs `Should -BeGreaterOrEqual 1`). The smoke tests serve as harness validation; the new scenarios serve as engine contract tests. This is acceptable overlap, not DRY-violating duplication, because the two groups have different purposes and different assertion specificity.

## BLOCKERS

None.

## BACKLOG

**L1: Scenario 15 session TTL assertion uses dual type-checking.** The `Get-PeonState` helper returns `ConvertFrom-Json` output, which is always `PSCustomObject`. The `if ($sessionPacks -is [hashtable])` branch (lines 540-541 in the diff) is dead code -- `ConvertFrom-Json` never returns hashtables in PowerShell 5.1. Harmless but misleading. Consider removing the hashtable branch to reduce test complexity.

**L2: Smoke test / scenario overlap could benefit from a comment.** The existing smoke tests (Scenarios "Invoke-PeonHook: SessionStart plays a sound", "Stop plays a completion sound", "disabled config skips sound") test the same events as Scenarios 1, 2, and 8. Both groups pass and serve different purposes. A brief section comment at the smoke test block explaining "these validate harness infrastructure, not engine contracts" would help future contributors understand why the overlap exists.
