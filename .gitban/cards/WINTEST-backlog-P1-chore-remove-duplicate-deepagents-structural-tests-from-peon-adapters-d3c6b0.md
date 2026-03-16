# Remove duplicate deepagents structural tests from peon-adapters

## Task Overview

* **Task Description:** Remove the standalone "Structural: deepagents.ps1 syntax validation" Describe block (lines 683-698) from `tests/peon-adapters.Tests.ps1`. These exact checks (valid PowerShell syntax, absence of ExecutionPolicy Bypass) are already performed by `adapters-windows.Tests.ps1` via its ForEach-parameterized blocks which now include deepagents.
* **Motivation:** DRY violation — the same structural tests run in two places. Removing the duplicate keeps the test suite clean and avoids false confidence from redundant assertions.
* **Scope:** `tests/peon-adapters.Tests.ps1` — delete the standalone deepagents structural Describe block.
* **Related Work:** Flagged during WINTEST lxhqpf reviewer feedback (L1).
* **Estimated Effort:** 15 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Lines 683-698 of peon-adapters.Tests.ps1 contain a standalone deepagents structural block duplicating adapters-windows.Tests.ps1 coverage | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Delete the standalone Describe block for deepagents structural tests | - [ ] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run `Invoke-Pester` to confirm no regressions | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Remove the standalone Describe block at lines 683-698 of peon-adapters.Tests.ps1. Verify that adapters-windows.Tests.ps1 still covers deepagents in its parameterized blocks.

**Decisions Made:**
* Duplicate coverage identified by reviewer during WINTEST sprint.

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
