# Code Refactoring Template

**When to use this template:** Hardening BATS test fixtures and filling coverage gaps in the hook-logging test suite before the log format is documented and released.

---

## Refactoring Overview & Motivation

* **Refactoring Target:** Hook-logging BATS test infrastructure — `validate_log_fixture` helper, debug-config boilerplate, and missing error-path test coverage
* **Code Location:** `tests/setup.bash`, `tests/peon.bats`, `tests/fixtures/hook-logging/`
* **Refactoring Type:** Test infrastructure hardening (fix parsing bug, DRY helpers, add missing coverage)
* **Motivation:** Three issues found during review of step 2 (card 77eri8): (1) `validate_log_fixture` word-splitting parser breaks on quoted values with spaces; (2) config-enable boilerplate is copy-pasted across 8 test functions; (3) missing audio backend error-path test that PRD-002 acceptance criteria require.
* **Business Impact:** Without these fixes, test assertions silently pass on incorrect data (word-splitting bug), maintenance cost grows with each new logging test (boilerplate duplication), and a PRD-002 acceptance criterion (error logging branch) is unverified.
* **Scope:** 3 files — `tests/setup.bash` (add/fix helpers), `tests/peon.bats` (refactor existing tests + add new test), `tests/fixtures/hook-logging/` (fixture validation).
* **Risk Level:** Low — test-only changes, no production code modified.
* **Related Work:** Card 77eri8 (step 2 core logging infrastructure), card 288ewn (step 2b bash log hardening), ADR-002 structured hook logging, PRD-002 hook observability.

**Required Checks:**
* [x] **Refactoring motivation** clearly explains why this change is needed.
* [x] **Scope** is specific and bounded (not open-ended).
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
| **Existing Code** | `tests/setup.bash` — `validate_log_fixture` function | Word-splitting parser breaks on quoted values containing spaces; non-wildcard fixture matching gives false positives |
| **Test Coverage** | `tests/peon.bats` — 8 debug-logging tests | Each test copies identical `python3 -c "import json; cfg = json.load(...); cfg['debug'] = True; ..."` boilerplate to enable debug mode |
| **Documentation** | PRD-002 acceptance criteria | Requires validation of `[play] error=` logging branch when audio backend is missing |
| **Dependencies** | `tests/fixtures/hook-logging/` | Shared fixtures used by both BATS and future Pester tests |
| **Usage Patterns** | Called by all hook-logging BATS tests | `validate_log_fixture` is the primary assertion helper for structured log output |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* Fix `validate_log_fixture` to use a proper field extractor (Python one-liner or awk) that respects quoted values, replacing naive word-splitting.
* Extract an `enable_debug_logging` helper into `tests/setup.bash` and replace the 8 copy-pasted config-enable blocks in `tests/peon.bats`.
* Add a new BATS test that removes mock audio backends from PATH to trigger and validate the `[play] error=` logging branch.

**Incremental Steps:**
1. Fix `validate_log_fixture` quoted-value parsing
2. Verify existing tests still pass with the parser fix
3. Extract `enable_debug_logging` helper into `setup.bash`
4. Replace 8 boilerplate blocks in `peon.bats` with calls to the new helper
5. Verify all existing tests still pass after DRY refactor
6. Add new BATS test for missing audio backend error path
7. Verify full test suite passes

**Risk Mitigation:**
* Test-only changes — zero risk to production code
* Each step is independently verifiable with `bats tests/`
* Incremental commits allow easy bisect if something breaks

**Rollback Plan:**
* Git revert — no configuration or state changes involved

**Success Criteria:**
* `validate_log_fixture` correctly handles quoted values with spaces (no false positives)
* Config-enable boilerplate appears exactly once (in `enable_debug_logging` helper)
* New BATS test exercises the `[play] error=` logging branch when no audio backend is on PATH
* All existing BATS tests continue to pass

---

## Refactoring Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | Existing BATS suite is the safety net | - [ ] Comprehensive tests exist before refactoring starts. |
| **Baseline Measurements** | Run `bats tests/` — confirm green | - [ ] Baseline metrics captured (complexity, performance, coverage). |
| **Incremental Refactoring** | Fix parser, DRY helper, add error-path test | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | Inline comments in setup.bash for new helpers | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | Sprint reviewer | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |
| **Performance Validation** | N/A — test infrastructure only | - [ ] Performance validated - no regression, ideally improvement. |
| **Staging Deployment** | N/A | - [ ] Refactored code validated in staging environment. |
| **Production Deployment** | N/A | - [ ] Refactored code deployed to production with monitoring. |

---

## Safe Refactoring Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Existing BATS tests are the safety net | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | `bats tests/` all green | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | N/A for test-only scope | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Fix `validate_log_fixture` quoted-value parsing | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | All tests pass after parser fix | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | Commit parser fix | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | (a) Extract `enable_debug_logging` helper, (b) Replace 8 boilerplate blocks, (c) Add error-path test | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | Inline comments for new helpers | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | N/A — no linter configured | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | Sprint reviewer | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | N/A | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | N/A | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | N/A | - [ ] Gradual production rollout with monitoring. |

#### Refactoring Implementation Notes

> **Item 1 — `validate_log_fixture` parser fix:** The current implementation uses bash word-splitting to parse key=value fields from log lines. This breaks when a quoted value contains spaces (e.g., `label="Ready to work"`). Replace with a Python one-liner or awk-based field extractor that respects double-quoted values. Grep for `validate_log_fixture` in `tests/setup.bash` to find the function.
>
> **Item 2 — `enable_debug_logging` helper:** The pattern `python3 -c "import json; cfg = json.load(open('$PEON_DIR/config.json')); cfg['debug'] = True; json.dump(cfg, open('$PEON_DIR/config.json', 'w'))"` is duplicated across 8 test functions. Extract to a single `enable_debug_logging` function in `tests/setup.bash`.
>
> **Item 3 — Missing audio backend error-path test:** Current "missing audio backend" test has mock afplay on PATH, so it exercises the happy path. Add a test that removes all audio backend mocks from PATH before triggering a hook event, then assert the log contains `[play] error=` with appropriate error details.

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | `tests/setup.bash`, `tests/peon.bats`, `tests/fixtures/hook-logging/` |
| **Test Suite** | `bats tests/` — existing + 1 new error-path test |
| **Baseline Metrics (Before)** | Word-splitting parser; 8x boilerplate; no error-path coverage |
| **Final Metrics (After)** | Proper quoted-value parser; DRY helper; error-path test added |
| **Performance Validation** | N/A |
| **Style & Linting** | N/A |
| **Code Review** | Pending |
| **Documentation Updates** | Inline comments for new helpers |
| **Staging Validation** | N/A |
| **Production Deployment** | N/A |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | No |
| **Design Patterns Reusable?** | N/A |
| **Test Suite Improvements?** | This card IS the test suite improvement |
| **Documentation Complete?** | Inline comments sufficient for test helpers |
| **Performance Impact?** | N/A |
| **Team Knowledge Sharing?** | N/A |
| **Technical Debt Reduced?** | Yes — fixes parser bug, removes duplication, fills coverage gap |
| **Code Quality Metrics Improved?** | Yes — 3 issues resolved |

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
