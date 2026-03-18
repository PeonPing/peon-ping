# Code Refactoring Template

---

## Refactoring Overview & Motivation

* **Refactoring Target:** `_write_state` / `_read_state` Python helpers in `peon.sh`
* **Code Location:** `peon.sh` (lines ~2586, ~2671, ~2865 — three identical copies)
* **Refactoring Type:** Extract method / DRY duplication + optimize error handling
* **Motivation:** Three identical copies of `_write_state`/`_read_state` exist in `peon.sh`. If retry delays, temp file strategy, or error handling ever need to change, all three must be updated in sync. Additionally, `read_state()` retries on `FileNotFoundError` adding up to 350ms of unnecessary delay on a clean first run when no `.state.json` exists.
* **Business Impact:** Reduces maintenance burden and eliminates a 350ms first-run latency penalty.
* **Scope:** ~3 inline Python blocks in `peon.sh` consolidated into a shared approach.
* **Risk Level:** Medium - state management is core to hook operation.
* **Related Work:** Flagged during HOOKBUG-kydihy review (atomic state writes card).

**Required Checks:**
* [ ] **Refactoring motivation** clearly explains why this change is needed.
* [ ] **Scope** is specific and bounded (not open-ended "improve everything").
* [ ] **Risk level** is assessed based on code criticality and usage.

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
| **Existing Code** | `peon.sh` lines ~2586, ~2671, ~2865 | Three identical copies of `_write_state`/`_read_state` Python helpers |
| **Test Coverage** | `tests/peon.bats` | Needs review for state management coverage |
| **Documentation** | `CLAUDE.md` State Management section | `.state.json` persists across invocations |
| **Dependencies** | Main Python block, trainer commands | Trainer commands use separate Python blocks with duplicated helpers |
| **Usage Patterns** | Every hook invocation | `read_state()` called on every event; `write_state()` on most |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* **Item 1 (DRY):** Extract shared `_write_state`/`_read_state` Python snippet so all three call sites use a single definition. Options: (a) extract to a shared `.py` file that gets inlined during install, or (b) refactor trainer commands to share the main Python block's helpers.
* **Item 2 (First-run optimization):** In `read_state()`, check `os.path.exists(path)` before the retry loop, or catch only `json.JSONDecodeError` and `IOError`/`PermissionError` in the retry path while letting `FileNotFoundError` fall through to return `{}` immediately.

**Incremental Steps:**
1. Add/verify tests covering state read/write behavior (including first-run with no `.state.json`).
2. Optimize `read_state()` to skip retry loop on `FileNotFoundError`.
3. Extract shared state helpers to eliminate duplication.
4. Verify all existing tests pass.

**Risk Mitigation:**
* Risk: Breaking state persistence. Mitigation: Ensure comprehensive test coverage before refactoring.
* Risk: Platform differences (Unix vs WSL2). Mitigation: Test on both platforms.

**Rollback Plan:**
* Git revert — changes are isolated to `peon.sh`.

**Success Criteria:**
* All existing tests pass without modification.
* Only one copy of `_write_state`/`_read_state` logic exists.
* First run with no `.state.json` completes without 350ms retry delay.

---

## Refactoring Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | Not started | - [ ] Comprehensive tests exist before refactoring starts. |
| **Baseline Measurements** | Not started | - [ ] Baseline metrics captured (complexity, performance, coverage). |
| **Incremental Refactoring** | Not started | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | Not started | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | Not started | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |
| **Performance Validation** | Not started | - [ ] Performance validated - no regression, ideally improvement. |
| **Staging Deployment** | N/A (CLI tool) | - [ ] Refactored code validated in staging environment. |
| **Production Deployment** | N/A (CLI tool) | - [ ] Refactored code deployed to production with monitoring. |

---

## Safe Refactoring Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Not started | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | Not started | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | Not started | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Not started — optimize `read_state()` FileNotFoundError handling | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | Not started | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | Not started | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | Not started — extract shared state helpers | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | Not started | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | N/A (shell/Python, no configured linter) | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | Not started | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | Not started — verify first-run latency improvement | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | N/A | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | N/A | - [ ] Gradual production rollout with monitoring. |

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | `peon.sh` — state helper Python blocks |
| **Test Suite** | TBD |
| **Baseline Metrics (Before)** | 3 duplicate blocks; 350ms first-run delay |
| **Final Metrics (After)** | TBD |
| **Performance Validation** | TBD |
| **Style & Linting** | N/A |
| **Code Review** | TBD |
| **Documentation Updates** | TBD |
| **Staging Validation** | N/A |
| **Production Deployment** | N/A |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | TBD |
| **Design Patterns Reusable?** | TBD |
| **Test Suite Improvements?** | TBD |
| **Documentation Complete?** | TBD |
| **Performance Impact?** | TBD |
| **Team Knowledge Sharing?** | N/A |
| **Technical Debt Reduced?** | TBD |
| **Code Quality Metrics Improved?** | TBD |

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
