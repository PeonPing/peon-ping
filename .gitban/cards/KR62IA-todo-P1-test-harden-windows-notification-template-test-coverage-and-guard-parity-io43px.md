# Harden Windows Notification Template Test Coverage and Guard Parity

**When to use this template:** Targeted test and code hardening for the Windows notification template resolution engine shipped in kr62ia.

## Overview & Context for [Windows Notification Templates]

* **Component/Feature:** Windows notification template resolution in `peon.ps1` (embedded in `install.ps1`)
* **Related Work:** Card kr62ia — Windows Notification Template Resolution Engine
* **Motivation:** Code review of kr62ia identified two non-blocking gaps: (1) `task.error` template key is only verified via regex, not by invoking the resolution engine, and (2) Windows event-override guard structure diverges from Unix implementation.

**Required Checks:**
* [x] Component or feature being tested is identified above.
* [x] Related work or original card is linked.
* [x] Clear motivation for pausing to add tests is documented.

---

## Initial Assessment

* The `task.error -> error` template key is verified in `win-notification-templates.Tests.ps1` only via regex match on `install.ps1` source, not by invoking the template resolution engine like the other four keys.
* The Unix `peon.sh` guards `idle_prompt`/`elicitation_dialog` overrides behind `event == 'Notification'`, while the Windows `peon.ps1` uses flat `if` statements that fire regardless of `$hookEvent`, risking future edge-case divergence.

### Current Test Coverage Analysis

| Test Type | Current Coverage | Gap Identified | Priority |
| :--- | :--- | :--- | :---: |
| **Unit Tests** | 4/5 keys invoke-tested | `task.error` key only regex-tested, not invoke-tested | P1 |
| **Integration Tests** | N/A | N/A | -- |
| **Edge Cases** | No guard parity test | Missing `$hookEvent` guard on Windows event overrides | P1 |

---

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | Add invoke-based `task.error` Pester test case; add guard-parity test | - [ ] Failing tests are written and committed. |
| **2. Implement Code** | Add `$hookEvent` guard around `idle_prompt`/`elicitation_dialog` overrides in `install.ps1` | - [ ] Minimal code to make tests pass is implemented. |
| **3. Verify Tests Pass** | Run `Invoke-Pester -Path tests/win-notification-templates.Tests.ps1` | - [ ] All new tests are passing. |
| **4. Refactor** | Verify guard structure mirrors Unix `peon.sh` pattern | - [ ] Code is refactored for quality (or N/A is documented). |
| **5. Regression Check** | Run full Pester suite: `Invoke-Pester -Path tests/adapters-windows.Tests.ps1` | - [ ] Full test suite passes with no regressions. |

### Test Cases Defined

| Test Case # | Description | Input | Expected Output | Status |
| :---: | :--- | :--- | :--- | :---: |
| **1** | Invoke-based `task.error` template resolution | CESP event `task.error`, config with `error` template | Notification message matches `error` template output with variables resolved | Not Started |
| **2** | `idle_prompt` override only fires when `$hookEvent -eq 'Notification'` | CESP event `input.required` with `$hookEvent` not `Notification` | Override does NOT apply; default template used | Not Started |
| **3** | `elicitation_dialog` override only fires when `$hookEvent -eq 'Notification'` | CESP event `input.required` with `$hookEvent` not `Notification` | Override does NOT apply; default template used | Not Started |

#### Test Implementation Notes

**Item 1 -- Invoke-based `task.error` test:**
Add a test case in `tests/win-notification-templates.Tests.ps1` that invokes the template resolution function with a `task.error` event, matching the pattern used for the other four template keys (`session.start`, `task.complete`, `input.required`, `user.spam`).

**Item 2 -- Event-override guard alignment:**
In `install.ps1`, wrap the `idle_prompt`/`elicitation_dialog` override logic in a `$hookEvent -eq 'Notification'` guard, mirroring the Unix `peon.sh` pattern at approximately line 3698+. Add Pester tests confirming the guard prevents override application for non-Notification hook events.

---

## Test Execution & Verification

| Iteration # | Test Batch | Action Taken | Outcome |
| :---: | :--- | :--- | :--- |
| **1** | Tests 1-3 | Pending | Pending |

---
#### Iteration 1: [Initial Test Run]

**Test Batch:** Test cases 1-3

**Action Taken:** Pending

**Outcome:** Pending

---

## Coverage Verification

| Metric | Before | After | Target Met? |
| :--- | :---: | :---: | :---: |
| **Template invoke tests** | 4/5 keys | 5/5 keys | N |
| **Guard parity tests** | 0 | 2 | N |
| **Pester regression** | 360 passing | >= 360 passing | N |

* [ ] Coverage report generated and reviewed.
* [ ] All critical paths are now tested.
* [ ] Edge cases identified in assessment are covered.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | Self-review or PR |
| **CI/CD Verification** | Pester Windows CI job |
| **Coverage Report** | Template invoke coverage: 5/5 keys |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Similar Gaps Elsewhere?** | Check that all future template keys get invoke tests from the start |
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

---

## Required Reading

| Resource | Location |
| :--- | :--- |
| Existing template tests | `tests/win-notification-templates.Tests.ps1` |
| Windows hook script | `install.ps1` (lines ~1080-1168, notification/template section) |
| Unix guard reference | `peon.sh` (lines ~3698-3723, Python template block) |
| Design doc | `docs/designs/win-notification-templates.md` |

### Files Touched

- `tests/win-notification-templates.Tests.ps1` -- add invoke-based `task.error` test + guard parity tests
- `install.ps1` -- add `$hookEvent` guard around `idle_prompt`/`elicitation_dialog` overrides
