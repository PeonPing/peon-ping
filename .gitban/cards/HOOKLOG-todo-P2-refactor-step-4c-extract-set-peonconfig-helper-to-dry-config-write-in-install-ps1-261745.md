# Code Refactoring Template

---

## Refactoring Overview & Motivation

* **Refactoring Target:** Culture-swap + config-write boilerplate in install.ps1
* **Code Location:** `install.ps1`
* **Refactoring Type:** Extract Method — consolidate repeated culture-save / ConvertTo-Json -Depth 10 / Set-Content / culture-restore sequences into a single `Set-PeonConfig` helper function
* **Motivation:** The culture-save, `ConvertTo-Json -Depth 10`, `Set-Content`, culture-restore sequence now appears 8 times in `install.ps1` (4 pre-existing + 2 from debug on/off + 2 from other recent work). This is a clear DRY violation that increases maintenance burden and risk of inconsistency.
* **Business Impact:** Reduces bug surface for config-write operations. Each call site shrinks to 1-2 lines, making future config changes safer and reviews faster.
* **Scope:** ~8 call sites in `install.ps1`, approximately 40-50 lines removed, 1 new helper function (~10 lines)
* **Risk Level:** Low — existing Pester tests cover the config-write behavior; the helper is a pure extraction with no behavior change
* **Related Work:** Discovered during review of card unkjkl (step 4b: debug and logs CLI parity in peon.ps1). See HOOKLOG sprint.

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

Use the table below to document findings from pre-refactoring review. Add rows as needed.

| Review Source | Link / Location | Key Findings / Constraints |
| :--- | :--- | :--- |
| **Existing Code** | `install.ps1` — 8 occurrences of culture-swap + config-write pattern | Each site saves `[Threading.Thread]::CurrentThread.CurrentCulture`, sets InvariantCulture, calls `ConvertTo-Json -Depth 10`, writes via `Set-Content`, then restores culture. Identical boilerplate each time. |
| **Test Coverage** | `tests/adapters-windows.Tests.ps1` | Pester tests validate install.ps1 behavior including config writes. These tests must continue passing without modification. |
| **Dependencies** | Called only within `install.ps1` | No external consumers — the helper is internal to the installer script. |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* Extract Method: Create a `Set-PeonConfig` function that accepts a config object (and optionally a file path), handles the full culture-save / serialize / write / culture-restore cycle internally.

**Incremental Steps:**
1. Add `Set-PeonConfig` helper function near the top of `install.ps1` (after param block, before first usage)
2. Replace each of the 8 call sites with a single `Set-PeonConfig $config` call
3. Run Pester tests to confirm no behavior change
4. Verify no culture-swap + Set-Content sequences remain outside the helper

**Risk Mitigation:**
* Risk: Missing a call site or subtle difference between sites. Mitigation: Grep for all `ConvertTo-Json -Depth 10` and `Set-Content` patterns in install.ps1 to ensure complete coverage.
* Risk: Culture state leak on error. Mitigation: Use try/finally in the helper to guarantee culture restoration.

**Rollback Plan:**
* Git revert — single commit, no migration needed.

**Success Criteria:**
* All existing Pester tests pass without modification
* Zero remaining bare culture-swap + config-write sequences in install.ps1
* Each former call site reduced to 1-2 lines

---

## Refactoring Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | Existing Pester tests provide safety net | - [ ] Comprehensive tests exist before refactoring starts. |
| **Baseline Measurements** | 8 duplicate culture-swap + config-write sequences | - [ ] Baseline metrics captured (complexity, performance, coverage). |
| **Incremental Refactoring** | TBD | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | N/A — no user-facing doc changes needed | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | TBD | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |
| **Performance Validation** | N/A — no performance-sensitive path | - [ ] Performance validated - no regression, ideally improvement. |
| **Staging Deployment** | N/A — CLI tool | - [ ] Refactored code validated in staging environment. |
| **Production Deployment** | N/A — ships with next release | - [ ] Refactored code deployed to production with monitoring. |

---

## Safe Refactoring Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Existing Pester tests in `tests/adapters-windows.Tests.ps1` | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | TBD — run `Invoke-Pester` before changes | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | 8 duplicate sequences, ~40-50 lines of boilerplate | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Add `Set-PeonConfig` function, replace first call site | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | TBD | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | TBD | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | Replace remaining 7 call sites | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | No user-facing doc changes needed | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | N/A — no linter configured | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | TBD | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | N/A | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | N/A | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | Ships with next version bump | - [ ] Gradual production rollout with monitoring. |

#### Refactoring Implementation Notes

**Refactoring Techniques Applied:**
* Extract Method: Consolidate 8 identical culture-swap + config-write sequences into `Set-PeonConfig`

**Code Quality Improvements:**
* Lines of boilerplate: ~50 -> ~10 (helper definition only)
* Call site verbosity: 5-6 lines each -> 1 line each
* Culture-restore safety: ad-hoc -> guaranteed via try/finally

**Before/After Comparison:**
```powershell
# Before: 5-6 lines repeated 8 times
$savedCulture = [Threading.Thread]::CurrentThread.CurrentCulture
[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$config | ConvertTo-Json -Depth 10 | Set-Content $configPath
[Threading.Thread]::CurrentThread.CurrentCulture = $savedCulture

# After: 1 line per call site
Set-PeonConfig $config $configPath
```

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | `install.ps1` — `Set-PeonConfig` helper + 8 simplified call sites |
| **Test Suite** | Existing Pester tests must pass without modification |
| **Baseline Metrics (Before)** | 8 duplicate culture-swap sequences, ~50 lines boilerplate |
| **Final Metrics (After)** | TBD |
| **Performance Validation** | N/A |
| **Style & Linting** | N/A |
| **Code Review** | TBD |
| **Documentation Updates** | None required |
| **Staging Validation** | N/A |
| **Production Deployment** | Ships with next version bump |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | Check if `peon.ps1` has the same pattern — if so, apply same helper there |
| **Test Suite Improvements?** | Existing tests should suffice |
| **Documentation Complete?** | No user-facing changes needed |
| **Technical Debt Reduced?** | Yes — eliminates DRY violation discovered in unkjkl review |

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
