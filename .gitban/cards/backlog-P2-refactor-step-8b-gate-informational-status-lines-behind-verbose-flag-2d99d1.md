# Code Refactoring Template

**When to use this template:** Refactoring `peon status` to gate informational mode lines behind `--verbose`, keeping default output concise as feature count grows.

---

## Refactoring Overview & Motivation

* **Refactoring Target:** `peon status` command output in peon.sh
* **Code Location:** `peon.sh` (status command handler)
* **Refactoring Type:** Extract verbose-only output gating
* **Motivation:** As more features accumulate (debug mode, headphones_only, meeting_detect, etc.), the non-verbose `peon status` output grows long. Informational mode lines should only display when `--verbose` is passed.
* **Business Impact:** Keeps CLI output clean and scannable for users. Prevents information overload as features grow.
* **Scope:** `peon status` command handler in peon.sh -- mode/informational status lines
* **Risk Level:** Low -- output formatting only, no functional behavior change
* **Related Work:** HOOKLOG sprint (step-5-documentation-and-discoverability review finding)

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

Use the table below to document findings from pre-refactoring review. Add rows as needed.

| Review Source | Link / Location | Key Findings / Constraints |
| :--- | :--- | :--- |
| **Existing Code** | `peon.sh` status command handler | Identify all informational mode lines (debug, headphones_only, meeting_detect, etc.) |
| **Test Coverage** | `tests/peon.bats` | Check for existing status output tests |
| **Documentation** | `README.md` CLI reference | Update if `--verbose` flag is new or behavior changes |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* Identify all informational/mode status lines in `peon status` output (e.g., debug status, headphones_only, meeting_detect)
* Gate these lines behind a `--verbose` flag check
* Keep essential status info (version, active pack, mute state) in default output
* Show full detail only when `--verbose` is passed

**Incremental Steps:**
1. Audit all status lines and classify as "essential" vs "informational"
2. Add `--verbose` flag parsing to `peon status`
3. Wrap informational lines in verbose conditional
4. Update tests to cover both default and verbose output
5. Update README/completions if `--verbose` is a new flag

**Risk Mitigation:**
* Risk: Users relying on status output for scripting. Mitigation: Essential info stays in default output.

**Success Criteria:**
* Default `peon status` output is concise (essential info only)
* `peon status --verbose` shows all current information
* No existing tests break
* CLI completions updated if needed

---

## Refactoring Phases

Track the major phases of refactoring from test establishment through deployment.

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Audit status output lines** | Not started | - [ ] All informational lines identified and classified. |
| **Add --verbose flag parsing** | Not started | - [ ] Flag parsing implemented in peon status handler. |
| **Gate informational lines** | Not started | - [ ] Informational lines only show with --verbose. |
| **Update tests** | Not started | - [ ] Tests cover both default and verbose output. |
| **Update docs and completions** | Not started | - [ ] README, completions.bash, completions.fish updated. |

---

## Safe Refactoring Workflow

Follow this workflow to ensure safe refactoring with no functionality broken.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Not started | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | Not started | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | Not started | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Not started | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | Not started | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | Not started | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | Not started | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | Not started | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | Not started | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | Not started | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | Not started | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | N/A (CLI tool) | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | N/A (CLI tool) | - [ ] Gradual production rollout with monitoring. |

#### Refactoring Implementation Notes

> Document refactoring techniques used, design patterns introduced, and complexity improvements.

**Files touched:**
* `peon.sh` -- gate informational status lines behind `--verbose`

### Required Reading

- `peon.sh` -- the status command handler, identify all mode/informational lines
- `tests/peon.bats` -- existing status output tests
- `completions.bash` / `completions.fish` -- update if adding `--verbose` flag

### Acceptance Criteria

- [ ] `peon status` default output only shows essential info (version, active pack, mute state)
- [ ] `peon status --verbose` shows all informational mode lines (debug, headphones_only, meeting_detect, etc.)
- [ ] Existing tests pass without modification (or are updated to match new behavior)
- [ ] New tests cover both default and verbose output modes
- [ ] CLI completions updated if `--verbose` is a new flag for `peon status`
- [ ] README updated if status command documentation changes

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | peon.sh (status command handler) |
| **Test Suite** | tests/peon.bats |
| **Baseline Metrics (Before)** | TBD |
| **Final Metrics (After)** | TBD |
| **Performance Validation** | N/A (output formatting only) |
| **Style & Linting** | N/A (no linter configured) |
| **Code Review** | TBD |
| **Documentation Updates** | TBD |
| **Staging Validation** | N/A |
| **Production Deployment** | N/A |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | Consider applying same pattern to peon.ps1 |
| **Test Suite Improvements?** | TBD |
| **Documentation Complete?** | TBD |

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
