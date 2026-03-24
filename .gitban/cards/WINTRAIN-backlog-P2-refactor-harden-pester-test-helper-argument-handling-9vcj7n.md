## Refactoring Overview & Motivation

* **Refactoring Target:** `Invoke-PeonCli` helper function argument construction
* **Code Location:** `tests/trainer-windows.Tests.ps1`
* **Refactoring Type:** Replace string concatenation with safe array splatting
* **Motivation:** `Invoke-PeonCli` constructs arguments via string concatenation (`"'" + $_ + "'"`) which would break if any argument contained a single quote. Refactor to use proper PowerShell array splatting with `& powershell.exe -File $script -args` or equivalent safe quoting.
* **Business Impact:** Prevents future test fragility if exercise names or arguments ever contain special characters (single quotes, spaces, etc.)
* **Scope:** Single helper function in one test file (~5-10 lines)
* **Risk Level:** Low - isolated test helper, not production code
* **Related Work:** Flagged during WINTRAIN code review (WINTRAIN-hchc5z reviewer feedback, L2 item)

**Required Checks:**
* [ ] **Refactoring motivation** clearly explains why this change is needed.
* [ ] **Scope** is specific and bounded (not open-ended "improve everything").
* [ ] **Risk level** is assessed based on code criticality and usage.

---

## Pre-Refactoring Context Review

* [ ] Existing code reviewed and behavior fully understood.
* [ ] Test coverage reviewed - current test suite provides safety net.
* [ ] Documentation reviewed (README, docstrings, inline comments).
* [ ] Style guide and coding standards reviewed for compliance.
* [ ] Dependencies reviewed (internal modules, external libraries).
* [ ] Usage patterns reviewed (who calls this code, how it's used).
* [ ] Previous refactoring attempts reviewed (if any - learn from history).

| Review Source | Link / Location | Key Findings / Constraints |
| :--- | :--- | :--- |
| **Existing Code** | `tests/trainer-windows.Tests.ps1`, `Invoke-PeonCli` function | String concatenation with single-quote wrapping for arguments |
| **Test Coverage** | Pester test suite in same file | Tests currently pass because exercise names are simple strings without special chars |
| **Documentation** | Inline comments in test file | Minimal documentation on helper |
| **Style Guide** | PowerShell best practices | Should use array splatting or proper argument passing |
| **Dependencies** | Used by multiple test cases within `trainer-windows.Tests.ps1` | All test cases in this file call through this helper |
| **Usage Patterns** | Test-only helper | Not used in production code |
| **Previous Attempts** | None | First refactor |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* Replace string concatenation (`"'" + $_ + "'"`) with PowerShell array splatting or proper `& powershell.exe -File $script @args` invocation pattern

**Incremental Steps:**
1. Review current `Invoke-PeonCli` implementation and all callers
2. Implement safe argument passing using PowerShell array splatting
3. Verify all existing Pester tests still pass
4. Optionally add a test case with a single-quote in an argument to confirm safety

**Risk Mitigation:**
* Risk: Breaking existing tests. Mitigation: Run full Pester suite before and after change.

**Rollback Plan:**
* Git revert single commit if tests fail

**Success Criteria:**
* All existing Pester tests pass without modification
* Arguments with single quotes, spaces, or special characters are handled safely
* No string concatenation for argument construction

---

## Refactoring Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | Existing Pester tests serve as safety net | - [ ] Comprehensive tests exist before refactoring starts. |
| **Baseline Measurements** | Run `Invoke-Pester` to confirm all tests pass | - [ ] Baseline metrics captured (complexity, performance, coverage). |
| **Incremental Refactoring** | Replace string concat with array splatting | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | Update inline comments if needed | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | PR review | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |
| **Performance Validation** | N/A - test helper only | - [ ] Performance validated - no regression, ideally improvement. |
| **Staging Deployment** | N/A - test code | - [ ] Refactored code validated in staging environment. |
| **Production Deployment** | N/A - test code | - [ ] Refactored code validated in production. |

---

## Safe Refactoring Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Existing Pester tests | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | `Invoke-Pester -Path tests/trainer-windows.Tests.ps1` | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | All tests green | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Replace string concat in `Invoke-PeonCli` with array splatting | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | Re-run Pester suite | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | Single commit | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | Single-step refactor, no repetition needed | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | Update inline comments | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | PowerShell best practices | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | PR review | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | N/A | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | N/A | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | N/A | - [ ] Gradual production rollout with monitoring. |

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | `tests/trainer-windows.Tests.ps1` - `Invoke-PeonCli` function |
| **Test Suite** | Pester tests in same file |
| **Baseline Metrics (Before)** | String concatenation argument handling |
| **Final Metrics (After)** | Array splatting argument handling |
| **Performance Validation** | N/A - test helper |
| **Style & Linting** | PowerShell best practices compliance |
| **Code Review** | TBD |
| **Documentation Updates** | Inline comments |
| **Staging Validation** | N/A |
| **Production Deployment** | N/A |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | Check other test helpers for similar patterns |
| **Design Patterns Reusable?** | Array splatting pattern applicable to all test helpers |
| **Test Suite Improvements?** | Optionally add test with special-char arguments |
| **Documentation Complete?** | TBD |
| **Performance Impact?** | None |
| **Team Knowledge Sharing?** | N/A |
| **Technical Debt Reduced?** | Yes - removes fragile string concatenation |
| **Code Quality Metrics Improved?** | Yes - safer argument handling |

### Completion Checklist

* [ ] Comprehensive tests exist before refactoring (95%+ coverage target).
* [ ] All tests pass before refactoring begins (baseline established).
* [ ] Baseline metrics captured (complexity, coverage, performance).
* [ ] Refactoring implemented incrementally (small, safe steps).
* [ ] All tests pass after each refactoring step (continuous validation).
* [ ] Documentation updated (docstrings, README, inline comments, architecture docs).
* [ ] Code passes style guide validation (linting, type checking).
* [ ] Code reviewed by at least 2 team members.
* [ ] No performance regression (ideally improvement).
* [ ] Refactored code validated in staging environment.
* [ ] Production deployment successful with monitoring.
* [ ] Code quality metrics improved (complexity, coverage, maintainability).
* [ ] Rollback plan documented and tested (if high-risk refactor).
