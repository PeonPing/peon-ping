---
verdict: APPROVAL
card_id: 9gi8ut
review_number: 1
commit: 7e54ae8
date: 2026-03-18
has_backlog_items: true
---

## Summary

This commit adds `tests/cli-config-write.Tests.ps1` with 20 behavioral Pester tests covering the CLI config-write commands (`--pause`, `--resume`, `--toggle`, `--volume`, `--mute`, `--unmute`). The tests extract the hook script from `install.ps1`'s here-string, write it to an isolated temp directory alongside a real `config.json`, execute commands via `pwsh -File`, and verify the config file was updated correctly. This replaces the prior structural grep-style coverage with genuine end-to-end behavioral verification.

## Assessment

**Test design quality:** The tests are well-structured and behavioral. They define the contract (what each command should do to the config file) rather than mirroring implementation details. Each Describe block maps to a single command, with focused assertions on the config file state after execution. The test isolation pattern (fresh temp dir per test via BeforeEach/AfterEach) is clean and prevents cross-contamination.

**TDD compliance:** This is a test card for pre-existing behavior -- the production code already exists. The card correctly identifies that existing tests were structural-only (string presence checks) and that skip-write optimization had zero behavioral coverage. The test cases cover the full contract: happy path writes, idempotency (no-op when value already matches), alias commands, boundary clamping (volume), JSON integrity after multiple writes, non-target key preservation, and error handling for missing config. The failure cases and edge cases are present, which is consistent with test-first thinking.

**Test execution evidence:** Executor logs show `tests/cli-config-write.Tests.ps1` with 20 passed / 0 failed, and `tests/adapters-windows.Tests.ps1` with 236 passed / 0 failed (regression check). Satisfactory.

**Config setup fidelity:** The `New-TestHookEnv` helper builds a config with all production keys (27 keys matching `config.json`), ensuring the regex-based replacement logic in production code sees realistic JSON structure. The hook script discovery mechanism (`$MyInvocation.MyCommand.Path` -> same directory as config.json) is faithfully replicated by colocating both files in the temp directory.

**No lazy solves:** No dependency changes, no widened catches, no loosened checks. Pure test addition.

## BLOCKERS

None.

## BACKLOG

**L1 -- Volume regex is fragile against JSON key ordering.**
The production code at line 696 uses `'"volume"\s*:\s*[\d.]+,'` which requires a trailing comma. PowerShell hashtable enumeration order is not guaranteed. If `volume` were serialized as the last JSON key (no trailing comma), the regex would silently not match, `$updated -ne $raw` would be false, and the write would be skipped. The test would catch this (it asserts the new value), but the production code itself has a latent bug. A safer approach would be to parse/reserialize JSON or use a regex that handles the optional trailing comma. This is pre-existing debt, not introduced by this card.

**L2 -- `Invoke-PeonCommand` does not assert exit codes.**
The helper captures output but does not return or assert `$LASTEXITCODE`. For the error-handling tests this is fine (they assert on output text), but the success-path tests could be strengthened by also asserting exit code 0. Low priority since the config assertions implicitly prove success.
