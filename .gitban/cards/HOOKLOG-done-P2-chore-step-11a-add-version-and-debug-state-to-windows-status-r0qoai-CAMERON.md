# step 11A: Add version and debug state to Windows status output

## Task Overview

* **Task Description:** The `peon --status` handler in `peon.ps1` (install.ps1:593-668) is missing two lines that exist on Unix: version number and debug logging state. Add both to match `peon.sh` parity.
* **Motivation:** Smoke test finding (card 6qfugq). Users on Windows have no way to see the installed version or whether debug logging is active from `peon --status`. Unix shows both.
* **Scope:** `install.ps1` status handler only. Two additions: version line (essential, always shown) and debug state line (verbose only).
* **Related Work:** HOOKLOG sprint, card 2d99d1 (verbose gating in peon.sh), card nnj6gt (verbose gating in peon.ps1).

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
|:-----|:---------------|:---------------:|
| **1. Review peon.sh reference** | Read peon.sh status handler — version from `$PEON_DIR/VERSION` file, debug state from `PEON_DEBUG` env var. Unix status handler does not yet show these; Windows implementation uses same data sources. | - [x] Current state is understood and documented. |
| **2. Add version line** | Added `$versionFile = Join-Path $InstallDir "VERSION"` and included `version $version` in the main status line. Always shown. | - [x] Changes are implemented. |
| **3. Add debug state line** | Added in verbose block: reads `$env:PEON_DEBUG`, shows `debug logging: enabled/disabled`. When enabled, also shows log dir path. | - [x] Changes are implemented. |
| **4. Update Pester tests** | Added 4 Pester tests: 2 structural (content match) + 2 functional (E2E) covering version and debug logging output. All pass. | - [x] Changes are tested/verified. |
| **5. Verify** | Ran targeted Pester tests: 4 passed, 0 failed. | - [x] Changes are tested/verified. |

#### Required Reading

| File | Location | What to look for |
|:-----|:---------|:-----------------|
| `install.ps1` | Lines 593-668 | `--status` handler, `$isVerbose` gating |
| `peon.sh` | Lines 1029-1037 | Unix debug status reference implementation |
| `peon.sh` | Line 4259 | Unix version display (`$PEON_DIR/VERSION`) |
| `tests/adapters-windows.Tests.ps1` | Status tests | Existing status output assertions |

---

## Completion & Follow-up

| Task | Detail/Link |
|:-----|:------------|
| **Changes Made** | Added version line to status output (always shown), debug logging state to verbose output |
| **Files Modified** | `install.ps1`, `tests/adapters-windows.Tests.ps1` |
| **Pull Request** | Sprint PR #405 |
| **Testing Performed** | 4 targeted Pester tests: 2 structural + 2 functional, all passing |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
|:------|:------------------------|
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No — README already documents `peon status`, output format is implementation detail |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |


## Work Summary

- Commit `55596c4`: feat: add version and debug state to Windows peon --status
- `install.ps1` line 590-591: reads `VERSION` file from `$InstallDir`, displays on main status line
- `install.ps1` line 632-639: in `--verbose` block, reads `$env:PEON_DEBUG`, shows enabled/disabled + log dir when enabled
- Note: Unix `peon.sh` status handler does not yet show version or debug state; this card adds Windows parity with the *intended* Unix behavior per the card spec. A follow-up card could add the same to peon.sh.

## Review Log

- **Review 1** (2026-03-26): **APPROVAL** at commit `9939dab`. No blockers, no follow-up items. Report: `.gitban/agents/reviewer/inbox/HOOKLOG-r0qoai-reviewer-1.md`