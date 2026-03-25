# Add CI lint check for python3 bash quoting hazards

**When to use this template:** CI regression prevention for the class of bugs fixed in card dsmh31.

---

## Task Overview

* **Task Description:** Add a CI lint check (shellcheck custom rule or BATS test) that detects `python3 -c "` blocks containing `["` or `.get("` patterns in `peon.sh`, to prevent regression of the bash double-quoting hazard bug class fixed in card dsmh31.
* **Motivation:** Card dsmh31 fixed quoting hazards across 61 python3 -c blocks in peon.sh. Its "Process Improvements" section identified the opportunity to add automated regression detection so these bugs cannot be reintroduced.
* **Scope:** CI config (new workflow or extension of existing), potentially `tests/` for a BATS-based approach.
* **Related Work:** Follow-up from dsmh31 (audit peon.sh python blocks for bash double-quoting hazards).
* **Estimated Effort:** 2-4 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Review dsmh31 fix patterns and identify the exact regex/pattern that catches the quoting hazard | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Decide approach: shellcheck directive, BATS test scanning peon.sh, or GitHub Actions grep step | - [ ] Change plan is documented. |
| **3. Make Changes** | Implement the lint check in CI or tests/ | - [ ] Changes are implemented. |
| **4. Test/Verify** | Verify the check catches known-bad patterns (e.g., `python3 -c "...["...` ) and passes on correct code | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | Update CHANGELOG.md if adding a new CI check | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> The specific patterns to detect are `python3 -c "` blocks that contain unescaped `["` or `.get("` inside bash double-quoted strings. These cause bash to interpret the quotes prematurely, breaking the python code.

**Commands/Scripts Used:**
```bash
# Example approach: BATS test that greps peon.sh for hazardous patterns
# Look for python3 -c " blocks containing [" or .get(" without proper escaping
```

**Decisions Made:**
* Approach TBD: shellcheck custom rule vs BATS test vs CI grep step

**Issues Encountered:**
* None yet

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | TBD |
| **Files Modified** | TBD |
| **Pull Request** | TBD |
| **Testing Performed** | TBD |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | TBD |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | This card IS the process improvement from dsmh31 |
| **Automation Opportunities?** | The entire card is about automation |

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
