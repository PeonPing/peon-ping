# TDD Test Implementation for PEON_DEBUG Warning Stream Output

## Overview & Context for PEON_DEBUG Warning Stream

* **Component/Feature:** Diagnostic logging via `PEON_DEBUG=1` in `scripts/win-play.ps1` and the embedded `peon.ps1` in `install.ps1`
* **Related Work:** Card z5xm5k (Add diagnostic logging for silent audio failures), commit 3bcf15e
* **Motivation:** The diagnostic logging added in commit 3bcf15e emits warnings on known failure paths, but there are no Pester tests validating that warnings are actually produced when `PEON_DEBUG=1` is set. Without test coverage, future changes could silently break the diagnostic output.

**Required Checks:**
* [ ] Component or feature being tested is identified above.
* [ ] Related work or original card is linked.
* [ ] Clear motivation for pausing to add tests is documented.

---

## Initial Assessment

* Gap noticed: No Pester tests assert on warning stream output when `PEON_DEBUG=1` is set
* Risk: Diagnostic logging could regress silently since it is untested
* Scope: `scripts/win-play.ps1` failure paths and embedded `peon.ps1` in `install.ps1`

### Current Test Coverage Analysis

| Test Type | Current Coverage | Gap Identified | Priority |
| :--- | :--- | :--- | :---: |
| **Unit Tests** | Partial — `peon-engine.Tests.ps1` covers engine logic | No tests for PEON_DEBUG warning output | P2 |
| **Integration Tests** | None for warning stream | No tests verify stderr/warning output under PEON_DEBUG=1 | P2 |
| **Edge Cases** | None | Missing win-play.ps1, empty catch blocks, corrupt state | P2 |

---

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | tests/peon-engine.Tests.ps1 or new test file | - [ ] Failing tests are written and committed. |
| **2. Implement Code** | N/A — diagnostic logging already exists from commit 3bcf15e | - [ ] Minimal code to make tests pass is implemented. |
| **3. Verify Tests Pass** | Run Invoke-Pester | - [ ] All new tests are passing. |
| **4. Refactor** | N/A | - [ ] Code is refactored for quality (or N/A is documented). |
| **5. Regression Check** | Full Pester suite | - [ ] Full test suite passes with no regressions. |

### Test Cases Defined

| Test Case # | Description | Input | Expected Output | Status |
| :---: | :--- | :--- | :--- | :---: |
| **1** | Warning emitted when win-play.ps1 path is missing and PEON_DEBUG=1 | PEON_DEBUG=1, missing win-play.ps1 | Warning stream contains diagnostic message | Not Started |
| **2** | Warning emitted on WAV playback catch path with PEON_DEBUG=1 | PEON_DEBUG=1, simulated playback error | Warning stream contains error detail | Not Started |
| **3** | Warning emitted on state-write catch path with PEON_DEBUG=1 | PEON_DEBUG=1, simulated state-write failure | Warning stream contains state-write diagnostic | Not Started |
| **4** | No warning output when PEON_DEBUG is unset | Normal operation, no PEON_DEBUG | Empty warning stream | Not Started |

---

## Test Execution & Verification

| Iteration # | Test Batch | Action Taken | Outcome |
| :---: | :--- | :--- | :--- |
| **1** | TBD | TBD | TBD |

---
#### Iteration 1: [Initial Test Run]

**Test Batch:** Test cases 1-4: PEON_DEBUG warning stream validation

**Action Taken:** TBD

**Outcome:** TBD

---

## Coverage Verification

| Metric | Before | After | Target Met? |
| :--- | :---: | :---: | :---: |
| **Line Coverage** | N/A | TBD | TBD |
| **Branch Coverage** | N/A | TBD | TBD |
| **Test Count** | TBD | TBD | TBD |

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
| **Similar Gaps Elsewhere?** | Check bash-side peon.sh diagnostic paths |
| **Process Improvement** | N/A |
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
