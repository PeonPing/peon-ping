# TDD Test Implementation for Trainer Hook Reminder Logic

**When to use this template:** Use this when you realize you didn't follow TDD properly, notice inadequate test coverage for a specific feature, or need to pause development to implement better tests for the code you're currently working on.

**When NOT to use this template:** Don't use this for comprehensive test audits, large-scale testing initiatives, or tests that are already part of your current TDD workflow. This is for targeted, immediate test improvements.

## Overview & Context for Trainer Hook Reminder Logic

* **Component/Feature:** Trainer reminder block in peon.ps1 (~130 lines) — hook-time logic that checks exercise goals, date resets, interval gating, slacking detection, and fires desktop notifications with progress summaries.
* **Related Work:** Origin: review feedback on card 2twy3o (WINTRAIN-2twy3o-planner-1.md, Card 2). Related: card yq8iba review routed L3 for trainer CLI subcommand tests — those are separate (CLI subcommands vs hook-time reminder logic) and should remain distinct cards.
* **Motivation:** The trainer reminder block (~130 lines in peon.ps1) shipped without Pester tests. This is a significant logic-heavy feature with multiple code paths that needs test coverage.

**Required Checks:**
* [x] Component or feature being tested is identified above.
* [x] Related work or original card is linked.
* [x] Clear motivation for pausing to add tests is documented.

---

## Initial Assessment

* The trainer reminder block shipped as part of card 2twy3o without Pester tests
* Multiple code paths need coverage: date reset, completion skip, interval gating, SessionStart bypass, slacking detection
* Manifest read failures need graceful degradation testing
* Zero-overhead path when trainer is disabled needs verification

### Current Test Coverage Analysis

| Test Type | Current Coverage | Gap Identified | Priority |
| :--- | :--- | :--- | :---: |
| **Unit Tests** | 0% — no Pester tests for trainer reminder logic | All reminder code paths untested | P1 |
| **Integration Tests** | None | No end-to-end trainer hook invocation tests | P2 |
| **Edge Cases** | None | Manifest read failures, zero-config, disabled state | P1 |

---

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | Create test file (tests/trainer-windows.Tests.ps1 or extend tests/adapters-windows.Tests.ps1) | - [ ] Failing tests are written and committed. |
| **2. Implement Code** | N/A — code already exists, tests are being added retroactively | - [ ] Minimal code to make tests pass is implemented. |
| **3. Verify Tests Pass** | Run `Invoke-Pester` against new test cases | - [ ] All new tests are passing. |
| **4. Refactor** | Refactor test helpers if needed for reuse | - [ ] Code is refactored for quality (or N/A is documented). |
| **5. Regression Check** | Run full Pester suite | - [ ] Full test suite passes with no regressions. |

### Test Cases Defined

| Test Case # | Description | Input | Expected Output | Status |
| :---: | :--- | :--- | :--- | :---: |
| **1** | Date reset — new day resets daily counters | State with yesterday's date, new invocation today | `trainer.today` updated, counters reset | Not Started |
| **2** | Completion skip — no reminder when daily goal already met | State showing goal completed | No notification fired, early return | Not Started |
| **3** | Interval gating — reminder suppressed within cooldown window | State with recent `last_reminder_ts` | No notification fired | Not Started |
| **4** | Interval gating — reminder fires after cooldown expires | State with old `last_reminder_ts` | Notification fired, timestamp updated | Not Started |
| **5** | SessionStart bypass — no trainer reminder on session start events | SessionStart CESP event | Trainer block skipped entirely | Not Started |
| **6** | Slacking detection threshold — triggers slacking message | State with low reps and enough elapsed time | Slacking notification content | Not Started |
| **7** | Manifest read failure — graceful degradation | Missing or corrupt openpeon.json | No crash, trainer block skipped gracefully | Not Started |
| **8** | Zero overhead when disabled — trainer.enabled=false | Config with trainer.enabled=false | Single boolean check, no further processing | Not Started |

#### Test Implementation Notes (Optional)

> Tests should mock the state file, config, and notification calls. The trainer logic is embedded in peon.ps1 within install.ps1, so tests will need to either extract the logic into a testable function or source the relevant section. Consider whether tests belong in `tests/adapters-windows.Tests.ps1` (extending existing) or a new `tests/trainer-windows.Tests.ps1` file — decide based on test isolation needs.

---

## Test Execution & Verification

| Iteration # | Test Batch | Action Taken | Outcome |
| :---: | :--- | :--- | :--- |
| **1** | TBD | TBD | TBD |

---

## Coverage Verification

| Metric | Before | After | Target Met? |
| :--- | :---: | :---: | :---: |
| **Line Coverage** | 0% | TBD | TBD |
| **Branch Coverage** | 0% | TBD | TBD |
| **Test Count** | 0 | TBD | TBD |

* [ ] Coverage report generated and reviewed.
* [ ] All critical paths are now tested.
* [ ] Edge cases identified in assessment are covered.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | TBD |
| **CI/CD Verification** | TBD |
| **Coverage Report** | TBD |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Similar Gaps Elsewhere?** | Card yq8iba L3 routed trainer CLI subcommand tests — separate scope (CLI vs hook-time), keep as distinct cards |
| **Process Improvement** | N/A |
| **Future Refactoring** | Card zolklp (extract Format-TrainerBar helper) depends on trainer Pester tests existing first |
| **Documentation Updates** | N/A |

### Completion Checklist

* [ ] All test cases defined in the table are implemented.
* [ ] All tests are passing.
* [ ] Code coverage meets or exceeds target for this component.
* [ ] Full regression suite passes with no failures.
* [ ] Code is refactored and clean.
* [ ] Changes are committed and pushed.
* [ ] Follow-up actions are documented or tickets created.
* [ ] Original work (feature/bug) can be resumed with confidence.
