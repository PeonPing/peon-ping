---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A lightweight template for tracking generic chore tasks, maintenance work, and technical project management activities that don't fit specialized templates.
use_case: Use this for basic maintenance tasks, dependency updates, configuration changes, documentation updates, cleanup work, or any technical project management activities that need simple progress tracking and logging.
patterns_used:
  - section: "Task Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Work Log"
    pattern: "Pattern 4: Process Workflow"
  - section: "Completion & Follow-up"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Generic Chore Task Template

**When to use this template:** Use this for straightforward maintenance tasks, dependency updates, configuration changes, documentation updates, cleanup work, or any technical work that needs basic progress tracking but doesn't require the structure of specialized templates.

**When NOT to use this template:** Do not use this for bugs (use `bug.md`), new features (use `feature.md`), refactoring (use `refactor.md`), or code style work (use `style-formatting.md`). Use specialized templates when the work requires specific workflows or validation.

---

## Task Overview

* **Task Description:** [Brief description of what needs to be done, e.g., "Update Python dependencies to latest stable versions", "Clean up deprecated configuration files", "Update API documentation"]
* **Motivation:** [Why this work is needed, e.g., "Security patches available", "Files no longer used after refactoring", "Documentation outdated after recent changes"]
* **Scope:** [What will be changed, e.g., "requirements.txt and poetry.lock", "config/ directory", "docs/api/"]
* **Related Work:** [Optional links to related tickets, PRs, or documentation, e.g., "Related to FEATURE-123", "Follow-up from REFACTOR-456"]
* **Estimated Effort:** [Optional time estimate, e.g., "2 hours", "Half day", "1-2 days"]

**Required Checks:**
* [ ] **Task description** clearly states what needs to be done.
* [ ] **Motivation** explains why this work is necessary.
* [ ] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | [e.g., "Reviewed requirements.txt, found 15 outdated packages" or "Link to file(s)"] | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | [e.g., "Created list of packages to update, checked compatibility" or "Documented changes needed"] | - [ ] Change plan is documented. |
| **3. Make Changes** | [e.g., "Updated packages, regenerated lock file" or "Link to commit/PR"] | - [ ] Changes are implemented. |
| **4. Test/Verify** | [e.g., "Ran test suite, all passing" or "Verified config loads correctly"] | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | [e.g., "Updated CHANGELOG.md" or "Updated README with new config format" or "N/A"] | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | [e.g., "PR #789 approved and merged" or "Self-review complete for minor change"] | - [ ] Changes are reviewed and merged. |

#### Work Notes

> Use this space for any additional notes, commands run, decisions made, or issues encountered during the work.

**Commands/Scripts Used:**
```bash
# Example: Dependency update commands
pip install --upgrade package-name
pip freeze > requirements.txt
```

**Decisions Made:**
* [e.g., "Decided to skip updating package X to v3.0 due to breaking changes - will handle in separate ticket"]
* [e.g., "Removed deprecated config files instead of archiving - team agreed in Slack"]

**Issues Encountered:**
* [e.g., "Package Y had compatibility issue with Z - downgraded Y to v2.8"]
* [e.g., "Found additional deprecated files not listed in original scope - added to cleanup"]

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | [Summary, e.g., "Updated 15 Python packages, removed 8 deprecated config files"] |
| **Files Modified** | [Count or list, e.g., "3 files changed: requirements.txt, poetry.lock, pyproject.toml"] |
| **Pull Request** | [Link to PR, e.g., "PR #789" or "N/A - direct commit to main (minor change)"] |
| **Testing Performed** | [Description, e.g., "Full test suite passed (450 tests)", "Manual verification of config loading"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | [e.g., "Yes - found 10 more deprecated files, created CHORE-567" or "No"] |
| **Documentation Updates Needed?** | [e.g., "Yes - updated README and CHANGELOG" or "No updates needed"] |
| **Follow-up Work Required?** | [e.g., "Yes - created TECH-890 to update package X in separate effort" or "No"] |
| **Process Improvements?** | [e.g., "Added dependency update schedule to team calendar" or "N/A"] |
| **Automation Opportunities?** | [e.g., "Could automate with dependabot - created INFRA-234" or "N/A"] |

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
