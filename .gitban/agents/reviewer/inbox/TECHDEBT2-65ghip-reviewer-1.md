---
verdict: APPROVAL
card_id: 65ghip
review_number: 1
commit: 61c6e63
date: 2026-03-17
has_backlog_items: false
---

## Review: harden Get-FunctionAst parse-error assertion and DRY up parameter extraction

### Changes Reviewed

1. **Parse-error assertion in `Get-FunctionAst`** -- Three lines added after `Parser::ParseFile` to check `$errors` and throw with a message that includes the file path and joined error strings. This is correct: `$errors` is a `[ref]` out-parameter that receives a `ParseError[]` array, and PowerShell treats a non-empty array as truthy. The error message interpolation using `${FilePath}` (braced form) is correct and avoids ambiguity with the colon that follows. The `-join '; '` formatting is appropriate for surfacing multiple parse errors in a single throw.

2. **`Get-ParamNames` helper extraction** -- A new function accepts a `FunctionDefinitionAst` and returns the parameter names array. The type constraint `[System.Management.Automation.Language.FunctionDefinitionAst]` is correct and provides early failure if the wrong type is passed. All four call sites were updated to use the helper. Post-change grep confirms `VariablePath.UserPath` now appears only once in the file (inside the helper itself). The card originally estimated 5 occurrences; the executor correctly noted the actual count was 4 and documented this in the work log.

### TDD Assessment

This is a test-infrastructure-only change (improving test helpers, not production code). The helpers are exercised by the existing 279 Pester tests that all pass. No new runtime behavior was introduced, so no new behavioral tests are required. TDD proportionality is satisfied.

### BLOCKERS

None.

### BACKLOG

None.
