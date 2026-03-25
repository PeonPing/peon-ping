# TDD Test Implementation for Trainer CLI Subcommands (Windows)

## Overview & Context for Trainer CLI Subcommands

* **Component/Feature:** Trainer CLI subcommands in `peon.ps1` (native Windows): `on`, `off`, `status`, `log`, `goal`, `help`
* **Related Work:** Card yq8iba (step-1-trainer-cli-subcommands-in-peon-ps1) — trainer was ported without Pester tests, explicitly deferred to follow-up.
* **Motivation:** The trainer subcommands were ported from bash to PowerShell without accompanying Pester tests. The card explicitly deferred tests to "step 3." This card fulfills that commitment.

**Required Checks:**
* [ ] Component or feature being tested is identified above.
* [ ] Related work or original card is linked.
* [ ] Clear motivation for pausing to add tests is documented.

---

## Initial Assessment

* Gap: Trainer subcommands (`on`, `off`, `status`, `log`, `goal`, `help`) have zero Pester test coverage.
* Reference: BATS tests exist in `tests/trainer.bats` — Pester tests should match that coverage.
* Files: Tests should go in `tests/adapters-windows.Tests.ps1` (existing) or a new `tests/trainer-windows.Tests.ps1`.

### Current Test Coverage Analysis

| Test Type | Current Coverage | Gap Identified | Priority |
| :--- | :--- | :--- | :---: |
| **Unit Tests** | 0% — no Pester tests for trainer subcommands | All trainer subcommands untested on Windows | P2 |
| **Integration Tests** | None | No end-to-end trainer workflow tests | P2 |
| **Edge Cases** | None | No tests for invalid inputs, missing config, boundary values | P2 |

---

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | Not started | - [ ] Failing tests are written and committed. |
| **2. Implement Code** | N/A — code already exists, tests are catching up | - [ ] Minimal code to make tests pass is implemented. |
| **3. Verify Tests Pass** | Not started | - [ ] All new tests are passing. |
| **4. Refactor** | N/A | - [ ] Code is refactored for quality (or N/A is documented). |
| **5. Regression Check** | Not started | - [ ] Full test suite passes with no regressions. |

### Test Cases Defined

| Test Case # | Description | Input | Expected Output | Status |
| :---: | :--- | :--- | :--- | :---: |
| **1** | `peon trainer on` enables trainer | subcommand `on` | Config updated, confirmation message | Not Started |
| **2** | `peon trainer off` disables trainer | subcommand `off` | Config updated, confirmation message | Not Started |
| **3** | `peon trainer status` shows progress | subcommand `status` | Progress bar, rep count, goal display | Not Started |
| **4** | `peon trainer log` records reps | subcommand `log 25 pushups` | State updated, progress bar shown | Not Started |
| **5** | `peon trainer goal` sets daily goal | subcommand `goal 100` | Config updated, confirmation | Not Started |
| **6** | `peon trainer help` shows usage | subcommand `help` | Help text printed | Not Started |
| **7** | `peon trainer log` with invalid input | subcommand `log abc` | Error message | Not Started |
| **8** | `peon trainer status` with no activity | subcommand `status` when no reps logged | Empty/zero progress display | Not Started |

#### Test Implementation Notes

Reference `tests/trainer.bats` for expected behaviors to mirror. Tests should use isolated temp directories with mock config/state files, similar to the BATS test setup pattern.

---

## Test Execution & Verification

| Iteration # | Test Batch | Action Taken | Outcome |
| :---: | :--- | :--- | :--- |
| **1** | Not started | | |

---

## Coverage Verification

| Metric | Before | After | Target Met? |
| :--- | :---: | :---: | :---: |
| **Line Coverage** | 0% | TBD | N |
| **Test Count** | 0 | TBD | N |

* [ ] Coverage report generated and reviewed.
* [ ] All critical paths are now tested.
* [ ] Edge cases identified in assessment are covered.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | TBD |
| **CI/CD Verification** | TBD — should pass in GitHub Actions Windows job |
| **Coverage Report** | TBD |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Similar Gaps Elsewhere?** | Check other Windows PowerShell features without Pester coverage |
| **Process Improvement** | Ensure future Windows ports include Pester tests from the start |

### Completion Checklist

* [ ] All test cases defined in the table are implemented.
* [ ] All tests are passing.
* [ ] Code coverage meets or exceeds target for this component.
* [ ] Full regression suite passes with no failures.
* [ ] Code is refactored and clean.
* [ ] Changes are committed and pushed.
* [ ] Follow-up actions are documented or tickets created.
* [ ] Original work (feature/bug) can be resumed with confidence.
