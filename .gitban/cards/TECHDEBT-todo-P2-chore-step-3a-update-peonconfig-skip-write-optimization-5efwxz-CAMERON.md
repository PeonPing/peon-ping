# Update-PeonConfig skip-write optimization

## Task Overview

* **Task Description:** `Update-PeonConfig` unconditionally writes config back to disk even when the mutator makes no changes. Add a skip-write optimization so unnecessary disk I/O is avoided.
* **Motivation:** The current implementation always serializes and writes `config.json` after every mutator call, even if the config object was not modified. This causes unnecessary disk I/O and increases the risk of write-related edge cases (file locking, partial writes) on Windows.
* **Scope:** `install.ps1` — the embedded `peon.ps1` hook script's `Update-PeonConfig` function.
* **Related Work:** Originated from reviewer feedback on card `inexon` (step 2c windows CLI bind/unbind quality improvements). Flagged as L2 non-blocking item.
* **Estimated Effort:** 1-2 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Review `Update-PeonConfig` in the embedded `peon.ps1` within `install.ps1` to understand current write-always behavior | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Choose approach: (a) have the mutator scriptblock return a changed flag, or (b) compare before/after JSON strings to detect no-op mutations | - [ ] Change plan is documented. |
| **3. Make Changes** | Implement the skip-write check in `Update-PeonConfig` | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run Pester tests (`Invoke-Pester -Path tests/adapters-windows.Tests.ps1`) and verify bind/unbind/bindings still work correctly | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal optimization, no user-facing doc changes expected | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Suggested approaches from reviewer:
> 1. Have the mutator return a changed flag (e.g., return `$true`/`$false`)
> 2. Compare before/after JSON (`ConvertTo-Json`) to skip write when identical
>
> Approach (2) is simpler but has a minor cost of double-serialization. Approach (1) is more explicit but requires updating all existing mutator callsites.

**Decisions Made:**
* Approach TBD during implementation

**Issues Encountered:**
* None yet

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | TBD |
| **Files Modified** | TBD |
| **Pull Request** | TBD |
| **Testing Performed** | TBD |

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
