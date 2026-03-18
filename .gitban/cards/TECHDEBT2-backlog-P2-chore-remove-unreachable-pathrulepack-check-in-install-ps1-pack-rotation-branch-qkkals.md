# Remove unreachable pathRulePack check in install.ps1 pack_rotation branch

**When to use this template:** FASTFOLLOW — dead code removal flagged during TECHDEBT2 reviewer pass on card tnd98r.

---

## Task Overview

* **Task Description:** Remove the unreachable `$pathRulePack` check inside the `pack_rotation` branch in `install.ps1` (lines 1068-1071). The `$pathRulePack` case is already handled by the preceding `elseif ($pathRulePack)` at line 1065, so if `$pathRulePack` is truthy, execution never reaches line 1069. This is dead code.
* **Motivation:** Dead code reduces readability and can mislead future contributors into thinking the check is functional. Removing it clarifies the actual control flow.
* **Scope:** `install.ps1` — remove lines 1068-1071 (the `$pathRulePack` check inside the `pack_rotation` branch).
* **Related Work:** Flagged by reviewer on card tnd98r (align-default-pack-config-parity-and-add-session-override-path-rules-test).
* **Estimated Effort:** 15 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | install.ps1 lines 1065-1071: `elseif ($pathRulePack)` at L1065 handles the path-rule case. Inside the subsequent `pack_rotation` branch (L1068-1071), a redundant `$pathRulePack` check exists that can never be reached. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Remove the dead `$pathRulePack` check (lines 1068-1071) from inside the pack_rotation branch. No functional change expected. | - [ ] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run Pester tests to confirm no regressions. | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal dead code removal, no user-facing changes. | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Flagged by TECHDEBT2 reviewer on card tnd98r. The `$pathRulePack` variable is checked in an `elseif` before the `pack_rotation` branch, so the inner check is unreachable.

**Commands/Scripts Used:**
```powershell
# Verify with Pester after removal
Invoke-Pester -Path tests/adapters-windows.Tests.ps1
```

**Decisions Made:**
* Straight removal — no replacement logic needed since the outer elseif already handles this case.

**Issues Encountered:**
* None expected.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | install.ps1 |
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

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
