# Harden Category B function extraction with PowerShell AST parser

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
| **1. Review Current State** | Regex patterns `(?s)(function Emit-Event \{.*?\n\})` and similar used for function extraction in Category B tests | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Replace regex extraction with `[System.Management.Automation.Language.Parser]::ParseFile()` to extract function bodies via AST | - [ ] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run `Invoke-Pester` to confirm all Category B tests still pass | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

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
| **Changes Made** | |
| **Files Modified** | tests/peon-adapters.Tests.ps1 |
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
