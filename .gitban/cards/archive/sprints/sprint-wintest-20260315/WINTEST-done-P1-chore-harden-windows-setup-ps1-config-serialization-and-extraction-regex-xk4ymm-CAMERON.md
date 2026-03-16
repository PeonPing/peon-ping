# Harden windows-setup.ps1 config serialization and extraction regex

**When to use this template:** Fast-follow hardening for `tests/windows-setup.ps1` — two non-blocking issues flagged during review of WINTEST step 1.

---

## Task Overview

* **Task Description:** Fix two fragility issues in `tests/windows-setup.ps1`: (1) locale-dependent decimal separator corruption in config serialization, and (2) brittle here-string extraction regex that assumes a single match in `install.ps1`.
* **Motivation:** The current regex `(?<=\d),(?=\d)` that fixes decimal commas from `ConvertTo-Json` on non-English locales would also corrupt integer arrays like `[1,2,3]` → `[1.2.3]`. The extraction regex `hookScript = @'(.+?)'@` assumes exactly one here-string in `install.ps1`, which will silently break if a second is added.
* **Scope:** `tests/windows-setup.ps1`
* **Related Work:** Flagged during review of card q52ygy (WINTEST step 1)
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
| **1. Review Current State** | **Item A — Locale decimal separator:** The regex `(?<=\d),(?=\d)` in config serialization replaces commas between digits with dots to fix `ConvertTo-Json` decimal output on non-English locales. However, this also corrupts integer arrays like `[1,2,3]` → `[1.2.3]`. **Item B — Extraction regex:** The regex `hookScript = @'(.+?)'@` assumes exactly one here-string in `install.ps1`. A second here-string would cause silent misextraction. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | **Item A fix options:** Either force `CurrentCulture` to invariant before serialization, or target only the `volume` key specifically instead of blanket digit-comma-digit replacement. **Item B fix:** Anchor the extraction regex on a unique marker comment inside the here-string (e.g., `# peon-ping hook for Claude Code`) so that adding a second here-string to `install.ps1` does not silently break extraction. | - [x] Change plan is documented. |
| **3. Make Changes** | Implement chosen fixes in `tests/windows-setup.ps1` | - [x] Changes are implemented. |
| **4. Test/Verify** | Run `Invoke-Pester -Path tests/adapters-windows.Tests.ps1` and any new test files to verify no regressions | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal test harness | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [x] Changes are reviewed and merged. |

#### Work Notes

> Use this space for any additional notes, commands run, decisions made, or issues encountered during the work.

**Item A — Locale-dependent decimal separator:**
- File: `tests/windows-setup.ps1`
- Current regex: `(?<=\d),(?=\d)` applied to full JSON output
- Problem: Corrupts integer arrays `[1,2,3]` → `[1.2.3]`
- Preferred fix: Force `[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture` before `ConvertTo-Json`, or scope the replacement to only the `volume` key

**Item B — Extraction regex fragility:**
- File: `tests/windows-setup.ps1`
- Current regex: `hookScript = @'(.+?)'@`
- Problem: Assumes exactly one here-string in `install.ps1`
- Fix: Add a unique marker comment (e.g., `# peon-ping hook for Claude Code`) inside the here-string in `install.ps1` and anchor the regex on that marker

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | (A) Replaced brittle `(?<=\d),(?=\d)` regex with InvariantCulture enforcement around ConvertTo-Json. (B) Anchored here-string extraction regex on `# peon-ping hook for Claude Code` marker comment. |
| **Files Modified** | `tests/windows-setup.ps1` |
| **Pull Request** | Pending merge to sprint/WINTEST |
| **Testing Performed** | adapters-windows.Tests.ps1: 204 passed, 0 failed. peon-engine.Tests.ps1: 46 passed, 0 failed, 1 skipped (pre-existing). |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [x] All planned changes are implemented.
* [x] Changes are tested/verified (tests pass, configs work, etc.).
* [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [x] Changes are reviewed (self-review or peer review as appropriate).
* [x] Pull request is merged or changes are committed.
* [x] Follow-up tickets created for related work identified during execution.


## Executor Work Summary

Commit: `374fcd2` fix: harden windows-setup.ps1 config serialization and extraction regex\n\n**Summary:**\n- Item A: Replaced `(?<=\\d),(?=\\d)` regex with `[System.Threading.Thread]::CurrentThread.CurrentCulture = InvariantCulture` before `ConvertTo-Json`, then restored the original culture afterward. This prevents integer array corruption like `[1,2,3]` -> `[1.2.3]`.\n- Item B: Changed extraction regex from `hookScript = @'(.+?)'@` to `hookScript = @'(\\r?\\n# peon-ping hook for Claude Code.+?)'@`, anchoring on the existing marker comment at line 314 of install.ps1. A second here-string in install.ps1 will no longer cause silent misextraction.\n- All 250 Pester tests pass (204 adapter + 46 engine)."

## Review Log

| Review | Verdict | Date | Report |
| :---: | :--- | :--- | :--- |
| 1 | APPROVAL | 2026-03-15 | `.gitban/agents/reviewer/inbox/WINTEST-xk4ymm-reviewer-1.md` |

Routed to executor: `.gitban/agents/executor/inbox/WINTEST-xk4ymm-executor-1.md`
