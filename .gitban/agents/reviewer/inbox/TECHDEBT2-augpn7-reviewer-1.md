---
verdict: APPROVAL
card_id: augpn7
review_number: 1
commit: 371c945
date: 2026-03-18
has_backlog_items: false
---

## Review: Extract install.ps1 validation into dot-sourceable module

### Summary

Clean, well-scoped refactoring. Seven functions (`Test-SafePackName`, `Test-SafeSourceRepo`, `Test-SafeSourceRef`, `Test-SafeSourcePath`, `Test-SafeFilename`, `Get-PeonConfigRaw`, `Get-ActivePack`) were lifted verbatim from `install.ps1` into `scripts/install-utils.ps1`. The installer now dot-sources the module. 18 behavioral Pester tests were added that call the real functions rather than regex-matching source text. Two existing structural tests were updated to check the new file instead of `install.ps1` for patterns that moved.

### Assessment

**Extraction correctness.** Diffing the removed lines in `install.ps1` against the new `scripts/install-utils.ps1` confirms a byte-identical move -- no logic was altered, added, or dropped during extraction. The dot-source line uses nested `Join-Path` for PS 5.1 compatibility, which is correct.

**No side effects.** `install-utils.ps1` contains only function definitions and comments. No `Write-Host`, no variable assignments outside function bodies, no execution-policy changes. The header comment explicitly documents this contract. Good.

**Behavioral tests.** The 18 new tests exercise all 7 functions with both positive and negative cases:
- All 5 `Test-Safe*` validators have accept and reject tests with multiple inputs including empty strings, path traversal, slashes, and special characters.
- `Get-PeonConfigRaw` is tested with comma-decimal locale damage, missing volume value, and clean passthrough.
- `Get-ActivePack` is tested across all 3 branches of the fallback chain (default_pack, active_pack, "peon" default).

These are proper behavioral tests -- they invoke real functions with controlled inputs and assert on outputs rather than grepping source text.

**Structural test updates.** The two structural tests that previously matched function body patterns in `install.ps1` were correctly redirected to read `install-utils.ps1` instead. The assertions themselves (`\\d\),\(\\d` for locale repair, `\\\.\\\.` for path traversal) are unchanged and still valid.

**TDD proportionality.** This is a pure extract-method refactoring of existing functions. The behavioral tests were added alongside the extraction, which is appropriate -- the prior tests were structural (regex-matching source text), so there was no pre-existing behavioral test to "drive" the refactoring with. The new tests now serve as the behavioral contract for future changes.

**DRY.** The card's original motivation was to eliminate duplication between `install.ps1` and tests. The executor's implementation note correctly flags that the tests were not actually duplicating functions -- they were doing structural regex matching. The refactoring still achieves the DRY goal by establishing a single source of truth for validation logic, and the new behavioral tests are strictly better than regex-matching source text.

**Executor evidence.** The executor log shows 253 passed, 0 failed. The delta from 235 to 253 is +18, matching the number of new test `It` blocks in the diff.

### BLOCKERS

None.

### BACKLOG

None.

### Close-out

- Three unchecked checkboxes on the card are review-gated ("Code reviewed..." items). These can be checked upon merge.
