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
| **1. Review Current State** | Review `Get-PeonConfigRaw` in both `install-utils.ps1` and `install.ps1` (line 326); review `Get-ActivePack` (line 333) for identical duplication; review `$peonDebug` assignments at lines 323 and 730 | - [x] Current state is understood and documented. |
| **2. Plan Changes** | L1: Duplication is architecturally required (hook is self-contained, no dot-source at runtime). No change needed. L2: Remove redundant `$peonDebug` at line 730; line 323 already covers both paths. | - [x] Change plan is documented. |
| **3. Make Changes** | Removed redundant `$peonDebug = $env:PEON_DEBUG -eq "1"` at line 730 of `install.ps1`. No changes to `install-utils.ps1` (L1 dedup not needed). | - [x] Changes are implemented. |
| **4. Test/Verify** | Pester: adapters-windows (336/336 pass), peon-debug (14/14 pass) | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal refactor, no user-facing doc changes | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [x] Changes are reviewed and merged. |

#### Work Notes

> **Review cycle 2 investigation (actual file reads):**
>
> **L1 (function dedup):** `scripts/install-utils.ps1` exists and is dot-sourced at line 19 of `install.ps1`. It defines `Get-PeonConfigRaw` (with locale repair: fixes `0,5` to `0.5` and missing volume values), `Get-ActivePack`, and `Test-Safe*` validation functions. The `$hookScript` here-string (lines 326-337) redefines `Get-PeonConfigRaw` (simpler, no locale repair) and `Get-ActivePack` (identical logic). This duplication is **architecturally required**: the installed hook script is written as a standalone `.ps1` file and cannot dot-source `install-utils.ps1` at runtime. The hook's `Get-PeonConfigRaw` is intentionally simpler because locale repair is done at install/update time, so the hook only needs a plain read.
>
> **L2 ($peonDebug hoist):** `$peonDebug = $env:PEON_DEBUG -eq "1"` appears at line 323 (top of `$hookScript`, before `if ($Command)` branch) and again at line 730 (start of hook mode section). Since line 323 executes unconditionally before both the CLI branch (line 340) and the hook branch (line 729), the assignment at line 730 is redundant. Removed.
>
> **L3 (volume regex):** Already tracked in card `cb0gpg`.

**Commands/Scripts Used:**
```powershell
# Verify Pester tests pass after changes
Invoke-Pester -Path tests/adapters-windows.Tests.ps1
```

**Decisions Made:**
* L3 (volume regex trailing comma) not included — already captured in card cb0gpg.

**Issues Encountered:**
* Review 1 rejected: executor fabricated claims that `$peonDebug` and `install-utils.ps1` did not exist. Corrected in review cycle 2 by actually reading the files.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Removed redundant `$peonDebug` assignment at line 730 of `install.ps1`. L1 function dedup confirmed architecturally required (no change needed). |
| **Files Modified** | `install.ps1` |
| **Pull Request** | Part of sprint/WINTEST |
| **Testing Performed** | Pester: adapters-windows (336 pass), peon-debug (14 pass) |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |
| **Automation Opportunities?** | N/A |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Executor Summary (Review Cycle 2)

**Commit:** `cf03ffc` — fix: remove redundant $peonDebug assignment in install.ps1 hook mode

**What was done:**
- **B1 (L2 fix):** Removed the redundant `$peonDebug = $env:PEON_DEBUG -eq "1"` at line 730 of `install.ps1`. The assignment at line 323 (top of the `$hookScript` here-string) already executes unconditionally before both the CLI branch (`if ($Command)` at line 340) and the hook mode section (line 729+), making the second assignment a no-op.
- **B2 (L1 re-investigation):** Confirmed that `scripts/install-utils.ps1` exists and is dot-sourced at line 19 of `install.ps1`. It defines `Get-PeonConfigRaw` (with locale repair), `Get-ActivePack`, and `Test-Safe*` functions. The `$hookScript` here-string redefines `Get-PeonConfigRaw` (simpler, no locale repair — repair is done at install/update time) and `Get-ActivePack` (identical logic). This duplication is architecturally required: the installed hook is written as a standalone `.ps1` file that cannot dot-source utility files at runtime.

**Tests:** adapters-windows (336/336 pass), peon-debug (14/14 pass)


## Review Log

| Review 2 | APPROVAL | `.gitban/agents/reviewer/inbox/WINTEST-od5a0c-reviewer-2.md` | Routed to executor: `.gitban/agents/executor/inbox/WINTEST-od5a0c-executor-2.md` |