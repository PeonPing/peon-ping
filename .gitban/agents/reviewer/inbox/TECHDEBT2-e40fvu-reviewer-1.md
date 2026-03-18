---
verdict: APPROVAL
card_id: e40fvu
review_number: 1
commit: d4ab7f9
date: 2026-03-18
has_backlog_items: true
---

## Summary

This card adds 14 Pester tests covering `PEON_DEBUG=1` diagnostic warning output in `scripts/win-play.ps1` and the embedded `peon.ps1` within `install.ps1`. It also adds the diagnostic logging itself (cherry-picked from commit 3bcf15e which was on a different branch). The test file splits neatly into behavioral tests (4 tests that invoke `win-play.ps1` in a subprocess and capture the warning stream) and structural tests (10 tests that pattern-match against source content to verify diagnostic patterns are present and no empty catch blocks remain).

## Analysis

**TDD compliance.** The card is typed as `test` -- its purpose is adding test coverage for an existing diagnostic logging pattern. The commit introduces both the production code (cherry-picked `PEON_DEBUG` gating into `install.ps1` and `win-play.ps1`) and the tests in the same commit. For a test-backfill card this is appropriate: the diagnostic behavior was already designed in the prior card (z5xm5k/3bcf15e), and this card's job is to validate it. The test plan is thorough -- 14 cases covering happy path (warnings emitted with PEON_DEBUG=1), negative path (silent when unset), and structural validation.

**Test quality.** The behavioral tests (cases 1-4) are well-constructed. They spawn a real PowerShell subprocess, set the environment variable, redirect the warning stream via `3>&1`, and assert on the captured output. The negative tests (cases 3-4) verify silence when PEON_DEBUG is unset, which is critical -- diagnostic logging should never leak into production output. The "no CLI player" test correctly isolates by overriding PATH and ProgramFiles to non-existent directories.

**Structural tests.** Cases 5-14 use regex pattern matching against file content. This is a reasonable approach for validating that diagnostic patterns exist without needing to trigger every embedded catch block (which would require a full integration harness with mock config, state, manifests, etc.). The extraction of embedded peon.ps1 from the here-string block is correctly implemented.

**Scope of production changes.** The diff replaces 4 empty `catch {}` blocks in the embedded peon.ps1 with `catch { if ($peonDebug) { Write-Warning ... } }` and adds one new `else` branch for missing `win-play.ps1`. In `win-play.ps1`, one empty catch is replaced and one new diagnostic line is added at the end. All changes are guarded behind `$peonDebug` so they have zero runtime impact when `PEON_DEBUG` is unset. The `catch { exit 0 }` blocks (config read failure, stdin read failure, JSON parse failure, manifest parse failure) are correctly left alone -- those are intentional control flow, not silent error swallowing.

**Checkbox integrity.** All checked boxes are truthful. Test execution is verified in the executor log (14/14 new, 236/236 regression).

**DRY.** The `$peonDebug = $env:PEON_DEBUG -eq "1"` pattern is declared once per script entry point (once in `install.ps1` embedded block, once in `win-play.ps1`). No duplication concern.

**Security.** No secrets, no injection vectors. The diagnostic output includes file paths and error messages from PowerShell's own exception handling, which is appropriate for stderr diagnostics.

## BLOCKERS

None.

## BACKLOG

**L1: The `catch { exit 0 }` blocks in embedded peon.ps1 could benefit from PEON_DEBUG diagnostics too.** Lines 760, 774, 782, and 1087 exit silently on config read failure, stdin read failure, JSON parse failure, and manifest parse failure respectively. While these are intentional early exits (not silent error swallowing), a user debugging with `PEON_DEBUG=1` would still benefit from knowing *why* the hook exited. Low priority since these are "can't run at all" scenarios rather than subtle silent failures.

**L2: Behavioral test coverage gap for embedded peon.ps1 catch blocks.** The embedded peon.ps1 diagnostics (state write, category check, sound lookup, missing win-play.ps1) are only validated structurally via regex. Behavioral tests that actually trigger these paths would provide stronger guarantees, but require a more sophisticated test harness. Worth considering if the embedded script's error handling grows more complex.
