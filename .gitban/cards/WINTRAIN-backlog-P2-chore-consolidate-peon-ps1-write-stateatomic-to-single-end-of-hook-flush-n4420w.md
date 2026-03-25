# Consolidate peon.ps1 Write-StateAtomic to single end-of-hook flush

**When to use this template:** Use this for straightforward maintenance tasks, dependency updates, configuration changes, documentation updates, cleanup work, or any technical work that needs basic progress tracking but doesn't require the structure of specialized templates.

**When NOT to use this template:** Do not use this for bugs (use `bug.md`), new features (use `feature.md`), refactoring (use `refactor.md`), or code style work (use `style-formatting.md`). Use specialized templates when the work requires specific workflows or validation.

---

## Task Overview

* **Task Description:** Refactor `peon.ps1` (embedded in `install.ps1`) to use a single end-of-hook `Write-StateAtomic` call gated by `$stateDirty`, instead of the current 3 separate calls at lines ~1422, ~1576, and ~1687. The `$stateDirty` variable already exists (line ~1325) and is set but never consumed.
* **Motivation:** The Unix reference (`peon.sh`) uses a `state_dirty` flag and writes once at the end. The PowerShell code currently performs up to 3 disk writes per invocation, which is unnecessary I/O. This also fulfills the "single atomic write" promise documented in ADR-002.
* **Scope:** `install.ps1` (embedded `peon.ps1` section) — remove intermediate `Write-StateAtomic` calls and add a single gated write at the end of the hook execution path.
* **Related Work:** Origin: review feedback on card 2twy3o (WINTRAIN-2twy3o-planner-1.md, Card 1). Related: card 26yooi (Write-StateAtomic atomic overwrite upgrade, blocked on PS 5.1 EOL — separate concern).
* **Estimated Effort:** 1-2 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Audit all `Write-StateAtomic` call sites in peon.ps1 (~lines 1422, 1576, 1687) and confirm `$stateDirty` is set but never consumed (~line 1325) | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Map each call site — confirm all state mutations set `$stateDirty = $true`, then remove intermediate writes and add single gated write at end of hook | - [ ] Change plan is documented. |
| **3. Make Changes** | Remove 3 intermediate `Write-StateAtomic` calls; add `if ($stateDirty) { Write-StateAtomic ... }` at end of hook execution | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run Pester tests (`Invoke-Pester -Path tests/adapters-windows.Tests.ps1`), manual smoke test with a real hook invocation | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal refactor, no user-facing doc changes needed | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Key implementation detail: ensure every code path that mutates `$state` also sets `$stateDirty = $true`. The existing variable assignment at line ~1325 suggests this was the original intent but was never completed.

**Decisions Made:**
* This is separate from card 26yooi which addresses making `Write-StateAtomic` itself truly atomic (rename-over pattern) — that is blocked on PS 5.1 EOL.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | TBD |
| **Files Modified** | install.ps1 (embedded peon.ps1) |
| **Pull Request** | TBD |
| **Testing Performed** | TBD |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | 26yooi — Write-StateAtomic atomic overwrite upgrade (separate card, blocked on PS 5.1 EOL) |
| **Documentation Updates Needed?** | No |
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
