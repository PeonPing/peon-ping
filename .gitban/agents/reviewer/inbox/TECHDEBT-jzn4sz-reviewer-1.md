---
verdict: APPROVAL
card_id: jzn4sz
review_number: 1
commit: 0891dbb
date: 2026-03-16
has_backlog_items: true
---

## Review: Harden Category B function extraction with PowerShell AST parser

### Assessment

This is a clean, well-scoped test infrastructure improvement. The commit replaces fragile regex-based function verification in Category B adapter tests with PowerShell AST parsing via `[System.Management.Automation.Language.Parser]::ParseFile()`. The motivation is sound: regex patterns like `(?s)(function Emit-Event \{.*?\n\})` are brittle against formatting changes, while AST parsing is format-independent by definition.

### What was evaluated

**1. Get-FunctionAst helper (lines 18-37 of the post-commit file)**

The helper is correctly placed in the top-level `BeforeAll` block, making it available to all `Describe` blocks. The implementation is idiomatic PowerShell: it uses `ParseFile` with `[ref]` out-parameters for tokens and errors, then `FindAll` with a predicate filtering for `FunctionDefinitionAst` nodes matching the target name. The `$true` parameter to `FindAll` enables recursive search through nested scopes, which is the correct behavior for adapter files that may nest functions.

One observation: the `$errors` and `$tokens` variables are captured but never inspected. This is acceptable for a test helper -- if the file has parse errors, the downstream assertions will fail anyway, producing a clear enough signal. Not a blocker.

**2. Category B test structure**

Each adapter's `BeforeAll` now extracts all relevant functions up front into `$script:` variables, then individual `It` blocks assert against those cached AST objects. This is the right pattern -- parse once, assert many times.

The tests follow a consistent three-tier structure per function:
- Existence check (extractable via AST, count is 1)
- Parameter signature verification (via `Body.ParamBlock.Parameters`)
- Body content verification (via `Extent.Text` with `Should -Match`)

**3. Migration of event mapping tests (Kimi)**

The old tests like `"maps TurnEnd to Stop"` used whole-file regex matches (`$script:kimiContent | Should -Match '"TurnEnd".*"Stop"'`). The new tests scope these assertions to the specific function body (`$script:kimiProcessWireLine[0].Extent.Text`). This is strictly more precise -- the old tests could pass even if the mapping was in a comment or dead code path, while the new tests confirm the mapping lives inside `Process-WireLine` specifically. Good improvement.

The non-function-level checks (daemon flags, FileSystemWatcher, PID files) correctly remain as whole-file regex assertions, since those are structural properties of the file, not function-level behavior.

**4. TDD compliance**

This card is a test refactor -- it changes how tests are written, not what behavior is tested. The production code is untouched. TDD scrutiny is proportional: this is infrastructure that makes the test suite more robust, and it does so correctly. The 28 new tests are additive (from ~199 to 227), and the migrated tests are strictly more precise than their predecessors. No behavior was lost.

**5. Checkbox integrity**

All checked boxes on the card are truthful:
- Task description, motivation, scope: accurate
- Current state review: documented correctly
- Change plan: matches what was implemented
- Testing: card claims 227/227 pass, 0 failures. The card's execution summary is consistent with the diff.
- Documentation: N/A is correct for an internal test refactor

### No blockers found.

The code is clean, idiomatic, well-structured, and achieves its stated goal. The AST approach is the canonical way to introspect PowerShell code and is a clear upgrade over regex extraction.

### BACKLOG

**L1: Get-FunctionAst could assert on parse errors for defensive clarity.** Currently, if an adapter file has a syntax error, `ParseFile` will populate `$errors` but the helper silently returns whatever partial AST it got (or nothing). Adding an optional assertion like `$errors | Should -BeNullOrEmpty` inside the helper (or as a dedicated test per adapter) would surface parse failures immediately rather than as confusing downstream assertion failures. Non-blocking because syntax validation is already covered by the Category-level syntax tests earlier in the file, but it would improve debuggability.

**L2: Consider extracting the parameter-name-from-AST pattern into a helper.** The pattern `@($params | ForEach-Object { $_.Name.VariablePath.UserPath })` appears 5 times across the three adapter sections. A small `Get-ParamNames` helper would DRY this up. Non-blocking since 5 occurrences is at the threshold and the pattern is simple enough to be self-documenting.
