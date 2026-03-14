---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking sprint cleanup work including deferred tasks, documentation updates, technical debt, and maintenance items that were deprioritized during feature development.
use_case: Use this for end-of-sprint cleanup, post-release housekeeping, or consolidating deferred maintenance tasks into a single tracking card.
patterns_used:
  - section: "Cleanup Scope & Context"
    pattern: "Pattern 1: Section Header"
  - section: "Deferred Work Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Cleanup Checklist"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Validation & Closeout"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Sprint Cleanup Template

## Cleanup Scope & Context

* **Sprint/Release:** [e.g., "Sprint 24 (Q4 2024)" or "v2.3.0 Release"]
* **Primary Feature Work:** [e.g., "User authentication overhaul" or "API v2 migration"]
* **Cleanup Category:** [e.g., "Documentation debt" or "Mixed (tests + docs + refactoring)"]

**Required Checks:**
* [ ] Sprint/Release is identified above.
* [ ] Primary feature work that generated this cleanup is documented.

---

## Deferred Work Review

First, identify what was deferred or left incomplete during the main feature work. Review commit messages, PR comments, code TODOs, and team discussions for items marked "not in scope" or "do later."

* [ ] Reviewed commit messages for "TODO" and "FIXME" comments added during sprint.
* [ ] Reviewed PR comments for "out of scope" or "follow-up needed" discussions.
* [ ] Reviewed code for new TODO/FIXME markers (grep for them).
* [ ] Checked team chat/standup notes for deferred items.

Use the table below to log all deferred work. Add rows as needed for each category of cleanup.

| Cleanup Category | Specific Item / Location | Priority | Justification for Cleanup |
| :--- | :--- | :---: | :--- |
| **Documentation** | [e.g., "README.md - setup instructions outdated"] | [P0/P1/P2] | [e.g., "New auth flow not documented, will confuse new devs"] |
| **Documentation** | [e.g., "api.md - 3 new endpoints missing"] | P2 | [e.g., "External API users need these docs"] |
| **Docstrings** | [e.g., "auth.py - 8 functions lack docstrings"] | P1 | [e.g., "Core auth module should be well-documented"] |
| **Tests** | [e.g., "Missing integration test for password reset"] | P0 | [e.g., "Critical path not covered, risk of regression"] |
| **Tests** | [e.g., "Unit test coverage dropped to 65%"] | P1 | [e.g., "Team standard is 80%, need to close gap"] |
| **Broken/Flaky** | [e.g., "test_session_timeout fails 30% of time"] | P0 | [e.g., "Blocks CI, must fix"] |
| **Technical Debt** | [e.g., "Hardcoded API key in config.py (marked TODO)"] | P0 | [e.g., "Security risk, must move to env var"] |
| **Technical Debt** | [e.g., "Duplicate validation logic in 3 files"] | P2 | [e.g., "Should be DRY, but not urgent"] |
| **Dependencies** | [e.g., "requests==2.28.0 has CVE-2023-xxxxx"] | P0 | [e.g., "Security vulnerability"] |
| **Dependencies** | [e.g., "5 dependencies with available minor updates"] | P2 | [e.g., "Good to stay current, low risk"] |
| **Refactoring** | [e.g., "auth_handler.py is 800 lines, should split"] | P2 | [e.g., "Maintainability - hard to navigate"] |
| **Unused Code** | [e.g., "legacy_auth.py not imported anywhere"] | P2 | [e.g., "Dead code adds confusion"] |
| **Error Handling** | [e.g., "No logging in error paths of user_service.py"] | P1 | [e.g., "Can't debug production issues"] |
| **Configuration** | [e.g., "Dev/prod configs are inconsistent"] | P1 | [e.g., "Caused staging bug last week"] |
| **Build/CI** | [e.g., "Linter warnings ignored (34 total)"] | P2 | [e.g., "Should address before they pile up"] |
| **Nice-to-Have** | [e.g., "Add pretty-print to error messages"] | P2 | [e.g., "UX improvement, not critical"] |

---

## Cleanup Checklist

Below is a comprehensive checklist of common cleanup tasks. Check off items as you complete them, and add rows for sprint-specific items.

### Documentation Updates (optional)

| Task | Status / Details | Done? |
| :--- | :--- | :---: |
| **README.md** | [e.g., "Updated setup instructions for new auth flow"] | - [ ] |
| **API Documentation** | [e.g., "Added 3 missing endpoints to api.md"] | - [ ] |
| **Architecture Docs** | [e.g., "Updated system diagram with new auth service"] | - [ ] |
| **Runbooks/Playbooks** | [e.g., "Added troubleshooting section for auth failures"] | - [ ] |
| **CHANGELOG** | [e.g., "Added v2.3.0 entries"] | - [ ] |
| **ADRs** | [e.g., "Wrote ADR-015 for auth provider choice"] | - [ ] |
| **Inline Comments** | [e.g., "Added comments to complex token validation logic"] | - [ ] |
| **Docstrings** | [e.g., "Added docstrings to 8 functions in auth.py"] | - [ ] |
| **Other:** [Custom] | [Details] | - [ ] |

### Testing & Quality (optional)

