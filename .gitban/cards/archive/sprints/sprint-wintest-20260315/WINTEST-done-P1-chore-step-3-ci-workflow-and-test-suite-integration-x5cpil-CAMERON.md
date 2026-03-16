# Generic Chore Task Template

**When to use this template:** Final integration card for the WINTEST sprint -- updates CI to discover all new test files and verifies the full suite.

---

## Task Overview

* **Task Description:** Update `.github/workflows/test.yml` to discover and run all new Pester test files (not just `tests/adapters-windows.Tests.ps1`), verify the full suite passes on windows-latest, and ensure total execution time stays under 60 seconds. Also clean up superseded card gtb6dm.
* **Motivation:** The WINTEST sprint splits tests across 5 files. The current CI workflow hardcodes a single test file path. Without this update, new functional tests will not run in CI.
* **Scope:** `.github/workflows/test.yml` (Pester invocation), verify all `tests/*.Tests.ps1` files, archive card gtb6dm.
* **Related Work:** WINTEST sprint cards: q52ygy (step 1), 1dnbzv (step 2A), lxhqpf (step 2B), jwh5zl (step 2C), frjune (step 2D). Supersedes card gtb6dm.
* **Estimated Effort:** 1-2 hours

**Required Checks:**
- [x] **Task description** clearly states what needs to be done.
- [x] **Motivation** explains why this work is necessary.
- [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Current CI: `$config.Run.Path = "tests/adapters-windows.Tests.ps1"` hardcoded in `.github/workflows/test.yml` line 56. Only runs one test file. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Change Run.Path to `"tests/"` so Pester auto-discovers all `*.Tests.ps1`. Verify `windows-setup.ps1` is NOT a `.Tests.ps1` file. Add deepagents.ps1 to syntax validation step if not already done in step 2B. | - [x] Change plan is documented. |
| **3. Make Changes** | Update test.yml, verify all test files run, archive gtb6dm | - [x] Changes are implemented. |
| **4. Test/Verify** | Run `Invoke-Pester -Path tests/` locally on both PS 5.1 and PS 7+. All tests green. Execution under 60s. | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A -- internal CI change | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review | - [x] Changes are reviewed and merged. |

#### Work Notes

**Key change (test.yml):**
```yaml
# Before:
$config.Run.Path = "tests/adapters-windows.Tests.ps1"

# After:
$config.Run.Path = "tests/"
```

**File organization verification:**
- `tests/windows-setup.ps1` -- shared harness (NOT a .Tests.ps1 file, Pester ignores it)
- `tests/adapters-windows.Tests.ps1` -- existing structural/lint tests (KEPT)
- `tests/peon-engine.Tests.ps1` -- core engine functional tests
- `tests/peon-adapters.Tests.ps1` -- adapter translation functional tests
- `tests/peon-security.Tests.ps1` -- security and edge case tests
- `tests/peon-packs.Tests.ps1` -- pack selection functional tests

**Decisions Made:**
* Shared setup file named `windows-setup.ps1` (no `.Tests.` in name) so Pester auto-discovery skips it
* Existing structural tests in `adapters-windows.Tests.ps1` are preserved as a lint layer

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | CI workflow updated to discover all test files |
| **Files Modified** | `.github/workflows/test.yml` |
| **Pull Request** | |
| **Testing Performed** | Full Pester suite on PS 5.1 + PS 7+, all green, under 60s |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | Card gtb6dm superseded by WINTEST sprint -- archive it |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | Future test cards should add to existing test files, not create new infrastructure |
| **Automation Opportunities?** | N/A |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.
