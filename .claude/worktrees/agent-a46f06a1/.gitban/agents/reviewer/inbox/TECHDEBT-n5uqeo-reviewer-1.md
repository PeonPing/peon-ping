---
verdict: APPROVAL
card_id: n5uqeo
review_number: 1
commit: ac4775f
date: 2026-03-16
has_backlog_items: false
---

## Review: Tighten peon-security.Tests.ps1 assertion precision

This card addresses two specific reviewer-flagged precision issues from the WINTEST Step 2C security tests review, and fixes a genuine source bug discovered during the investigation.

### Changes Evaluated

**1. Source fix in `scripts/hook-handle-use.ps1` (lines 117, 121)**

The executor identified that CLI-mode "pack not found" paths fell through to `exit 0` at line 124, inconsistent with other CLI error paths (invalid charset at line 76, not installed at line 99) which all `exit 1`. The fix adds `exit 1` in CLI mode before the existing `exit 0` for both the "no packs installed" and "pack not found" branches. The `exit 0` at line 124 remains as the hook-mode exit, which is correct -- hook mode communicates errors via JSON response, not exit codes.

The pattern used (`if ($cliMode) { Write-Host "..."; exit 1 }`) is consistent with the existing pattern at lines 76 and 99. This is the right fix.

**2. Scenario 5 exit code assertion (`tests/peon-security.Tests.ps1`)**

Added `$r.ExitCode | Should -Be 1` to Scenario 5, which tests the "nonexistent pack" CLI path. This assertion validates the source fix above. The test already verified output text; now it also verifies the error contract (non-zero exit on failure).

**3. Scenario 15 VLC gain regex tightening**

Changed from `Should -Match "--gain 1"` to `Should -Match "--gain 1(\.\d+)?(\s|$)"`. The original regex would match `--gain 10`, `--gain 100`, etc. The new pattern matches `--gain 1`, `--gain 1.0`, `--gain 1.00` but not `--gain 10`. The word-boundary approach using `(\s|$)` is correct for this context since the gain value appears at the end of the command line or followed by a space.

### TDD Assessment

The card is a test-precision card that tightens existing assertions. The test file (`peon-security.Tests.ps1`) was created in a prior commit (416f3c6) and already covered 16 scenarios. This card modifies two assertions and fixes the source to match the corrected contract. The source fix (exit code) was driven by the test investigation -- the test expectation was defined first (exit 1 for CLI errors should be consistent), then the source was fixed to meet it. This is TDD-compliant.

### Checkbox Audit

All checked boxes are truthful:
- Exit code assertion added: confirmed in diff.
- VLC gain regex tightened: confirmed in diff.
- Changes tested/verified: card reports 14/16 pass with 2 pre-existing failures (Scenarios 1 and 7, `session_override` vs `agentskill` mismatch). These are out of scope.
- Files modified match what the card claims.

### Close-out

No outstanding actions. The two pre-existing test failures (Scenarios 1 and 7) are noted as out of scope, which is appropriate -- they relate to a different behavioral question (`session_override` vs `agentskill` naming) that predates this card.
