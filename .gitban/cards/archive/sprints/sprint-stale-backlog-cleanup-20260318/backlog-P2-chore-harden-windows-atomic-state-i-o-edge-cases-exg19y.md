# Harden Windows atomic state I/O edge cases

**When to use this template:** Technical debt hardening for Windows PowerShell state I/O in `install.ps1` (embedded `peon.ps1` hook).

---

## Task Overview

* **Task Description:** Harden two edge cases in the Windows PowerShell state management code (`Write-StateAtomic` and safety timer) within the embedded `peon.ps1` hook in `install.ps1`.
* **Motivation:** Reviewer flagged two non-blocking reliability gaps during the SMARTPACK sprint (card z0c9fd review). Both are low-risk but worth hardening for correctness.
* **Scope:** `install.ps1` — embedded `peon.ps1` hook code, specifically `Write-StateAtomic` and the safety timer exit path.
* **Related Work:** Flagged during SMARTPACK sprint review of card z0c9fd. Related to archived card kydihy (atomic state writes) and backlog card lyq5ta (state helper DRY-up).
* **Estimated Effort:** 1-2 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Two edge cases identified in review: (L1) non-atomic window in `Write-StateAtomic` between `[IO.File]::Delete` and `[IO.File]::Move`; (L2) safety timer uses `[Environment]::Exit(1)` which skips `finally` blocks and may leave `.tmp` files | - [x] Current state is understood and documented. |
| **2. Plan Changes** | L1: Add PS version check — on PS 7+ use `Move-Item -Force` (truly atomic, overwrites target) instead of delete-then-move. L2: Either switch to `exit 1` (runs trap handlers) or add `.tmp` cleanup on next startup in `Read-StateWithRetry`. | - [ ] Change plan is documented. |
| **3. Make Changes** | Pending | - [ ] Changes are implemented. |
| **4. Test/Verify** | Pending | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal implementation detail | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Pending | - [ ] Changes are reviewed and merged. |

#### Work Notes

> **Item L1 — Non-atomic window in `Write-StateAtomic`:**
> `Write-StateAtomic` currently does `[IO.File]::Delete($target)` then `[IO.File]::Move($tmp, $target)`. There is a sub-millisecond window where the target does not exist. On PowerShell 7+, `Move-Item -Force` performs an atomic overwrite. Add a `$PSVersionTable.PSVersion.Major -ge 7` check to use the safer path when available.
>
> **Item L2 — Safety timer skips `finally` blocks:**
> The safety timer fires `[Environment]::Exit(1)` which bypasses `finally` blocks and cleanup. If state has been partially written, this could leave a `.tmp` file behind. Two options: (a) switch to `exit 1` which runs trap handlers, or (b) add a `.tmp` file cleanup check at the start of `Read-StateWithRetry` on next invocation.

**Decisions Made:**
* Both items are low-risk hardening (sub-millisecond race window, rare timeout scenario) but worth fixing for correctness.

**Issues Encountered:**
* None yet — work not started.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Pending |
| **Files Modified** | `install.ps1` (embedded peon.ps1 hook) |
| **Pull Request** | Pending |
| **Testing Performed** | Pending |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | Card lyq5ta (dry-up state helpers) may overlap — coordinate. |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | TBD |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
