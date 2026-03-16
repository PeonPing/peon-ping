# Tighten peon-security.Tests.ps1 assertion precision

**When to use this template:** FASTFOLLOW from reviewer feedback on jwh5zl (Step 2C security tests).

---

## Task Overview

* **Task Description:** Fix two imprecise test assertions in `tests/peon-security.Tests.ps1` flagged during code review of the WINTEST Step 2C security tests card (jwh5zl).
* **Motivation:** Current assertions have false-positive risk: one missing exit-code check masks a potential source bug, and one regex match is too loose and could pass on incorrect values.
* **Scope:** `tests/peon-security.Tests.ps1` (and potentially `scripts/hook-handle-use.ps1` if the exit-code bug is confirmed)
* **Related Work:** Review feedback on card jwh5zl (Step 2C). Reviewer card: `.gitban/agents/reviewer/inbox/WINTEST-q52ygy-reviewer-1.md`
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
| **1. Fix Scenario 5 exit code assertion** | Scenario 5 ("pack not found" in CLI mode) does not assert exit code. Add `$r.ExitCode | Should -Be 0` (documenting current behavior) or `Should -Be 1` if `hook-handle-use.ps1` is fixed. Investigate lines 110-123 of `scripts/hook-handle-use.ps1` — missing packs in CLI mode return exit 0 instead of exit 1, inconsistent with other CLI-mode errors (lines 76, 99). If the source is buggy, fix the source and assert exit 1. | - [ ] Exit code assertion added to Scenario 5. |
| **2. Fix Scenario 15 VLC gain regex** | Scenario 15 VLC gain assertion uses `Should -Match "--gain 1"` which also matches `--gain 10`, `--gain 100`, etc. Tighten to `"--gain 1(\.\d+)?(\s|$)"` or `"--gain 1\.0"`. | - [ ] VLC gain regex tightened in Scenario 15. |
| **3. Test/Verify** | Run `Invoke-Pester -Path tests/peon-security.Tests.ps1` and confirm all scenarios pass. | - [ ] Changes are tested/verified. |
| **4. Review/Merge** | Self-review or PR as appropriate. | - [ ] Changes are reviewed and merged. |

#### Work Notes

> **Item 1 detail (L1):** Scenario 5 verifies output text but does not check exit code for CLI-mode "pack not found". This also surfaces a potential source bug in `scripts/hook-handle-use.ps1` where missing packs in CLI mode return exit 0 instead of exit 1 (lines 110-123), inconsistent with other CLI-mode errors (lines 76, 99). If confirmed, fix the source and assert exit 1.
>
> **Item 2 detail (L2):** VLC gain assertion in Scenario 15 uses `Should -Match "--gain 1"` which would also match `--gain 10`, `--gain 100`, etc. Tighten to a pattern like `"--gain 1(\.\d+)?(\s|$)"` or `"--gain 1\.0"`.

**Decisions Made:**
* Grouped both items into one card per planner instructions (single file, related precision theme).

**Issues Encountered:**
* (none yet)

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | `tests/peon-security.Tests.ps1`, possibly `scripts/hook-handle-use.ps1` |
| **Pull Request** | |
| **Testing Performed** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | Possible source fix in hook-handle-use.ps1 (exit code for missing pack in CLI mode) |
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
