# Harden Get-FunctionAst parse-error assertion and DRY up parameter extraction

## Task Overview

* **Task Description:** Two improvements to the Pester test helpers in `tests/peon-engine.Tests.ps1` (or `tests/adapters-windows.Tests.ps1`): (1) Add a parse-error assertion to `Get-FunctionAst` so that `Parser::ParseFile` errors surface immediately instead of causing confusing downstream failures. (2) Extract a `Get-ParamNames` helper to DRY up the repeated `@($params | ForEach-Object { $_.Name.VariablePath.UserPath })` pattern that appears 5 times across Category B adapter sections.
* **Motivation:** Reviewer feedback on card jzn4sz identified these as non-blocking improvements. Parse errors are currently silently ignored, which can mask real failures. The parameter-name extraction pattern is duplicated 5 times, making maintenance harder.
* **Scope:** `tests/adapters-windows.Tests.ps1` — `Get-FunctionAst` helper and Category B test sections (amp, antigravity, kimi adapters).
* **Related Work:** Follow-up from jzn4sz review (`.gitban/agents/reviewer/inbox/TECHDEBT-jzn4sz-reviewer-1.md`).
* **Estimated Effort:** 1 hour

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | `Get-FunctionAst` uses `Parser::ParseFile` which populates `$errors` but the helper silently ignores them. The pattern `@($params | ForEach-Object { $_.Name.VariablePath.UserPath })` appears 5 times across 3 Category B adapter sections. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | (a) Add `$errors | Should -BeNullOrEmpty` assertion inside `Get-FunctionAst` or as a dedicated test per adapter. (b) Extract `Get-ParamNames` helper that wraps the repeated ForEach pattern. Replace all 5 occurrences. | - [ ] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — test-only change | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Items from reviewer feedback on jzn4sz:
> - L1: Add parse error assertion to Get-FunctionAst helper
> - L2: Extract Get-ParamNames helper to DRY up parameter-name-from-AST pattern

**Decisions Made:**
* Grouped both items into a single card per planner instructions.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | |
| **Pull Request** | |
| **Testing Performed** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
