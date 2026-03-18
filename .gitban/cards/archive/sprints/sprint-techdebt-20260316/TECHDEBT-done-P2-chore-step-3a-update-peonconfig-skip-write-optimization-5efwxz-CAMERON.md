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
| **1. Review Current State** | No `Update-PeonConfig` function exists. Config writes use inline regex-replace + `Set-Content` across 7 CLI command sites in `install.ps1`. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Approach (2) variant: compare raw string before/after regex replacement (no double-serialization cost since we already have both strings). Skip `Set-Content` when identical. | - [x] Change plan is documented. |
| **3. Make Changes** | All 7 write sites guarded: toggle, pause, resume, packs use, packs next, pack, volume. | - [x] Changes are implemented. |
| **4. Test/Verify** | Pester tests pass: 204/204 passed, 0 failed. | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal optimization, no user-facing doc changes. | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [x] Changes are reviewed and merged. |

#### Work Notes

> Suggested approaches from reviewer:
> 1. Have the mutator return a changed flag (e.g., return `$true`/`$false`)
> 2. Compare before/after JSON (`ConvertTo-Json`) to skip write when identical
>
> Approach (2) is simpler but has a minor cost of double-serialization. Approach (1) is more explicit but requires updating all existing mutator callsites.

**Decisions Made:**
* Approach (2) variant chosen: compare raw string before/after regex replacement. Zero extra cost since both strings are already in memory from the `-replace` operation. No mutator return-value changes needed, no callsite updates required.

**Issues Encountered:**
* The card references `Update-PeonConfig` but no such function exists in the codebase. The actual pattern is inline regex replacements across 7 CLI command handlers in `install.ps1`.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Added skip-write guard (`if ($updated -ne $raw)`) to all 7 config write sites in CLI command handlers |
| **Files Modified** | `install.ps1` (lines 354-475, 7 write sites) |
| **Pull Request** | Pending review |
| **Testing Performed** | Pester `adapters-windows.Tests.ps1`: 204/204 passed |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Executor Summary

**Commit:** `ec12caa` — fix: skip redundant config writes in peon CLI commands

**What was done:**
- Reviewed all config write sites in `install.ps1` CLI command handlers (7 total)
- Added skip-write optimization: compare raw string before/after regex replacement, only call `Set-Content` when the content actually changed
- This eliminates unnecessary disk I/O when a CLI command sets a value already at the target (e.g. `peon --pause` when already paused, `peon --volume 0.5` when already at 0.5, `peon packs use X` when X is already active)
- All 204 Pester tests pass

**Approach chosen:** Variant of approach (2) from reviewer notes. Instead of double-serializing via `ConvertTo-Json`, we compare the raw string before and after the `-replace` operation. Both strings are already in memory, so the comparison is effectively free.

**Remaining:** Checkbox 5 (PR merge) and checkbox 6 (follow-up tickets) left for review/merge phase.

## Review Log

| Review | Verdict | Commit | Report |
| :---: | :--- | :--- | :--- |
| 1 | APPROVAL | `ec12caa` | `.gitban/agents/reviewer/inbox/TECHDEBT-5efwxz-reviewer-1.md` |

**Routed:** Executor instructions at `.gitban/agents/executor/inbox/TECHDEBT-5efwxz-executor-1.md`. One non-blocking FASTFOLLOW item routed to planner at `.gitban/agents/planner/inbox/TECHDEBT-5efwxz-planner-1.md`.
