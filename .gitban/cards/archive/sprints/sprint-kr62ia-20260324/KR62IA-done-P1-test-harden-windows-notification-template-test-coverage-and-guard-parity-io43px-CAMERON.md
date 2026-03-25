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
| **1. Write Failing Tests** | Add invoke-based `task.error` Pester test case; add guard-parity test | - [x] Failing tests are written and committed. |
| **2. Implement Code** | Add `$hookEvent` guard around `idle_prompt`/`elicitation_dialog` overrides in `install.ps1` | - [x] Minimal code to make tests pass is implemented. |
| **3. Verify Tests Pass** | Run `Invoke-Pester -Path tests/win-notification-templates.Tests.ps1` | - [x] All new tests are passing. |
| **4. Refactor** | Verify guard structure mirrors Unix `peon.sh` pattern | - [x] Code is refactored for quality (or N/A is documented). |
| **5. Regression Check** | Run full Pester suite: `Invoke-Pester -Path tests/adapters-windows.Tests.ps1` | - [x] Full test suite passes with no regressions. |

### Test Cases Defined

| Test Case # | Description | Input | Expected Output | Status |
| :---: | :--- | :--- | :--- | :---: |
| **1** | Invoke-based `task.error` template resolution | CESP event `task.error`, config with `error` template | Notification message matches `error` template output with variables resolved | Pass |
| **2** | `idle_prompt` override only fires when `$hookEvent -eq 'Notification'` | CESP event `input.required` with `$hookEvent` not `Notification` | Override does NOT apply; default template used | Pass |
| **3** | `elicitation_dialog` override only fires when `$hookEvent -eq 'Notification'` | CESP event `input.required` with `$hookEvent` not `Notification` | Override does NOT apply; default template used | Pass |

#### Test Implementation Notes

**Item 1 -- Invoke-based `task.error` test:**
Add a test case in `tests/win-notification-templates.Tests.ps1` that invokes the template resolution function with a `task.error` event, matching the pattern used for the other four template keys (`session.start`, `task.complete`, `input.required`, `user.spam`).

**Item 2 -- Event-override guard alignment:**
In `install.ps1`, wrap the `idle_prompt`/`elicitation_dialog` override logic in a `$hookEvent -eq 'Notification'` guard, mirroring the Unix `peon.sh` pattern at approximately line 3698+. Add Pester tests confirming the guard prevents override application for non-Notification hook events.

---

## Test Execution & Verification

| Iteration # | Test Batch | Action Taken | Outcome |
| :---: | :--- | :--- | :--- |
| **1** | Tests 1-3 | Implemented and ran | 20/20 pass |

---
#### Iteration 1: [Initial Test Run]

**Test Batch:** Test cases 1-3 + all existing template tests

**Action Taken:** Replaced regex-only task.error test with invoke-based test; added $hookEvent guard in install.ps1; added 4 guard parity tests (idle positive/negative, elicitation positive/negative)

**Outcome:** 20/20 notification template tests pass; 360/360 adapters-windows regression tests pass

---

## Coverage Verification

| Metric | Before | After | Target Met? |
| :--- | :---: | :---: | :---: |
| **Template invoke tests** | 4/5 keys | 5/5 keys | Y |
| **Guard parity tests** | 0 | 4 | Y |
| **Pester regression** | 360 passing | 360 passing | Y |

- [x] Coverage report generated and reviewed.
- [x] All critical paths are now tested.
- [x] Edge cases identified in assessment are covered.

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

- [x] All test cases defined in the table are implemented.
- [x] All tests are passing.
- [x] Code coverage meets or exceeds target for this component.
- [x] Full regression suite passes with no failures.
- [x] Code is refactored and clean.
- [x] Changes are committed and pushed.
- [x] Follow-up actions are documented or tickets created.
- [x] Original work (feature/bug) can be resumed with confidence.

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


## Executor Work Summary

**Commits:**
- `179a4b3` cherry-pick: Windows notification template resolution engine from kr62ia
- `15c7f77` test: harden Windows notification template coverage and guard parity

**Changes made:**

1. **install.ps1 (lines 1350-1355):** Added `$hookEvent -eq 'Notification'` guard around `idle_prompt`/`elicitation_dialog` template overrides, matching the Unix `peon.sh` structure at lines 3706-3708. Previously these overrides fired on any `$ntype` match regardless of `$hookEvent`.

2. **tests/win-notification-templates.Tests.ps1:**
   - Replaced regex-only `task.error` test (line 174-177) with invoke-based test that exercises the full template resolution engine with `HookEventName=PostToolUseFailure` and `CategoryName=task.error`. All 5 template keys now have invoke-based coverage.
   - Added 4 new guard parity tests in two Describe blocks:
     - `idle_prompt` positive: template applies when `$hookEvent -eq 'Notification'`
     - `idle_prompt` negative: template does NOT apply when `$hookEvent -eq 'Stop'`
     - `elicitation_dialog` positive: template applies when `$hookEvent -eq 'Notification'`
     - `elicitation_dialog` negative: template does NOT apply when `$hookEvent -eq 'Stop'`

**Test results:**
- Notification template tests: 20/20 pass
- Adapters-windows regression: 360/360 pass

**No deferred work.** All three test cases and both code gaps are addressed.

## Review Log

| Review # | Verdict | Commit | Date | Report |
| :---: | :--- | :--- | :--- | :--- |
| 1 | APPROVAL | 9904ff7 | 2026-03-24 | `.gitban/agents/reviewer/inbox/kr62ia-io43px-reviewer-1.md` |

Routed to executor for close-out: `.gitban/agents/executor/inbox/kr62ia-io43px-executor-1.md`