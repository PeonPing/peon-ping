# Upgrade Write-StateAtomic to true atomic overwrite

**When to use this template:** Tech debt cleanup — upgrade atomic state write implementation when PowerShell 5.1 support is dropped.

---

## Task Overview

* **Task Description:** Write-StateAtomic in `peon.ps1` currently uses a delete-then-move pattern which has a tiny window where the state file does not exist. On PowerShell 7+, `[System.IO.File]::Move($src, $dst, $true)` provides a true atomic overwrite. Upgrade to this API when PS 5.1 support is dropped.
* **Motivation:** The current delete-then-move pattern has a theoretical race condition window. The three-arg `Move()` overload (available in .NET Core / PS 7+) eliminates this entirely. The current retry-on-read mitigation makes data loss extremely unlikely, so this is low urgency.
* **Scope:** `peon.ps1` — the `Write-StateAtomic` function.
* **Related Work:** Flagged during SMARTPACK-janrlf review. Original atomic state writes implemented in card kydihy (archived). Related refactor card lyq5ta.
* **Estimated Effort:** 30 minutes (once PS 5.1 is dropped)

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | `Write-StateAtomic` uses Remove-Item + [IO.File]::Move (two-step) | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Replace with `[System.IO.File]::Move($src, $dst, $true)` (single-step atomic overwrite, requires .NET Core / PS 7+) | - [ ] Change plan is documented. |
| **3. Make Changes** | Blocked until PS 5.1 support is dropped | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run existing BATS and Pester tests | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal implementation detail | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Pending | - [ ] Changes are reviewed and merged. |

#### Work Notes

> This is blocked until the project drops PowerShell 5.1 support. The current implementation with retry-on-read makes data loss extremely unlikely, so there is no urgency.

**Decisions Made:**
* Current retry-on-read mitigation is sufficient for now.

**Issues Encountered:**
* None — this is a future improvement.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Pending |
| **Files Modified** | `peon.ps1` |
| **Pull Request** | Pending |
| **Testing Performed** | Pending |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | Blocked until PS 5.1 support is dropped |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
