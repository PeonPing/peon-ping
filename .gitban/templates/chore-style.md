---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking code style, formatting, and readability improvements that enhance code quality and maintainability without changing functionality.
use_case: Use this for code formatting fixes, linting violations, readability refactoring, naming convention updates, documentation formatting, and other non-functional code quality improvements.
patterns_used:
  - section: "Style Improvement Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Current Code Quality Assessment"
    pattern: "Pattern 2: Structured Review"
  - section: "Style Improvement Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Validation & Quality Check"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Code Style & Formatting Improvement Template

**When to use this template:** Use this when making code style, formatting, or readability improvements that do not change functionality. Examples include fixing linting violations, applying consistent formatting, improving variable naming, adding code comments for clarity, or organizing imports.

**When NOT to use this template:** Do not use this for functional changes, refactoring that changes code structure, or bug fixes. Use `refactor.md` for structural changes, `bug.md` for fixes, or `chore.md` for general maintenance tasks that don't fit style improvements.

---

## Style Improvement Overview

* **Scope:** [What code is being improved, e.g., "All Python files in src/services/", "TypeScript components in ui/dashboard/"]
* **Style Issue Type:** [e.g., "Linting violations (ESLint)", "Inconsistent naming conventions", "Missing type hints", "Formatting inconsistencies"]
* **Motivation:** [Why this matters, e.g., "Reduces cognitive load for new developers", "Enables automated tooling", "Meets team standards"]
* **Automated Tooling:** [Tools that will be used, e.g., "Black (Python formatter)", "Prettier (JS/TS)", "ESLint --fix", "isort (import sorting)"]
* **Files Affected:** [Estimated count or file pattern, e.g., "~25 files in src/services/**/*.py"]

**Required Checks:**
* [ ] **Scope** of style improvements is clearly defined.
* [ ] **Style issue type** is identified (linting, formatting, naming, etc.).
* [ ] **Automated tooling** (if any) is specified.
* [ ] **Files affected** estimate is provided.

---

## Current Code Quality Assessment

Before making changes, review current code quality and identify specific issues to address.

* [ ] Linting report generated and reviewed.
* [ ] Code style guide or team standards document reviewed.
* [ ] Existing formatting configuration files reviewed (e.g., `.prettierrc`, `pyproject.toml`, `.eslintrc`).
* [ ] Related documentation (README, contributing guide) reviewed for style guidelines.

Use the table below to document specific issues found. Add rows as needed.

| Issue Category | Location / Files | Specific Issue | Priority |
| :--- | :--- | :--- | :---: |
| **Linting Violations** | [e.g., `src/services/*.py`] | [e.g., "120 violations: unused imports, line too long, missing docstrings"] | [H/M/L] |
| **Naming Conventions** | [e.g., `ui/components/UserDashboard.tsx`] | [e.g., "Components use inconsistent naming: some PascalCase, some camelCase"] | [H/M/L] |
| **Import Organization** | [e.g., `src/**/*.py`] | [e.g., "Imports not sorted, mix of absolute and relative imports"] | [M] |
| **Type Annotations** | [e.g., `src/utils/*.py`] | [e.g., "50% of functions missing type hints"] | [M] |
| **Code Comments** | [e.g., `src/core/engine.py`] | [e.g., "Complex algorithms lack explanatory comments"] | [L] |
| **Formatting Inconsistency** | [e.g., `tests/**/*.js`] | [e.g., "Inconsistent spacing, quote styles, semicolon usage"] | [M] |

---

## Style Improvement Workflow

Follow this process to ensure style changes are applied consistently and safely without breaking functionality.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Verify Tests Pass (Baseline)** | [e.g., "All 450 tests passing as of 2025-01-15" or "Link to CI run"] | - [ ] Confirmed that all existing tests pass before changes. |
| **2. Configure Automated Tooling** | [e.g., "Added .prettierrc config, enabled ESLint autofix" or "Updated pyproject.toml"] | - [ ] Tooling configuration is committed and documented. |
| **3. Apply Automated Fixes** | [e.g., "Ran `black .` and `isort .`" or "Ran `eslint --fix`" or "Link to commit"] | - [ ] Automated formatting/fixes are applied via tooling. |
| **4. Manual Style Improvements** | [e.g., "Fixed 12 complex naming issues" or "Added comments to algorithm in engine.py"] | - [ ] Manual improvements (if any) are completed and committed. |
| **5. Verify Tests Still Pass** | [e.g., "All 450 tests still passing" or "Link to CI run post-changes"] | - [ ] Confirmed that all tests still pass after style changes. |
| **6. Code Review** | [e.g., "PR #456 approved by 2 reviewers" or "Self-review completed for minor changes"] | - [ ] Changes are reviewed to ensure no functional impact. |

#### Tooling Configuration

> Document any configuration files added or modified for automated tooling.

```toml
# Example: pyproject.toml for Black and isort
[tool.black]
line-length = 100
target-version = ['py39']

[tool.isort]
profile = "black"
line_length = 100
```

```json
// Example: .prettierrc for JavaScript/TypeScript
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "printWidth": 100
}
```

---

## Validation & Quality Check

| Task | Detail/Link |
| :--- | :--- |
| **Pre-Change Test Results** | [Link to baseline CI run showing all tests passing] |
| **Post-Change Test Results** | [Link to CI run after style changes showing all tests still passing] |
| **Linting Report (Before)** | [e.g., "120 violations" or "Link to initial linting output"] |
| **Linting Report (After)** | [e.g., "0 violations" or "Link to final linting output showing improvements"] |
| **Files Changed** | [Count and list, e.g., "25 files modified" or "Link to PR file list"] |
| **Lines Changed** | [Approximate count, e.g., "~500 lines of formatting changes"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Pre-commit Hooks Updated?** | [e.g., "Yes - added Black and isort to pre-commit" or "No - not needed"] |
| **CI/CD Pipeline Updated?** | [e.g., "Yes - added ESLint check to CI" or "No - already enforced"] |
| **Documentation Updated?** | [e.g., "Yes - updated CONTRIBUTING.md with style guide" or "Link to updated docs"] |
| **Team Style Guide?** | [e.g., "Created team style guide document" or "Link to existing guide"] |
| **Automated Enforcement?** | [e.g., "Yes - linting now runs in CI, blocks merge on violations" or "No - manual for now"] |

### Completion Checklist

* [ ] All identified style issues are addressed or documented as follow-up.
* [ ] Automated tooling configuration (if added) is committed and documented.
* [ ] All tests pass before and after style changes (no functional regressions).
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pre-commit hooks or CI checks are updated to prevent future style drift.
* [ ] Documentation (README, CONTRIBUTING.md, style guide) is updated if needed.
* [ ] Follow-up tickets created for any deferred style improvements.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
