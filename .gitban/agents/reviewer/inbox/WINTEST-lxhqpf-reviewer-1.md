---
verdict: REJECTION
card_id: lxhqpf
review_number: 1
commit: fa135b7
date: 2026-03-15
has_backlog_items: true
---

## Summary

This merge commit delivers `tests/peon-adapters.Tests.ps1` (764 lines, 48 Pester tests) providing functional test coverage for all 12 Windows adapter scripts, plus a minor update to `tests/adapters-windows.Tests.ps1` adding deepagents to the syntax validation and ExecutionPolicy Bypass ForEach lists.

The new test file is well-structured. The mock peon.ps1 stdin-capture pattern is a clean approach that lets tests verify the actual JSON payload each adapter produces without running the full engine. Category B (filesystem watcher) tests correctly extract pure functions rather than attempting to start event loops. Test isolation via per-test temp directories and `$env:CLAUDE_PEON_DIR` override is solid. The copilot marker-file session detection test correctly uses a fixed sessionId across both invocations to handle the PID-change issue. All 14 planned scenarios from the card are covered, plus 34 additional tests for secondary event mappings, edge cases, and CESP JSON shape validation.

One blocker prevents approval.

## BLOCKERS

**B1: peon-adapters.Tests.ps1 is not in CI.**

The new test file is not added to `.github/workflows/test.yml`. Line 55 currently lists only:

```
$config.Run.Path = @("tests/adapters-windows.Tests.ps1", "tests/peon-engine.Tests.ps1")
```

48 tests exist that will never execute in CI. The card's acceptance criteria checkbox "All tests pass in CI (windows-latest) -- pending CI run post-merge" acknowledges this is pending, but the workflow file was not updated in this commit. Without CI integration, these tests provide no regression protection -- they only pass on the author's machine.

**Refactor plan:** Add `"tests/peon-adapters.Tests.ps1"` to the `$config.Run.Path` array in `.github/workflows/test.yml`.

## BACKLOG

**L1: Duplicate deepagents structural tests.** Lines 683-698 of `peon-adapters.Tests.ps1` contain a standalone "Structural: deepagents.ps1 syntax validation" Describe block that checks valid PowerShell syntax and absence of ExecutionPolicy Bypass. These exact checks are already performed by `adapters-windows.Tests.ps1` via its ForEach-parameterized "PowerShell Syntax Validation" and "No ExecutionPolicy Bypass" Describe blocks, which now include deepagents in their lists. The standalone block in `peon-adapters.Tests.ps1` should be removed to avoid DRY violation.

**L2: Fragile function extraction regex for Category B tests.** The regex `(?s)(function Emit-Event \{.*?\n\})` (and similar for `Process-WireLine`) relies on the function's closing brace being the first unindented `}` after the function signature. This works today because all inner braces are indented, but any future refactor that introduces an unindented closing brace within the function body (e.g., a here-string, a comment, or a reformatter) would silently truncate the extraction. A more robust approach would be to use PowerShell's AST parser (`[System.Management.Automation.Language.Parser]::ParseFile()`) to extract function definitions programmatically.

**L3: Feature branch attempted to delete ~41 existing tests from adapters-windows.Tests.ps1.** The feature branch (`worktree-agent-a3e3d654`) removed the "Core Script Syntax Validation" Describe block, all path_rules tests (Runtime Matching Engine, CLI Commands Structural, CLI Commands Functional), Write-StateAtomic/Read-StateWithRetry tests, and several other assertions for code that still exists in `install.ps1`. The merge resolution correctly preserved these tests, so no damage was done, but this indicates the executor was operating outside the card's scope. Worth noting for process improvement.
