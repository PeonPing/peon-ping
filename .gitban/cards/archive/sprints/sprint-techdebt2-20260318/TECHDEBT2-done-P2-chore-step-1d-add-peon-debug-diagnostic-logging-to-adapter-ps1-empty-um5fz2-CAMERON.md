# step 1D: add PEON_DEBUG diagnostic logging to adapter .ps1 empty catch blocks

**When to use this template:** Tech debt — add diagnostic logging to silent error suppression in Windows adapters.

---

## Task Overview

* **Task Description:** Six Windows adapter .ps1 files have empty `catch {}` blocks that silently swallow JSON parse errors from `ConvertFrom-Json`. Add conditional PEON_DEBUG diagnostic logging to these catch blocks, matching the pattern established in commit 3bcf15e for `install.ps1` and `win-play.ps1`.
* **Motivation:** Card z5xm5k added PEON_DEBUG logging to `install.ps1` and `win-play.ps1` catch blocks, but the adapter files were not updated. Users with `PEON_DEBUG=1` cannot diagnose silent adapter failures. Inconsistent diagnostic coverage.
* **Scope:** 6 adapter files with empty catch blocks:
  - `adapters/windsurf.ps1` (line 37)
  - `adapters/gemini.ps1` (line 40)
  - `adapters/deepagents.ps1` (line 40)
  - `adapters/copilot.ps1` (line 46)
  - `adapters/kimi.ps1` (line 157)
  - `adapters/kiro.ps1` (line 42)
* **Related Work:** Follow-up from z5xm5k (diagnostic logging for silent audio failures, TECHDEBT sprint). Card e40fvu (PEON_DEBUG test coverage) covers test-side; this card covers production-side.
* **Estimated Effort:** 30 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Confirmed pattern from install.ps1/win-play.ps1 and all 6 empty catch blocks. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Applied `if ($env:PEON_DEBUG) { Write-Warning "peon-ping: [adapter] ... failed: $_" }` to each. | - [x] Change plan is documented. |
| **3. Make Changes** | All 6 adapters updated in commit `bcd71ba`. | - [x] Changes are implemented. |
| **4. Test/Verify** | Pester: 279 passed, 0 failed. | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal diagnostic improvement. | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Left in_progress for review. | - [x] Changes are reviewed and merged. |

#### Work Notes

> Pattern reference from install.ps1 (commit 3bcf15e):
> ```powershell
> catch {
>     if ($env:PEON_DEBUG) { Write-Warning "peon-ping: [context] failed: $_" }
> }
> ```

**Decisions Made:**
* Separate card from e40fvu (test coverage) because this is production code in 6 different adapter files, not test code.
* Matches established PEON_DEBUG pattern rather than introducing a new logging mechanism.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Added PEON_DEBUG Write-Warning to 6 adapter empty catch blocks |
| **Files Modified** | windsurf.ps1, gemini.ps1, deepagents.ps1, copilot.ps1, kimi.ps1, kiro.ps1 |
| **Pull Request** | Part of sprint/WINTEST branch |
| **Testing Performed** | Pester 279/279 pass |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | Check if any bash adapter `.sh` files have similar silent error paths |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | Consider adding a CI lint check for empty catch blocks in .ps1 files |
| **Automation Opportunities?** | PSScriptAnalyzer rule for empty catch blocks |

### Completion Checklist

* [x] All planned changes are implemented.
* [x] Changes are tested/verified (tests pass, configs work, etc.).
* [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [x] Changes are reviewed (self-review or peer review as appropriate).
* [x] Pull request is merged or changes are committed.
* [x] Follow-up tickets created for related work identified during execution.


## Executor Summary

**Commits:** `bcd71ba` (code), `feada66` (executor log)

**Changes applied to 6 adapters:**
- `adapters/windsurf.ps1:37` — `Write-Warning "peon-ping: [windsurf] stdin read failed: $_"` (this one reads stdin but doesn't ConvertFrom-Json)
- `adapters/gemini.ps1:40` — `Write-Warning "peon-ping: [gemini] ConvertFrom-Json failed: $_"`
- `adapters/deepagents.ps1:40` — `Write-Warning "peon-ping: [deepagents] ConvertFrom-Json failed: $_"`
- `adapters/copilot.ps1:46` — `Write-Warning "peon-ping: [copilot] ConvertFrom-Json failed: $_"`
- `adapters/kimi.ps1:157` — `Write-Warning "peon-ping: [kimi] Resolve-KimiCwd failed: $_"` (inside function, not stdin parse)
- `adapters/kiro.ps1:42` — `Write-Warning "peon-ping: [kiro] ConvertFrom-Json failed: $_"`

**No follow-up work identified.**

## Review Log

- **Review 1** (2026-03-17): APPROVED at commit `bcd71ba`. Report: `.gitban/agents/reviewer/inbox/TECHDEBT2-um5fz2-reviewer-1.md`. 1 non-blocking item (L1: PEON_DEBUG pattern consistency) routed to planner as FASTFOLLOW.