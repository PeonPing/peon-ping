# Generic Chore Task Template

**When to use this template:** Use this for straightforward maintenance tasks, dependency updates, configuration changes, documentation updates, cleanup work, or any technical work that needs basic progress tracking but doesn't require the structure of specialized templates.

**When NOT to use this template:** Do not use this for bugs (use `bug.md`), new features (use `feature.md`), refactoring (use `refactor.md`), or code style work (use `style-formatting.md`). Use specialized templates when the work requires specific workflows or validation.

---

## Task Overview

* **Task Description:** Add diagnostic logging (stderr or debug file) for silent failure paths in `win-play.ps1` and the embedded `peon.ps1` within `install.ps1`, so that corrupted installs or runtime errors produce visible diagnostics instead of silently dropping audio.
* **Motivation:** Multiple silent failure paths exist in the Windows audio pipeline: (1) `win-play.ps1` missing from disk is silently skipped, and (2) empty `catch {}` blocks swallow all exceptions in WAV playback and state-write paths. These make debugging audio issues on Windows nearly impossible.
* **Scope:** `scripts/win-play.ps1` and `install.ps1` (embedded `peon.ps1`). Specifically:
  - The `if (Test-Path $winPlayScript)` guard that silently skips audio when `win-play.ps1` is missing — add stderr warning.
  - Empty `catch {}` blocks in the WAV playback path and state-write path — add conditional logging (e.g., when `$DebugPreference` is set or a `PEON_DEBUG` env var is present).
* **Related Work:** Flagged during review of card HOOKBUG-d5wz2f (async audio delegation). These are pre-existing tech debt items, not regressions.
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
| **1. Review Current State** | Identify all silent failure paths in `win-play.ps1` and embedded `peon.ps1` | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Design a lightweight debug logging approach (stderr + optional `PEON_DEBUG` env var) | - [ ] Change plan is documented. |
| **3. Make Changes** | Add `Write-Warning` or `Write-Error` to silent guard clauses; replace empty `catch {}` with conditional debug logging | - [ ] Changes are implemented. |
| **4. Test/Verify** | Verify audio still works normally; verify diagnostics appear when `PEON_DEBUG` is set | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | Document `PEON_DEBUG` env var in README if exposed to users | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Items from reviewer feedback on HOOKBUG-d5wz2f:
> - **L2:** Silent failure when `win-play.ps1` is missing. The `if (Test-Path $winPlayScript)` guard silently skips audio if the script doesn't exist. A corrupted install where win-play.ps1 is missing produces no sound with no diagnostic output. Consider logging to stderr.
> - **L3:** Empty `catch {}` blocks swallow all exceptions in WAV playback path. Both in the embedded peon.ps1 state write and in win-play.ps1 WAV path, empty catch blocks swallow errors silently. At minimum, log to a debug file or stderr when `$DebugPreference` is set.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | `scripts/win-play.ps1`, `install.ps1` |
| **Pull Request** | |
| **Testing Performed** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | |
| **Documentation Updates Needed?** | |
| **Follow-up Work Required?** | |
| **Process Improvements?** | |
| **Automation Opportunities?** | |

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
