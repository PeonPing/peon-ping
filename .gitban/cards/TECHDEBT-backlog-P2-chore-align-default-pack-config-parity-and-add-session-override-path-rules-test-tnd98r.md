# Align default_pack config parity and add session_override + path_rules test

## Task Overview

* **Task Description:** Two non-blocking items from the rd6fu4 review: (1) Add `default_pack` config key support to `peon.ps1` for parity with `peon.sh`, and (2) add a test covering the `session_override + path_rules` interaction in pack selection.
* **Motivation:** The Python reference in `peon.sh` checks `cfg.get('default_pack', cfg.get('active_pack', 'peon'))`, supporting a `default_pack` key distinct from `active_pack`. The PS1 engine only checks `active_pack`, creating a config parity gap. Additionally, the `session_override + path_rules` fallback integration point has no dedicated test coverage despite working correctly in production code.
* **Scope:** `install.ps1` (embedded `peon.ps1`), `tests/peon-packs.Tests.ps1`
* **Related Work:** Follow-up from card rd6fu4 (port path_rules to peon.ps1). Reviewer flagged these as non-blocking FASTFOLLOW items.
* **Estimated Effort:** 2-3 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | L1: `peon.ps1` only checks `$cfg.active_pack` — missing `default_pack` fallback that `peon.sh` Python block implements. L2: `$pathRulePack` is correctly integrated into session_override fallback chain but no test exercises the combined path. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | L1: In `peon.ps1` pack resolution, add `default_pack` config key lookup with fallback to `active_pack` then `'peon'`, matching Python logic. L2: Add Pester test in `peon-packs.Tests.ps1` where session pack is missing and a path_rule matches, confirming the integration point. | - [ ] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal config parity, no user-facing doc changes expected. | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Items from rd6fu4 reviewer dispatch (TECHDEBT-rd6fu4-planner-1.md):
> - L1: `default_pack` config key not supported in peon.ps1
> - L2: No test for path_rules + session_override interaction

**Decisions Made:**
* Grouped as single card per planner instructions (both items are small, related to pack selection logic in peon.ps1).

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | |
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
