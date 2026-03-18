# Deduplicate install.ps1 shared functions and hoist peonDebug

## Task Overview

* **Task Description:** Two cleanup items in `install.ps1` and `install-utils.ps1`: (1) `Get-PeonConfigRaw` is defined in `install-utils.ps1` (dot-sourced at line 18) and redeclared in `install.ps1` at line 326 — the hook-mode version is intentionally simpler (no locale repair), but `Get-ActivePack` at line 333 is identical to the utils version. Consider parameterizing `Get-PeonConfigRaw` with a `-Repair` switch to eliminate redeclaration, or extract hook-mode's version as `Get-PeonConfigRawFast` in the utils file. (2) `$peonDebug` is assigned at line 323 (CLI command mode) and again at line 730 (hook mode) in the same PowerShell scope, making the second assignment redundant. Hoist the single declaration above both code paths, or move it into a shared init block.
* **Motivation:** Reduces code duplication and eliminates a redundant variable assignment, making `install.ps1` easier to maintain and less error-prone when modifying debug or config-read logic.
* **Scope:** `install.ps1`, `install-utils.ps1`
* **Related Work:** Identified during review 3 of card f4w9gu (techdebt2 sprint cleanup). A third item from the same review (volume regex trailing comma, L3) was deduplicated — already captured in card `cb0gpg`.
* **Estimated Effort:** 30 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Review `Get-PeonConfigRaw` in both `install-utils.ps1` and `install.ps1` (line 326); review `Get-ActivePack` (line 333) for identical duplication; review `$peonDebug` assignments at lines 323 and 730 | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | L1: Either parameterize `Get-PeonConfigRaw` with `-Repair` switch or extract `Get-PeonConfigRawFast` into utils. Remove duplicate `Get-ActivePack`. L2: Hoist `$peonDebug` to a single declaration above both CLI and hook code paths. | - [ ] Change plan is documented. |
| **3. Make Changes** | Apply refactoring to `install.ps1` and `install-utils.ps1` | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run Pester tests (`adapters-windows.Tests.ps1`) and manual smoke test of CLI and hook modes | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal refactor, no user-facing doc changes | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Two items from review 3 of f4w9gu:
> - **L1 (function dedup):** `Get-PeonConfigRaw` has two definitions — full (with locale repair) in `install-utils.ps1` and slim (no repair) in `install.ps1` hook-mode section. `Get-ActivePack` is identical in both. Options: (a) add `-Repair` switch to single definition, (b) extract `Get-PeonConfigRawFast` into utils.
> - **L2 ($peonDebug hoist):** Same variable set twice in same scope at lines 323 and 730. Second is redundant.
> - **L3 (volume regex):** Deduplicated — already tracked in card `cb0gpg`.

**Commands/Scripts Used:**
```powershell
# Verify Pester tests pass after changes
Invoke-Pester -Path tests/adapters-windows.Tests.ps1
```

**Decisions Made:**
* L3 (volume regex trailing comma) not included — already captured in card cb0gpg.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | `install.ps1`, `install-utils.ps1` |
| **Pull Request** | |
| **Testing Performed** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
