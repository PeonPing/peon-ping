## Refactoring Overview & Motivation

* **Refactoring Target:** Validation functions in `install.ps1` (filename safety, pack name validation, fallback defaults)
* **Code Location:** `install.ps1`, `tests/adapters-windows.Tests.ps1`
* **Refactoring Type:** Extract module — move validation functions from `install.ps1` into a dot-sourceable `.ps1` utilities file
* **Motivation:** E2E tests currently duplicate validation functions from `install.ps1` into the test `BeforeAll` block. If validation logic changes in `install.ps1`, the test copies can drift. Extracting into a shared module lets tests exercise the real functions instead of copies.
* **Business Impact:** Reduces maintenance burden and risk of test/source drift. Improves confidence that tests validate actual production logic.
* **Scope:** Validation functions in `install.ps1` (~3-5 functions) plus corresponding duplicates in `tests/adapters-windows.Tests.ps1` `BeforeAll` block
* **Risk Level:** Low — isolated utility functions, structural regex tests provide a safety net against drift
* **Related Work:** Flagged during TECHDEBT sprint review of card `laimst`

**Required Checks:**
* [x] **Refactoring motivation** clearly explains why this change is needed.
* [x] **Scope** is specific and bounded (not open-ended "improve everything").
* [x] **Risk level** is assessed based on code criticality and usage.

---

## Pre-Refactoring Context Review

Before refactoring, review existing code, tests, documentation, and dependencies to understand current implementation and prevent breaking changes.

* [ ] Existing code reviewed and behavior fully understood.
* [ ] Test coverage reviewed - current test suite provides safety net.
* [ ] Documentation reviewed (README, docstrings, inline comments).
* [ ] Style guide and coding standards reviewed for compliance.
* [ ] Dependencies reviewed (internal modules, external libraries).
* [ ] Usage patterns reviewed (who calls this code, how it's used).
* [ ] Previous refactoring attempts reviewed (if any - learn from history).

| Review Source | Link / Location | Key Findings / Constraints |
| :--- | :--- | :--- |
| **Existing Code** | `install.ps1` — validation functions | Functions for filename safety, pack name validation, fallback defaults |
| **Test Coverage** | `tests/adapters-windows.Tests.ps1` `BeforeAll` block | Duplicated copies of validation functions used in E2E tests |
| **Documentation** | `CLAUDE.md` install section | Documents `install.ps1` usage and test commands |
| **Dependencies** | `install.ps1` is standalone, called by users directly | New module must be dot-sourceable without side effects |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* Extract validation functions (filename safety, pack name validation, fallback defaults) from `install.ps1` into a new `scripts/install-utils.ps1` (or similar) file
* Dot-source the utilities file from both `install.ps1` and `tests/adapters-windows.Tests.ps1`
* Remove duplicated function definitions from test `BeforeAll` block

**Incremental Steps:**
1. Identify all validation functions duplicated between `install.ps1` and tests
2. Create new utilities `.ps1` file with extracted functions
3. Update `install.ps1` to dot-source the utilities file
4. Update tests to dot-source the same utilities file, removing duplicates
5. Run Pester tests to validate no regressions

**Risk Mitigation:**
* Risk: Breaking `install.ps1` for users. Mitigation: Ensure dot-sourcing works from any working directory (use `$PSScriptRoot`)
* Risk: Test isolation. Mitigation: Verify utilities file has no side effects when dot-sourced

**Rollback Plan:**
* Simple git revert — functions can be inlined back into both files

**Success Criteria:**
* All Pester tests pass
* No duplicated validation logic between `install.ps1` and tests
* `install.ps1` still works standalone for end users

---

## Refactoring Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | Existing Pester tests in `tests/adapters-windows.Tests.ps1` | - [ ] Comprehensive tests exist before refactoring starts. |
| **Baseline Measurements** | Current tests pass in CI (Windows runner) | - [ ] Baseline metrics captured (complexity, performance, coverage). |
| **Incremental Refactoring** | Not started | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | Not started | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | Not started | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |
| **Performance Validation** | N/A — no runtime performance impact | - [ ] Performance validated - no regression, ideally improvement. |
| **Staging Deployment** | N/A — dev tooling | - [ ] Refactored code validated in staging environment. |
| **Production Deployment** | N/A — dev tooling | - [ ] Refactored code deployed to production with monitoring. |

---

## Safe Refactoring Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Existing Pester tests | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | Not started | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | Not started | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Not started | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | Not started | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | Not started | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | Not started | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | Not started | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | Not started | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | Not started | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | N/A | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | N/A | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | N/A | - [ ] Gradual production rollout with monitoring. |

#### Refactoring Implementation Notes

> To be filled during execution.

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | `install.ps1`, `scripts/install-utils.ps1` (new), `tests/adapters-windows.Tests.ps1` |
| **Test Suite** | Pester tests in `tests/adapters-windows.Tests.ps1` |
| **Baseline Metrics (Before)** | Duplicated validation functions in 2 files |
| **Final Metrics (After)** | Single source of truth for validation functions |
| **Performance Validation** | N/A |
| **Style & Linting** | To be validated |
| **Code Review** | To be completed |
| **Documentation Updates** | To be completed |
| **Staging Validation** | N/A |
| **Production Deployment** | N/A |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | TBD — may apply same pattern to other duplicated test helpers |
| **Design Patterns Reusable?** | Yes — dot-sourceable module pattern for PowerShell testability |
| **Test Suite Improvements?** | Tests will exercise real functions instead of copies |
| **Documentation Complete?** | Not started |
| **Performance Impact?** | Neutral |
| **Team Knowledge Sharing?** | Not needed |
| **Technical Debt Reduced?** | Yes — eliminates function duplication between source and tests |
| **Code Quality Metrics Improved?** | DRY principle enforced |

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
