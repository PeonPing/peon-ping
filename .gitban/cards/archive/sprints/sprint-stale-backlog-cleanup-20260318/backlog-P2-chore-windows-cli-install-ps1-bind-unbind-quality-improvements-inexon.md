# Windows CLI install.ps1 bind/unbind quality improvements

## Task Overview

* **Task Description:** Address two quality issues in `install.ps1` related to the bind/unbind CLI commands: (1) sequential sound downloads without parallelism or progress feedback in `--install`, and (2) duplicated config I/O pattern across bind/unbind/bindings subcommands.
* **Motivation:** Reviewer-flagged tech debt from SMARTPACK sprint. The `--install` flag downloads sounds one-at-a-time (lines 484-518), which can take 30+ seconds for large packs with no output. The config read/write pattern is duplicated across three subcommands and should be consolidated.
* **Scope:** `install.ps1` — bind/unbind/bindings subcommands
* **Related Work:** Flagged during SMARTPACK-9pjhy5 code review
* **Estimated Effort:** Half day

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | `--install` flag (lines 484-518) fetches registry, manifest, and each sound file sequentially via `Invoke-WebRequest`. No parallelism, no progress feedback. Config I/O pattern (`Get-Content \| ConvertFrom-Json` ... `ConvertTo-Json \| Set-Content`) duplicated in bind, unbind, and bindings. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | L1: Extract shared `Install-Pack` function or call pack-download logic; add parallelism and progress output. Add end-to-end test. L3: Extract `Update-PeonConfig { param($Mutator) }` helper to reduce duplication. | - [x] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Reviewer items from SMARTPACK-9pjhy5 review:

**Items:**
* **L1 (should fix):** `--install` flag downloads sounds one-at-a-time without parallelism or progress feedback. For packs with 40+ sounds this could take 30+ seconds with no output. Consider extracting a shared `Install-Pack` function or calling pack-download logic. No functional test covers `--install` end-to-end.
* **L3 (nice to have):** Duplicated config I/O pattern across bind/unbind/bindings. Each subcommand independently does `Get-Content | ConvertFrom-Json`, manipulates `path_rules`, then `ConvertTo-Json | Set-Content`. Consider a helper like `Update-PeonConfig { param($Mutator) }` to reduce duplication.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | |
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
