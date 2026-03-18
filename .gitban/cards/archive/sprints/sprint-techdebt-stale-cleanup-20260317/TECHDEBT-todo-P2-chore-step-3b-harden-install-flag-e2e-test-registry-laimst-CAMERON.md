# Harden --install flag: E2E test, registry fallbacks, and help text

## Task Overview

* **Task Description:** Address 3 non-blocking review items from the `inexon` card (step 2c windows CLI bind/unbind quality improvements, review cycle 2): add a functional E2E test for the `--install` flag, restore registry field fallback defaults in the download path, and fix help text alignment regressions.
* **Motivation:** Reviewer flagged these as non-blocking items that should be tracked and addressed to harden the `--install` flag implementation and maintain consistent CLI help output.
* **Scope:** `install.ps1`, `tests/adapters-windows.Tests.ps1`
* **Related Work:** Originated from reviewer feedback on card `inexon` (step 2c windows CLI bind/unbind quality improvements). Planner file: `.gitban/agents/planner/inbox/SMARTPACKDEBT-inexon-planner-2.md`
* **Estimated Effort:** 2-4 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | L1: `--install` flag has no functional E2E test — only a structural regex test exists. A true E2E requires mocking the registry HTTP endpoint. L2: `--install` download path lost registry field fallbacks (`source_repo` defaults to "PeonPing/og-packs", `source_ref` defaults to "main", `source_path` defaults to pack name) and lost explicit "pack not found in registry" error message. L3: Help text alignment regression — `--help` output lost column alignment for `unbind`, and the `--pattern <glob>` and `--install` flags are no longer documented in help text. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | L1: Create E2E test that mocks registry HTTP endpoint and validates full `--install` flow. L2: Restore defensive defaults for `source_repo`, `source_ref`, `source_path` fields and add explicit "pack not found in registry" error. L3: Fix help text column alignment for `unbind` and add `--pattern <glob>` and `--install` to help output. | - [ ] Change plan is documented. |
| **3. Make Changes** | | - [ ] Changes are implemented. |
| **4. Test/Verify** | | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Three non-blocking items from inexon review cycle 2, grouped into one card per planner instructions.

**Items:**
* **L1 — E2E test gap:** `--install` flag has no functional E2E test. The acceptance criteria checkbox is marked done but only a structural regex test exists. A true E2E requires mocking the registry HTTP endpoint. Track and implement when feasible.
* **L2 — Registry fallback defaults lost:** `--install` download path lost registry field fallbacks (`source_repo` defaults to "PeonPing/og-packs", `source_ref` defaults to "main", `source_path` defaults to pack name) and lost explicit "pack not found in registry" error message. Restore defensive defaults.
* **L3 — Help text alignment regression:** The `--help` output lost column alignment for `unbind`, and the `--pattern <glob>` and `--install` flags are no longer documented in help text.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | `install.ps1`, `tests/adapters-windows.Tests.ps1` |
| **Pull Request** | |
| **Testing Performed** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
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
