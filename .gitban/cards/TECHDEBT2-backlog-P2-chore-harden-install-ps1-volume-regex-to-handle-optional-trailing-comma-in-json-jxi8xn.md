# Harden install.ps1 volume regex to handle optional trailing comma in JSON

## Task Overview

* **Task Description:** The volume config-write regex at line ~696 of `install.ps1` uses `'"volume"\s*:\s*[\d.]+,'` which requires a trailing comma after the value. PowerShell hashtable enumeration order is not guaranteed, so if `volume` is serialized as the last JSON key (no trailing comma), the regex silently fails to match and the write is skipped. Fix by making the trailing comma optional in the regex pattern (e.g., `,?`) or by switching to proper JSON parse/reserialize.
* **Motivation:** Pre-existing tech debt. Silent failure when volume is the last key in JSON output means config writes are silently dropped, leading to user confusion when volume settings don't persist.
* **Scope:** `install.ps1` — volume config-write regex (line ~696)
* **Related Work:** Identified during reviewer pass on card 9gi8ut (behavioral test coverage for CLI config write commands)
* **Estimated Effort:** 30 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Review line ~696 of install.ps1 to confirm the regex pattern and trailing comma assumption | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Make trailing comma optional (`,?`) in the regex, or switch to JSON parse/reserialize | - [ ] Change plan is documented. |
| **3. Make Changes** | Update the regex pattern in install.ps1 | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run Pester tests; verify volume write works when volume is both a middle and last JSON key | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal fix, no user-facing doc changes | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> The root cause is that PowerShell `ConvertTo-Json` does not guarantee key order, so any key could be last (no trailing comma). The fix should handle this for all similar regex patterns in install.ps1, not just the volume one.

**Commands/Scripts Used:**
```powershell
# Test with Pester
Invoke-Pester -Path tests/adapters-windows.Tests.ps1
```

**Decisions Made:**
* TBD — decide between minimal regex fix (`,?`) vs. proper JSON parse/reserialize approach

**Issues Encountered:**
* None yet

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | TBD |
| **Files Modified** | `install.ps1` |
| **Pull Request** | TBD |
| **Testing Performed** | TBD |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | Check if other regex patterns in install.ps1 have the same trailing comma assumption |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | TBD |
| **Process Improvements?** | Consider switching all JSON manipulation to parse/reserialize instead of regex |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
