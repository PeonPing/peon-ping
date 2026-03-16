# Harden PS 5.1 locale handling in Write-StateAtomic and improve test harness reliability

## Task Overview

* **Task Description:** Two non-blocking improvements from the 8ny6qr review: (1) Add InvariantCulture locale guard to production `Write-StateAtomic` in `install.ps1` so `ConvertTo-Json` emits `0.5` instead of `0,5` on non-English locales; (2) Replace timing-based audio log detection in `Invoke-PeonHook` (windows-setup.ps1) with a sentinel-file approach from mock `win-play.ps1` for more robust CI.
* **Motivation:** L1: On non-English locales using decimal commas, volume values like `0.5` could be written as `0,5` in `.state.json`, corrupting state on read-back. The test harness already applies InvariantCulture — production code should match. L2: The current 3s poll + 200ms flush wait in `Invoke-PeonHook` is fragile on slow CI runners. A sentinel-file approach would be deterministic.
* **Scope:** `install.ps1` (Write-StateAtomic function), `tests/windows-setup.ps1` (Invoke-PeonHook helper and mock win-play.ps1)
* **Related Work:** Follow-up from review of card 8ny6qr (ConvertTo-Hashtable array corruption fix)
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
| **1. Review Current State** | L1: Confirm `Write-StateAtomic` in `install.ps1` lacks InvariantCulture guard on `ConvertTo-Json`. L2: Confirm `Invoke-PeonHook` in `tests/windows-setup.ps1` uses timing-based detection. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | L1: Add `[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture` or equivalent scope guard before `ConvertTo-Json` in `Write-StateAtomic`. L2: Have mock `win-play.ps1` write a sentinel file on completion; `Invoke-PeonHook` polls for sentinel instead of sleeping. | - [ ] Change plan is documented. |
| **3. Make Changes** | Apply locale guard and sentinel-file approach. | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run `Invoke-Pester -Path tests/` on Windows to confirm all tests pass. | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal hardening, no user-facing doc changes. | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR reviewed and merged. | - [ ] Changes are reviewed and merged. |

#### Work Notes

> L1 and L2 are both non-blocking — CI currently passes. These are robustness improvements.

**Commands/Scripts Used:**
```powershell
# Verify locale behavior
Invoke-Pester -Path tests/peon-engine.Tests.ps1
```

**Decisions Made:**
* Grouped as single card per planner instructions (both items from same review of 8ny6qr).

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Pending |
| **Files Modified** | `install.ps1`, `tests/windows-setup.ps1` |
| **Pull Request** | Pending |
| **Testing Performed** | Pending |

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
