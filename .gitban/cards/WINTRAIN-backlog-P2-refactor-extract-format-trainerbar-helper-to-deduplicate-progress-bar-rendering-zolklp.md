# Extract Format-TrainerBar Helper

## Refactoring Overview & Motivation

* **Refactoring Target:** Trainer progress bar rendering logic in `peon.ps1` (embedded in `install.ps1`)
* **Code Location:** `install.ps1` — embedded `peon.ps1` trainer block, `status` and `log` subcommands
* **Refactoring Type:** Extract method — deduplicate repeated progress bar rendering code
* **Motivation:** The `status` and `log` subcommands each independently define `$barWidth`, `$fullBlock`, `$lightShade`, compute `$filled`/`$empty`, and build the bar string. This is duplicated logic that should be extracted into a shared helper.
* **Business Impact:** Reduces maintenance burden and risk of bar rendering divergence between subcommands.
* **Scope:** Small — extract ~10 duplicated lines into a `Format-TrainerBar` helper function or scriptblock above the trainer switch block.
* **Risk Level:** Low — isolated UI formatting function with no side effects.
* **Related Work:** Originated from review item L2 on card yq8iba (step-1-trainer-cli-subcommands-in-peon-ps1).

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
| **Existing Code** | `install.ps1` — embedded peon.ps1 trainer block | `status` and `log` subcommands both define `$barWidth`, `$fullBlock`, `$lightShade`, compute `$filled`/`$empty`, and build identical bar strings |
| **Test Coverage** | `tests/adapters-windows.Tests.ps1` | No Pester tests for trainer subcommands yet (separate card) |
| **Dependencies** | Used by: `peon trainer status`, `peon trainer log` | Only affects console output formatting |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* Extract a `Format-TrainerBar` helper function (or scriptblock) that takes `$done` and `$goal` parameters and returns the formatted progress bar string.
* Place the helper above the trainer switch block so both `status` and `log` subcommands can call it.

**Incremental Steps:**
1. Identify the exact duplicated lines in both `status` and `log` subcommands.
2. Create `Format-TrainerBar` function with `$done` and `$goal` parameters.
3. Replace duplicated code in `status` subcommand with call to helper.
4. Replace duplicated code in `log` subcommand with call to helper.
5. Verify visual output is identical before and after.

**Risk Mitigation:**
* Risk: Breaking bar rendering. Mitigation: Visual comparison before/after.

**Rollback Plan:**
* Simple git revert — single commit change.

**Success Criteria:**
* Progress bar renders identically in both `status` and `log` subcommands.
* Bar rendering logic exists in exactly one place.

---

## Refactoring Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | Deferred — trainer Pester tests are a separate card | - [ ] Comprehensive tests exist before refactoring starts. |
| **Incremental Refactoring** | Not started | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | N/A — internal helper | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | Not started | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |

---

## Safe Refactoring Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Deferred to companion Pester test card | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | Not started | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | Not started | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Not started — extract Format-TrainerBar | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | Not started | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | Not started | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | N/A — single extraction | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | N/A — internal helper | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | Not started | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | Not started | - [ ] Changes reviewed for correctness and maintainability. |

#### Refactoring Implementation Notes

**Refactoring Techniques Applied:**
* Extract Method: Pull duplicated progress bar rendering into `Format-TrainerBar` helper.

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | `install.ps1` — embedded peon.ps1 trainer block |
| **Test Suite** | Pending companion Pester test card |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | TBD after implementation |
| **Documentation Complete?** | N/A — internal helper function |

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
