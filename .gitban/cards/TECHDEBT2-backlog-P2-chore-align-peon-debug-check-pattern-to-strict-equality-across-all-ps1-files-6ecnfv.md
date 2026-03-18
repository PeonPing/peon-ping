# Align PEON_DEBUG check pattern to strict equality across all .ps1 files

## Task Overview

* **Task Description:** Standardize the `PEON_DEBUG` environment variable check across all `.ps1` files to use the strict equality pattern `$peonDebug = $env:PEON_DEBUG -eq "1"` instead of the truthy `if ($env:PEON_DEBUG)` pattern.
* **Motivation:** The adapters use `if ($env:PEON_DEBUG)` which is truthy for any non-empty string including `"0"` and `"false"`, causing unexpected debug warnings. `install.ps1` and `win-play.ps1` already use the stricter `$env:PEON_DEBUG -eq "1"` pattern. The codebase should be consistent and use the strict form everywhere.
* **Scope:** `adapters/windsurf.ps1`, `adapters/gemini.ps1`, `adapters/deepagents.ps1`, `adapters/copilot.ps1`, `adapters/kimi.ps1`, `adapters/kiro.ps1`, `install.ps1`, `scripts/win-play.ps1`
* **Related Work:** Flagged during reviewer pass on card um5fz2 (PEON_DEBUG diagnostic logging). Follow-up from TECHDEBT2 sprint.
* **Estimated Effort:** 1 hour

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Audit all `.ps1` files for `PEON_DEBUG` usage patterns. Identify which files use truthy check vs strict equality. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Replace all `if ($env:PEON_DEBUG)` patterns with `$peonDebug = $env:PEON_DEBUG -eq "1"` and update downstream references. | - [ ] Change plan is documented. |
| **3. Make Changes** | Update each adapter file to use strict equality pattern. | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run Pester tests (`Invoke-Pester -Path tests/adapters-windows.Tests.ps1`) to confirm no regressions. | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal implementation detail, no user-facing doc changes. | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge. | - [ ] Changes are reviewed and merged. |

#### Work Notes

> The canonical pattern to adopt everywhere is:
> ```powershell
> $peonDebug = $env:PEON_DEBUG -eq "1"
> if ($peonDebug) { Write-Warning "..." }
> ```
> This matches the established pattern in `install.ps1` and `scripts/win-play.ps1`.

**Decisions Made:**
* Strict equality (`-eq "1"`) is preferred over truthy check to avoid unexpected debug output when `PEON_DEBUG` is set to `"0"` or `"false"`.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | [Pending] |
| **Files Modified** | [Pending] |
| **Pull Request** | [Pending] |
| **Testing Performed** | [Pending] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | Consider adding a lint rule to catch truthy env var checks in future. |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
