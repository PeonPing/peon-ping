# Fix BATS test Python fallback timing division bug

---

## Task Overview

* **Task Description:** Fix the Python fallback path in the BATS timing computation in `tests/peon.bats`. The fallback (`python3 -c "import time; print(int(time.time()*1000))"`) produces milliseconds, but the outer arithmetic divides by 1,000,000 (correct for nanoseconds from `date +%s%N`, wrong for the Python fallback). On platforms where `date +%s%N` is unsupported and the Python fallback fires, both `start_ms` and `end_ms` would be near zero, making the timing assertion trivially true.
* **Motivation:** The timing assertion becomes meaningless on platforms that use the Python fallback (e.g., macOS without GNU coreutils), silently passing tests that should validate real timing behavior.
* **Scope:** `tests/peon.bats` — the timing computation that chooses between `date +%s%N` and Python fallback.
* **Related Work:** Flagged during TECHDEBT2 reviewer pass on qufq3f.
* **Estimated Effort:** 30 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Review the timing computation in `tests/peon.bats` to understand both code paths (nanosecond via `date +%s%N` and millisecond via Python fallback) | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Fix the division to handle both code paths correctly — either normalize both to the same unit before dividing, or use separate divisors per path | - [ ] Change plan is documented. |
| **3. Make Changes** | Update the timing logic in `tests/peon.bats` | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run `bats tests/peon.bats` and verify timing assertions pass correctly on both code paths | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> The root issue: `date +%s%N` returns nanoseconds, so dividing by 1,000,000 yields milliseconds. But the Python fallback already returns milliseconds, so dividing by 1,000,000 yields ~0, making any timing assertion trivially true.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | TBD |
| **Files Modified** | `tests/peon.bats` |
| **Pull Request** | TBD |
| **Testing Performed** | TBD |

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
