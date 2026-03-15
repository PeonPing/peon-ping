## Task Overview

* **Task Description:** Sweep all test fixture configs that still use `"active_pack": "peon"` and replace with `"default_pack": "peon"`. Dozens of test files have stale inline config JSON from before the SMARTPACK sprint renamed the key.
* **Motivation:** Tests pass today only because `peon.sh` has a `c.get('default_pack', c.get('active_pack', 'peon'))` fallback chain. If the fallback is ever removed, these stale fixtures will mask regressions. Cleaning them up ensures tests exercise the current config schema.
* **Scope:** Inline config JSON in test files: `tests/peon.bats`, `tests/wsl-toast.bats`, `tests/mac-overlay.bats`, `tests/relay.bats`, `tests/windsurf.bats`, `tests/kiro.bats`, `tests/install.bats`, `tests/install-windows.bats`, `tests/deepagents.bats`, `tests/copilot.bats`
* **Related Work:** Follow-up from card i0u93q (fix CI test 261 and 567 failures). Flagged as L1 non-blocking review item.
* **Estimated Effort:** 1-2 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Grep all test files for `active_pack` to get full count of occurrences | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Simple find-and-replace: `"active_pack"` → `"default_pack"` in inline config JSON | - [ ] Change plan is documented. |
| **3. Make Changes** | Replace all occurrences across the 10 test files listed in scope | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run `bats tests/` — all tests must still pass | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — test-only change | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Simple search-and-replace task. No logic changes needed — just updating fixture data to match the current config schema.

**Commands/Scripts Used:**
```bash
# Find all occurrences
grep -rn "active_pack" tests/

# Run tests after replacement
bats tests/
```

**Decisions Made:**
* Straight replacement — no need to keep any `active_pack` references in tests since the runtime fallback handles backward compat at the application level, not the test level.

**Issues Encountered:**
* None yet.

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
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | Consider adding a CI lint check for deprecated config keys in test fixtures |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
