# Improve lint-python-quoting hazard reporting and test scope

**When to use this template:** Fastfollow items from TECHDEBT-csedqi reviewer feedback.

---

## Task Overview

* **Task Description:** Two non-blocking improvements to `scripts/lint-python-quoting.sh` and `tests/lint-python-quoting.bats` flagged during review of card csedqi.
* **Motivation:** L1 improves developer experience by reporting all hazard sites per python3 -c block instead of only the first. L2 prevents future false-positives in BATS tests from test helper scripts.
* **Scope:** `scripts/lint-python-quoting.sh`, `tests/lint-python-quoting.bats`
* **Related Work:** Follow-up from TECHDEBT-csedqi (add CI lint check for python3 bash quoting hazards). See `.gitban/agents/planner/inbox/TECHDEBT-csedqi-planner-1.md`.
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
| **1. Review Current State** | L1: Lint currently stops at the first unescaped `"` in each python3 -c block. L2: `grep -rl --include='*.sh'` in the "all shell scripts" BATS test does not exclude `tests/` directory. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | L1: After finding first unescaped `"`, walk the rest of the line to report all hazard sites. L2: Add `--exclude-dir=tests` to the grep in the BATS test, or document why current behavior is safe. | - [ ] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal tooling only | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Reviewer items from TECHDEBT-csedqi-reviewer-1:
> - **L1:** Lint only reports the first hazard per python3 -c block. Walk the rest of the line after the first unescaped `"` to report all hazard sites for better developer experience.
> - **L2:** The `grep -rl --include='*.sh'` in the "all shell scripts" BATS test does not exclude the `tests/` directory. Currently safe because `.bats` files don't match `*.sh`, but future `.sh` test helpers with intentional bad patterns would false-positive. Add `--exclude-dir=tests` or document why this is safe.

**Commands/Scripts Used:**
```bash
# Files to modify
scripts/lint-python-quoting.sh
tests/lint-python-quoting.bats
```

**Decisions Made:**
* Both items are non-blocking improvements from reviewer feedback — grouped into a single fastfollow card per planner instructions.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | `scripts/lint-python-quoting.sh`, `tests/lint-python-quoting.bats` |
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

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