| Task | Status / Details | Done? |
| :--- | :--- | :---: |
| **Missing Unit Tests** | [e.g., "Added 12 tests for auth edge cases"] | - [ ] |
| **Missing Integration Tests** | [e.g., "Added end-to-end test for password reset"] | - [ ] |
| **Test Coverage** | [e.g., "Increased from 65% to 82%"] | - [ ] |
| **Flaky Tests** | [e.g., "Fixed test_session_timeout race condition"] | - [ ] |
| **Test Data/Fixtures** | [e.g., "Added fixtures for auth test scenarios"] | - [ ] |
| **Performance Tests** | [e.g., "Added load test for auth endpoint"] | - [ ] |
| **Other:** [Custom] | [Details] | - [ ] |

### Code Quality & Technical  (optional)

| Task | Status / Details | Done? |
| :--- | :--- | :---: |
| **TODOs Resolved** | [e.g., "Resolved 8/12 TODOs, created tickets for 4"] | - [ ] |
| **FIXMEs Addressed** | [e.g., "Fixed all 3 FIXMEs in auth module"] | - [ ] |
| **Dead Code Removed** | [e.g., "Deleted legacy_auth.py and 3 unused utils"] | - [ ] |
| **Duplicate Code** | [e.g., "Extracted common validation to shared module"] | - [ ] |
| **Magic Numbers/Strings** | [e.g., "Moved hardcoded timeouts to config"] | - [ ] |
| **Error Handling** | [e.g., "Added logging to 6 error paths"] | - [ ] |
| **Code Formatting** | [e.g., "Ran formatter on all modified files"] | - [ ] |
| **Linter Warnings** | [e.g., "Resolved 34/34 warnings"] | - [ ] |
| **Other:** [Custom] | [Details] | - [ ] |

### Dependencies &  (optional)

| Task | Status / Details | Done? |
| :--- | :--- | :---: |
| **Dependency Updates** | [e.g., "Updated requests to 2.31.0 (security fix)"] | - [ ] |
| **Vulnerability Fixes** | [e.g., "Patched CVE-2023-xxxxx"] | - [ ] |
| **Lockfile Updates** | [e.g., "Regenerated requirements.txt and poetry.lock"] | - [ ] |
| **Deprecated APIs** | [e.g., "Replaced deprecated bcrypt.hashpw call"] | - [ ] |
| **License Compliance** | [e.g., "Verified all deps are MIT/Apache"] | - [ ] |
| **Other:** [Custom] | [Details] | - [ ] |

### Configuration & Environment (optional)

| Task | Status / Details | Done? |
| :--- | :--- | :---: |
| **Hardcoded Secrets** | [e.g., "Moved API key to env var"] | - [ ] |
| **Config Consistency** | [e.g., "Aligned dev/staging/prod configs"] | - [ ] |
| **Environment Variables** | [e.g., "Documented all env vars in .env.example"] | - [ ] |
| **Default Values** | [e.g., "Set sane defaults for optional config"] | - [ ] |
| **Other:** [Custom] | [Details] | - [ ] |

### Build & CI/CD (optional)

| Task | Status / Details | Done? |
| :--- | :--- | :---: |
| **CI Pipeline** | [e.g., "Fixed flaky CI test that blocked merges"] | - [ ] |
| **Build Scripts** | [e.g., "Updated Makefile with new test command"] | - [ ] |
| **Docker/Containers** | [e.g., "Updated Dockerfile base image"] | - [ ] |
| **Pre-commit Hooks** | [e.g., "Added hook for checking TODOs"] | - [ ] |
| **Other:** [Custom] | [Details] | - [ ] |

### Refactoring & Code Organization (optional)

| Task | Status / Details | Done? |
| :--- | :--- | :---: |
| **File/Module Splitting** | [e.g., "Split auth_handler.py into 3 modules"] | - [ ] |
| **Naming Improvements** | [e.g., "Renamed ambiguous variables in token logic"] | - [ ] |
| **Function Extraction** | [e.g., "Extracted 200-line function into 4 helpers"] | - [ ] |
| **Import Cleanup** | [e.g., "Removed unused imports"] | - [ ] |
| **Other:** [Custom] | [Details] | - [ ] |

---

## Validation & Closeout

### Pre-Completion Verification

| Verification Task | Status / Evidence |
| :--- | :--- |
| **All P0 Items Complete** | [e.g., "5/5 P0 items done and verified"] |
| **All P1 Items Complete or Ticketed** | [e.g., "8/10 P1 done, created TECH-456 and TECH-457 for remaining"] |
| **Tests Passing** | [e.g., "Full test suite passes (CI build #1234)"] |
| **No New Warnings** | [e.g., "Linter clean, no new warnings introduced"] |
| **Documentation Updated** | [e.g., "All doc updates reviewed by @teammate"] |
| **Code Review** | [e.g., "Cleanup PR #789 approved and merged"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Remaining P2 Items** | [e.g., "Created TECH-458 for remaining 4 P2 items"] |
| **Recurring Issues** | [e.g., "Docs consistently lag - need to make it part of Definition of Done"] |
| **Process Improvements** | [e.g., "Add 'cleanup time' to sprint planning to prevent this backlog"] |
| **Technical Debt Tickets** | [e.g., "Created TECH-459 for auth_handler.py refactoring"] |

### Completion Checklist

* [ ] All P0 items are complete and verified.
* [ ] All P1 items are complete or have follow-up tickets created.
* [ ] P2 items are complete or explicitly deferred with tickets.
* [ ] All tests are passing (unit, integration, and regression).
* [ ] No new linter warnings or errors introduced.
* [ ] All documentation updates are complete and reviewed.
* [ ] Code changes (if any) are reviewed and merged.
* [ ] Follow-up tickets are created and prioritized for next sprint.
* [ ] Team retrospective includes discussion of cleanup backlog (if significant).

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
