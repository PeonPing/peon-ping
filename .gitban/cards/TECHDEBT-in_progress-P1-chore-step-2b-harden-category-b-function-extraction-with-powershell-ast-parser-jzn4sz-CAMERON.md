# Harden Category B function extraction with PowerShell AST parser

**Step 2B** — Gated on step 1A (d3c6b0). Both cards modify `peon-adapters.Tests.ps1`.

## Task Overview

* **Task Description:** Replace the regex-based function extraction in `tests/peon-adapters.Tests.ps1` (patterns like `(?s)(function Emit-Event \{.*?\n\})` and similar for `Process-WireLine`) with PowerShell AST parsing via `[System.Management.Automation.Language.Parser]::ParseFile()`. The current regex relies on the closing brace being the first unindented `}` after the function signature, which is fragile.
* **Motivation:** A future refactor to the adapter source files could silently break extraction if brace formatting changes, leading to false-passing or false-failing tests. AST parsing is robust and format-independent.
* **Scope:** `tests/peon-adapters.Tests.ps1` — Category B function extraction tests.
* **Related Work:** Flagged during WINTEST lxhqpf reviewer feedback (L2).
* **Estimated Effort:** 1-2 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Category B tests used `Should -Match` on raw file content. No AST extraction existed. Functions Emit-Event, Test-ThreadWaiting, Handle-ThreadChange (amp), Emit-Event, Handle-ConversationChange (antigravity), Emit-Event, Process-WireLine, Resolve-KimiCwd, Handle-WireChange (kimi) identified for AST extraction. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Add `Get-FunctionAst` helper using `Parser::ParseFile()` + `FindAll()` with `FunctionDefinitionAst` predicate. Extract functions by name, verify params via `Body.ParamBlock.Parameters`, verify body content via `Extent.Text`. Keep existing `Should -Match` tests for non-function-level checks. | - [x] Change plan is documented. |
| **3. Make Changes** | Implemented Get-FunctionAst helper and 28 new AST-based tests across 3 Category B adapters. Commit `0891dbb`. | - [x] Changes are implemented. |
| **4. Test/Verify** | All 227 Pester tests pass (was ~199 before, +28 new AST tests). 0 failures. | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A (internal test refactor, no user-facing docs) | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Ready for review. | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Use `[System.Management.Automation.Language.Parser]::ParseFile()` to get the AST, then find function definitions by name using `$ast.FindAll()` with a predicate matching `FunctionDefinitionAst` nodes. Extract the function body extent text for testing.

**Decisions Made:**
* AST parser chosen over improved regex because it is format-independent and the canonical PowerShell approach.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Added Get-FunctionAst helper + 28 AST-based function extraction tests for Category B adapters (amp, antigravity, kimi) |
| **Files Modified** | tests/adapters-windows.Tests.ps1 |
| **Pull Request** | Pending merge to sprint/TECHDEBT |
| **Testing Performed** | Invoke-Pester: 227/227 pass, 0 fail |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Execution Summary

**Commit:** `0891dbb` on branch `worktree-agent-a0da3d3d`

**What was done:**
- Added `Get-FunctionAst` helper function to the top-level `BeforeAll` block in `tests/adapters-windows.Tests.ps1`. Uses `[System.Management.Automation.Language.Parser]::ParseFile()` with `FindAll()` predicate matching `FunctionDefinitionAst` nodes.
- Added 28 new AST-based tests across 3 Category B adapters:
  - **Amp** (8 new tests): Emit-Event, Test-ThreadWaiting, Handle-ThreadChange extraction + parameter/body verification
  - **Antigravity** (6 new tests): Emit-Event, Handle-ConversationChange extraction + parameter/body verification
  - **Kimi** (14 new tests): Emit-Event, Process-WireLine, Resolve-KimiCwd, Handle-WireChange extraction + parameter/body/event-mapping verification
- Migrated event mapping assertions (TurnEnd->Stop, CompactionBegin->PreCompact, SubagentEvent->SubagentStart) from raw file regex to AST-extracted function body assertions
- Kept existing `Should -Match` tests for non-function-level checks (daemon flags, FileSystemWatcher, PID files, etc.)

**Test results:** 227/227 Pester tests pass, 0 failures.

**Deferred work:** None. Step 6 (Review/Merge) left unchecked pending reviewer merge.

**No follow-up tickets needed.**