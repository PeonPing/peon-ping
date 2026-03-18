# Extend PEON_DEBUG diagnostics to embedded peon.ps1 early-exit catch blocks and add behavioral test coverage

**When to use this template:** Use this for straightforward maintenance tasks, dependency updates, configuration changes, documentation updates, cleanup work, or any technical work that needs basic progress tracking but doesn't require the structure of specialized templates.

**When NOT to use this template:** Do not use this for bugs (use `bug.md`), new features (use `feature.md`), refactoring (use `refactor.md`), or code style work (use `style-formatting.md`). Use specialized templates when the work requires specific workflows or validation.

---

## Task Overview

* **Task Description:** Two related improvements to PEON_DEBUG diagnostics in embedded peon.ps1: (1) Add `if ($peonDebug) { Write-Warning ... }` before `exit 0` in four silent catch blocks (config read failure ~L760, stdin read failure ~L774, JSON parse failure ~L782, manifest parse failure ~L1087) so users debugging with PEON_DEBUG=1 can understand why the hook exited early. (2) Add behavioral Pester tests that actually trigger the diagnostic warning paths (state write, category check, sound lookup, missing win-play.ps1) instead of relying solely on structural regex validation.
* **Motivation:** The catch blocks exit silently, making it impossible to diagnose "can't run at all" scenarios when PEON_DEBUG=1 is set. The existing test suite only validates warning strings structurally via regex — behavioral tests that invoke the embedded script with mock config, state, and manifests would provide stronger guarantees.
* **Scope:** `install.ps1` (embedded peon.ps1 catch blocks), `tests/peon-debug.Tests.ps1` (behavioral test additions)
* **Related Work:** Follow-up from e40fvu (PEON_DEBUG test coverage) and um5fz2 (adapter catch block diagnostics). Reviewer findings in TECHDEBT2-e40fvu-planner-1.md.
* **Estimated Effort:** 2-3 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Identify the four silent catch blocks in embedded peon.ps1 and confirm line numbers. Review existing regex-based tests in peon-debug.Tests.ps1. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Design PEON_DEBUG warning messages for each catch block. Design behavioral test harness that can invoke embedded peon.ps1 with mock config/state/manifests. | - [ ] Change plan is documented. |
| **3. Make Changes** | Add `if ($peonDebug) { Write-Warning "PEON_DEBUG: ..." }` before each `exit 0` in the four catch blocks. Add behavioral Pester tests. | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run `Invoke-Pester -Path tests/peon-debug.Tests.ps1` — all tests pass. Run `Invoke-Pester -Path tests/adapters-windows.Tests.ps1` — no regressions. | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal diagnostics only. | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR reviewed and merged. | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Use this space for any additional notes, commands run, decisions made, or issues encountered during the work.

**Catch blocks to update (embedded peon.ps1 in install.ps1):**
* Config read failure (~L760): `catch { exit 0 }`
* Stdin read failure (~L774): `catch { exit 0 }`
* JSON parse failure (~L782): `catch { exit 0 }`
* Manifest parse failure (~L1087): `catch { exit 0 }`

**Behavioral test paths to cover:**
* State write warning
* Category check warning
* Sound lookup warning
* Missing win-play.ps1 warning

**Decisions Made:**
* (pending)

**Issues Encountered:**
* (pending)

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | (pending) |
| **Files Modified** | (pending) |
| **Pull Request** | (pending) |
| **Testing Performed** | (pending) |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No — internal diagnostics only |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.