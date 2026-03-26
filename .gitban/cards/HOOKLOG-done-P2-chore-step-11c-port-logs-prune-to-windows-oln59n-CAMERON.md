# step 11C: Port `peon logs --prune` to Windows

## Task Overview

* **Task Description:** `peon logs --prune` exists in `peon.sh` (line 3106) but is missing from `peon.ps1`. Port it so Windows users can manually prune log files older than `debug_retention_days`.
* **Motivation:** Smoke test finding (card 6qfugq). Running `peon logs --prune` on Windows prints usage and exits — the flag isn't recognized. Auto-pruning on hook invocation may already work, but the manual CLI command is missing.
* **Scope:** `install.ps1` logs command handler, completions (if applicable on Windows), Pester test.
* **Related Work:** HOOKLOG sprint, card px9k89 (implemented --prune on Unix).

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
|:-----|:---------------|:---------------:|
| **1. Review Unix implementation** | peon.sh:3106-3130: reads `debug_retention_days` from config, lists log files, deletes those with date older than retention. Reports count deleted. | - [x] Current state is understood and documented. |
| **2. Find Windows logs handler** | install.ps1:1130-1260: `logs` case block has `--clear`, `--last`, `--session` cases in a `switch -Regex`. Added `--prune` before `default`. | - [x] Current state is understood and documented. |
| **3. Implement --prune** | Reads `debug_retention_days` from config via `Get-PeonConfigRaw`, computes cutoff date string, iterates log files comparing `BaseName -replace 'peon-ping-',''` to cutoff, deletes older files, reports count. | - [x] Changes are implemented. |
| **4. Add Pester test** | 5 tests in `tests/debug-logs-windows.Tests.ps1`: pruning old files, no-old-files, no-directory, custom retention days, single-today-file. | - [x] Changes are tested/verified. |
| **5. Verify** | `Invoke-Pester` — 39/39 passed (including 5 new --prune tests). | - [x] Changes are tested/verified. |

#### Required Reading

| File | Location | What to look for |
|:-----|:---------|:-----------------|
| `peon.sh` | Lines 3106-3130 | Unix `--prune` implementation |
| `install.ps1` | Logs command handler | `--last`, `--session`, `--clear` cases — add `--prune` alongside |
| `tests/debug-logs-windows.Tests.ps1` | Existing tests | Pattern for logs CLI Pester tests |

---

## Completion & Follow-up

| Task | Detail/Link |
|:-----|:------------|
| **Changes Made** | Added `--prune` case to logs CLI handler, updated help text, added 5 Pester tests, updated help assertion |
| **Files Modified** | `install.ps1`, `tests/debug-logs-windows.Tests.ps1` |
| **Pull Request** | Sprint PR #405 |
| **Testing Performed** | Invoke-Pester 39/39 pass |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
|:------|:------------------------|
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No — --prune is already documented in README from the Unix implementation |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |


## Work Summary

Commit `173d2b6` on branch `worktree-agent-ac6c5faa`.

**What was done:**
- Added `--prune` case to the `logs` switch block in `install.ps1` (line ~1232), mirroring the Unix implementation in `peon.sh`
- Reads `debug_retention_days` from config (defaults to 7), computes a cutoff date string, compares log filenames via string comparison, deletes older files
- Updated the usage string in the `default` case to include `--prune`
- Added `logs --prune` to the `--help` output
- Added 5 Pester tests covering: pruning old files, no old files, no directory, custom retention, single today file
- Updated help assertion test to verify `--prune` appears in help output
- All 39 Pester tests pass

**No follow-up needed:** Bash/fish completions already include `--prune` from the Unix implementation. README already documents `--prune` from the Unix side. No new CLI commands or config keys added.

## Review Log

| Review 1 | APPROVAL | Commit a016ec1 | `.gitban/agents/reviewer/inbox/HOOKLOG-oln59n-reviewer-1.md` | Routed to executor: `.gitban/agents/executor/inbox/HOOKLOG-oln59n-executor-1.md` |