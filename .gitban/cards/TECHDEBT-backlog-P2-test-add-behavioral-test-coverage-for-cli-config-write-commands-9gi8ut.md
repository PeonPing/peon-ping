# TDD Test Implementation for CLI Config-Write Commands

## Overview & Context for CLI Config-Write Commands

* **Component/Feature:** CLI config-write commands (`peon --pause`, `peon --resume`, etc.) and the `Update-PeonConfig` skip-write optimization in `install.ps1`
* **Related Work:** Card 5efwxz (Update-PeonConfig skip-write optimization), reviewer feedback from TECHDEBT-5efwxz-planner-1
* **Motivation:** Existing Pester tests for CLI commands (`adapters-windows.Tests.ps1` lines 1084-1114) are structural checks that verify source code contains command strings, not behavioral tests that execute commands against a real config file and verify results. The skip-write guard added in 5efwxz is now load-bearing logic with zero direct test coverage. This is pre-existing debt not introduced by card 5efwxz.

**Required Checks:**
* [x] Component or feature being tested is identified above.
* [x] Related work or original card is linked.
* [x] Clear motivation for pausing to add tests is documented.

---

## Initial Assessment

* The `peon --pause` command should write `"enabled": false` to config — no test verifies this behavior
* The `peon --resume` command should write `"enabled": true` to config — no test verifies this behavior
* The skip-write optimization (short-circuit when value already matches) has no direct test coverage
* All existing CLI command tests in `adapters-windows.Tests.ps1` are grep-style structural checks, not behavioral

### Current Test Coverage Analysis

| Test Type | Current Coverage | Gap Identified | Priority |
| :--- | :--- | :--- | :---: |
| **Unit Tests** | Structural only (string presence checks) | No behavioral tests that execute commands against real config | P2 |
| **Integration Tests** | None | No end-to-end test: run command, read config, assert value | P2 |
| **Edge Cases** | None | Skip-write optimization (no-op when value unchanged) untested | P2 |

---

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | `tests/peon-engine.Tests.ps1` or new Pester file | - [ ] Failing tests are written and committed. |
| **2. Implement Code** | Code already exists — tests are for existing behavior | - [ ] Minimal code to make tests pass is implemented. |
| **3. Verify Tests Pass** | Run `Invoke-Pester` | - [ ] All new tests are passing. |
| **4. Refactor** | N/A unless test setup needs cleanup | - [ ] Code is refactored for quality (or N/A is documented). |
| **5. Regression Check** | Full Pester suite + CI | - [ ] Full test suite passes with no regressions. |

### Test Cases Defined

| Test Case # | Description | Input | Expected Output | Status |
| :---: | :--- | :--- | :--- | :---: |
| **1** | `peon --pause` writes enabled=false | Fresh config with enabled=true | config.json has `"enabled": false` | Not Started |
| **2** | `peon --resume` writes enabled=true | Config with enabled=false | config.json has `"enabled": true` | Not Started |
| **3** | Skip-write no-op when value unchanged | Config already has enabled=false, run --pause | Config file not rewritten (timestamp unchanged) | Not Started |
| **4** | Other CLI config commands write expected values | Various --flag inputs | Corresponding config keys updated | Not Started |

---

## Test Execution & Verification

| Iteration # | Test Batch | Action Taken | Outcome |
| :---: | :--- | :--- | :--- |
| **1** | TBD | TBD | TBD |

---
#### Iteration 1: [Initial Test Run]

**Test Batch:** Test cases 1-4

**Action Taken:** TBD

**Outcome:** TBD

---

## Coverage Verification

| Metric | Before | After | Target Met? |
| :--- | :---: | :---: | :---: |
| **Line Coverage** | N/A (structural only) | TBD | TBD |
| **Branch Coverage** | 0% (skip-write path) | TBD | TBD |
| **Test Count** | 0 behavioral | TBD | TBD |

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
| **Similar Gaps Elsewhere?** | Check if bash-side CLI commands (peon.sh) have similar structural-only tests |
| **Process Improvement** | Consider adding behavioral test requirement to PR checklist for config-modifying code |
| **Future Refactoring** | N/A |
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
