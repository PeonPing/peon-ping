
## Refactoring Overview & Motivation

* **Refactoring Target:** Pack resolution logic (default_pack / active_pack fallback chain) in install.ps1
* **Code Location:** `install.ps1`
* **Refactoring Type:** Extract Method — consolidate repeated conditional expression into a single `Get-ActivePack` helper function
* **Motivation:** The expression `if ($cfg.default_pack) { $cfg.default_pack } elseif ($cfg.active_pack) { $cfg.active_pack } else { "peon" }` (and its `$config.` variant) appears ~10 times across install.ps1. This duplication creates maintenance risk, especially when the legacy `active_pack` fallback key is eventually removed.
* **Business Impact:** Reduces maintenance burden and risk of inconsistency when modifying pack resolution behavior. Single source of truth for the fallback chain.
* **Scope:** ~10 call sites in 1 file (install.ps1)
* **Risk Level:** Low — isolated to installer script, well-tested by Pester suite
* **Related Work:** SMARTPACK sprint, legacy `active_pack` key deprecation

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
| **Existing Code** | `install.ps1` — ~10 occurrences of pack resolution expression | Duplicated across both `$cfg.` and `$config.` variable contexts |
| **Test Coverage** | `tests/adapters-windows.Tests.ps1` | Pester tests validate PowerShell adapters and install.ps1 behavior |
| **Documentation** | `README.md`, `CLAUDE.md` | No specific docs on pack resolution internals |
| **Style Guide** | N/A — no formatter configured for PowerShell | Follow existing codebase conventions |
| **Dependencies** | Used by: install.ps1 only (self-contained installer) | No external consumers of this internal logic |
| **Usage Patterns** | Called during install and pack management operations | Expression evaluated whenever active pack name is needed |
| **Previous Attempts** | None known | First extraction attempt |

---

## Refactoring Strategy & Risk Assessment

**Refactoring Approach:**
* Extract Method: Create a `Get-ActivePack` function that encapsulates the fallback chain (`default_pack` -> `active_pack` -> `"peon"`), then replace all ~10 call sites.

**Incremental Steps:**
1. Step 1: Identify and catalog all ~10 occurrences of the pattern in install.ps1
2. Step 2: Create `Get-ActivePack` helper function accepting a config object parameter
3. Step 3: Replace all call sites with the helper function
4. Step 4: Run Pester tests to validate no behavior change

**Risk Mitigation:**
* Risk: Subtle differences between call sites. Mitigation: Carefully audit each occurrence to ensure the helper signature covers all variants.
* Risk: Parameter naming differences (`$cfg` vs `$config`). Mitigation: Helper accepts generic parameter.

**Rollback Plan:**
* Rollback: Simple git revert — single commit, no external dependencies.

**Success Criteria:**
* All existing Pester tests pass without modification
* Pack resolution expression appears exactly once (in the helper function)
* No behavior change in any install scenario

---

## Refactoring Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | Pester tests exist in tests/adapters-windows.Tests.ps1 | - [ ] Comprehensive tests exist before refactoring starts. |
| **Baseline Measurements** | ~10 duplicate expressions across install.ps1 | - [ ] Baseline metrics captured (complexity, performance, coverage). |
| **Incremental Refactoring** | Not started | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | N/A — internal helper, no user-facing doc change needed | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | Not started | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |
| **Performance Validation** | N/A — no performance-sensitive path | - [ ] Performance validated - no regression, ideally improvement. |
| **Staging Deployment** | N/A — script-based tool | - [ ] Refactored code validated in staging environment. |
| **Production Deployment** | N/A — included in next release | - [ ] Refactored code deployed to production with monitoring. |

---

## Safe Refactoring Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | Pester tests exist | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | Not started | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | ~10 duplicate expressions | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | Not started | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | Not started | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | Not started | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | Not started | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | Not started | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | Not started | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | Not started | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | N/A | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | N/A | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | Not started | - [ ] Gradual production rollout with monitoring. |

#### Refactoring Implementation Notes

**Refactoring Techniques Applied:**
* Extract Method: Consolidate ~10 occurrences of pack resolution fallback chain into single `Get-ActivePack` helper

**Design Patterns Introduced:**
* None — simple helper function extraction

**Code Quality Improvements:**
* Duplication: 10 occurrences -> 1 (helper function + call sites)
* Maintenance risk reduced for future `active_pack` key removal

**Before/After Comparison:**
```powershell
# Before: Repeated ~10 times across install.ps1
$pack = if ($cfg.default_pack) { $cfg.default_pack } elseif ($cfg.active_pack) { $cfg.active_pack } else { "peon" }

# After: Single helper function
function Get-ActivePack($config) {
    if ($config.default_pack) { return $config.default_pack }
    if ($config.active_pack) { return $config.active_pack }
    return "peon"
}
$pack = Get-ActivePack $cfg
```

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | `install.ps1` |
| **Test Suite** | `tests/adapters-windows.Tests.ps1` |
| **Baseline Metrics (Before)** | ~10 duplicate pack resolution expressions |
| **Final Metrics (After)** | TBD |
| **Performance Validation** | N/A |
| **Style & Linting** | N/A — no linter configured |
| **Code Review** | TBD |
| **Documentation Updates** | Inline comments on helper function |
| **Staging Validation** | N/A |
| **Production Deployment** | Included in next version bump |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | Check if peon.ps1 has similar duplication |
| **Design Patterns Reusable?** | N/A |
| **Test Suite Improvements?** | Consider adding explicit test for Get-ActivePack helper |
| **Documentation Complete?** | TBD |
| **Performance Impact?** | Neutral |
| **Team Knowledge Sharing?** | N/A |
| **Technical Debt Reduced?** | Yes — eliminates duplicated pack resolution logic |
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
