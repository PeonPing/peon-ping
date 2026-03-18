---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking systematic test suite audits to identify test quality issues, anti-patterns, and coverage gaps, with structured tracking of findings and follow-up improvements.
use_case: Use this for comprehensive test quality audits to find tautological tests, over-mocked tests, missing assertions, brittle assertions, coverage gaps, and other test anti-patterns. Tracks remediation work and documentation updates.
patterns_used:
  - section: "Audit Scope & Objectives"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Test Suite Baseline Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Initial Test Quality Assessment"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Audit Execution by Module/Component"
    pattern: "Pattern 3: Iterative Log"
  - section: "Remediation Work Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Audit Completion & Follow-up"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Test Suite Quality Audit Template

**When to use this template:** Use this when conducting a systematic audit of test quality to identify anti-patterns, improve test reliability, increase meaningful coverage, or assess test suite health. Ideal for quarterly test reviews, pre-refactoring audits, or when test maintenance has become problematic.

**When NOT to use this template:** Do not use this for writing new tests or fixing individual test failures. Use `test.md` for test development, `bug.md` for test failures, or `chore.md` for routine test maintenance. This template is specifically for comprehensive quality audits.

---

## Audit Scope & Objectives

* **Audit Target:** [What test suite is being audited, e.g., "Backend API integration tests", "Frontend component tests", "E2E test suite"]
* **Module/Component Scope:** [Specific areas to audit, e.g., "All tests in src/services/", "UI tests for dashboard module", "Full test suite (all)"]
* **Audit Trigger:** [Why this audit is happening, e.g., "Quarterly test health review", "Pre-refactoring assessment", "Test suite has become unreliable"]
* **Test Framework(s):** [What frameworks are used, e.g., "pytest", "Jest + React Testing Library", "Cypress"]
* **Current Test Count:** [Baseline metrics, e.g., "450 unit tests, 120 integration tests, 30 E2E tests"]
* **Current Coverage:** [If known, e.g., "85% line coverage, 70% branch coverage" or "Unknown - need to measure"]
* **Definition of Done:** [What success looks like, e.g., "All anti-patterns documented, remediation plan created, coverage >90%"]

**Required Checks:**
* [ ] **Audit target** and scope are clearly defined.
* [ ] **Test framework(s)** are identified.
* [ ] **Current test count** and coverage baseline are documented.
* [ ] **Definition of done** for audit is specified.

---

## Test Suite Baseline Review

Before auditing individual tests, review existing test documentation, coverage reports, and test infrastructure.

* [ ] Test documentation (README, testing guide) reviewed for current best practices.
* [ ] Coverage reports generated and reviewed (line, branch, function coverage).
* [ ] Test configuration files reviewed (pytest.ini, jest.config.js, etc.).
* [ ] CI/CD test pipeline reviewed for flakiness, runtime, and failure patterns.
* [ ] Previous test audit reports or test debt tickets reviewed.

Use the table below to document baseline findings. Add rows as needed.

| Baseline Metric | Current Value | Notes / Issues |
| :--- | :--- | :--- |
| **Total Test Count** | [e.g., "600 tests"] | [e.g., "Growth from 400 tests 6 months ago"] |
| **Line Coverage** | [e.g., "85%"] | [e.g., "Down from 90% last quarter"] |
| **Branch Coverage** | [e.g., "70%"] | [e.g., "Many conditional branches untested"] |
| **Test Runtime** | [e.g., "12 minutes full suite"] | [e.g., "2x slower than 6 months ago"] |
| **Flaky Test Rate** | [e.g., "5 tests fail intermittently"] | [e.g., "Tests: test_async_timeout, test_cache_race"] |
| **Test Documentation** | [e.g., "Outdated - last updated 2023"] | [e.g., "New patterns not documented"] |
| **Mocking Strategy** | [e.g., "Inconsistent - mix of unittest.mock and pytest-mock"] | [e.g., "No standard approach"] |

---

## Initial Test Quality Assessment

> Use this space for initial observations, common patterns noticed, hypothesis about systemic issues, and areas of concern before detailed audit.

**Initial Observations:**
* [e.g., "Many tests have single assert statements - may be missing edge cases"]
* [e.g., "Heavy use of mocking - unclear if integration paths are tested"]
* [e.g., "Test names don't follow consistent naming convention"]
* [e.g., "Some test files have 1000+ lines - need modularization"]

**Known Test Anti-Patterns to Look For:**
* Tautological tests (tests that can't fail or test nothing)
* Over-mocked tests (mocking everything, not testing real integration)
* Missing assertions (tests that run code but don't verify behavior)
* Brittle assertions (tests that break on irrelevant changes)
* Shortcut tests (tests that skip setup/teardown or use production data)
* Non-deterministic tests (flaky tests with race conditions or timing issues)
* God tests (single test covering too many scenarios)
* Commented-out tests or skipped tests without explanation

**Hypothesis About Systemic Issues:**
* [e.g., "Hypothesis: High mock usage suggests tight coupling in production code"]
* [e.g., "Hypothesis: Low branch coverage indicates missing negative case tests"]

---

## Audit Execution by Module/Component

Track audit progress module by module, documenting specific findings and severity for each area audited.

| Module # | Module/Component Name | Audit Status | Issues Found | Severity |
| :---: | :--- | :--- | :--- | :---: |
| **1** | [e.g., "Auth Service Tests"] | [Complete/In Progress/Not Started] | [Count, e.g., "12 issues found"] | [H/M/L] |
| **2** | [e.g., "User Management Tests"] | [Complete/In Progress/Not Started] | [Count] | [H/M/L] |
| **3** | [Module name...] | [Status...] | [Count...] | [Severity...] |

---

#### Module 1: [Module/Component Name, e.g., "Auth Service Tests"]

**Audit Date:** [e.g., "2025-01-15"]

**Test Files Audited:** [List files, e.g., "tests/services/test_auth.py (300 lines, 25 tests)"]

**Findings:**

| Finding # | Anti-Pattern Type | Specific Issue | Test Name/Location | Severity | Remediation |
| :---: | :--- | :--- | :--- | :---: | :--- |
| **1** | Tautological | [e.g., "Test asserts True is True, doesn't test actual behavior"] | [e.g., "test_user_creation line 45"] | H | [e.g., "Rewrite to assert user.id is not None and user.email == expected"] |
| **2** | Over-mocked | [e.g., "Mocks database, API client, AND cache - no integration tested"] | [e.g., "test_login_flow line 120"] | M | [e.g., "Create integration test with real DB (testcontainers)"] |
| **3** | Missing assertions | [e.g., "Test calls logout() but never asserts session is cleared"] | [e.g., "test_logout line 200"] | H | [e.g., "Add assert session.get('user_id') is None"] |
| **4** | Brittle assertion | [e.g., "Asserts exact JSON structure - breaks on any field addition"] | [e.g., "test_user_response line 250"] | M | [e.g., "Use schema validation or assert only critical fields"] |
| **5** | Flaky test | [e.g., "Race condition in async test - fails 10% of time"] | [e.g., "test_concurrent_login line 300"] | H | [e.g., "Add proper awaits and event synchronization"] |

**Summary for Module 1:**
* Total Issues: [Count, e.g., "5 issues"]
* High Severity: [Count, e.g., "3"]
* Medium Severity: [Count, e.g., "2"]
* Low Severity: [Count, e.g., "0"]

**Recommended Actions:**
* [e.g., "Create follow-up card to rewrite 3 high-severity test issues"]
* [e.g., "Document mocking strategy in test README"]

---

#### Module 2: [Module/Component Name]

**Audit Date:** [Date]

**Test Files Audited:** [List files]

**Findings:**

| Finding # | Anti-Pattern Type | Specific Issue | Test Name/Location | Severity | Remediation |
| :---: | :--- | :--- | :--- | :---: | :--- |
| **1** | [Type] | [Issue] | [Location] | [H/M/L] | [Remediation] |
| **2** | [Type] | [Issue] | [Location] | [H/M/L] | [Remediation] |

**Summary for Module 2:**
* Total Issues: [Count]
* High Severity: [Count]
* Medium Severity: [Count]
* Low Severity: [Count]

**Recommended Actions:**
* [Action items]

---

#### Module 3: [Module/Component Name]

[Continue pattern for each module audited - copy and paste this block as needed]

---

## Remediation Work Phases

Track the execution of follow-up work identified during the audit. This acts as a table of contents for remediation tasks.

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **High-Severity Issues** | [e.g., "Card TEST-123 created for 8 critical issues" or "Status: In Progress"] | - [ ] All high-severity issues have remediation cards or are fixed. |
| **Medium-Severity Issues** | [e.g., "Card TEST-124 created for 15 medium issues" or "Status: Not Started"] | - [ ] All medium-severity issues are documented and prioritized. |
| **Coverage Gaps** | [e.g., "Card TEST-125 for missing branch coverage" or "Status: Complete"] | - [ ] Coverage gaps are addressed or documented as tech debt. |
| **Test Infrastructure** | [e.g., "Card INFRA-200 for flaky test fixes" or "Status: In Progress"] | - [ ] Infrastructure improvements (flakiness, runtime) are addressed. |
| **Documentation Updates** | [e.g., "PR #456 - Updated test README with patterns" or "Link to updated docs"] | - [ ] Test documentation reflects current best practices. |
| **Team Training** | [e.g., "Scheduled test quality workshop for 2025-02-01" or "N/A"] | - [ ] Team training on test patterns completed [if needed]. |

---

## Audit Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Audit Report** | [Link to final audit document or summary report] |
| **Total Issues Found** | [Count by severity, e.g., "25 high, 40 medium, 15 low = 80 total"] |
| **Coverage Improvement** | [Target and plan, e.g., "Goal: 90% branch coverage, plan in TEST-125"] |
| **Remediation Timeline** | [Estimate, e.g., "High-severity fixes: 2 weeks, Medium: 4 weeks"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Test Quality Standards Document?** | [e.g., "Created docs/testing-standards.md" or "Link to existing doc updated"] |
| **Pre-commit Test Hooks?** | [e.g., "Added coverage threshold check to pre-commit" or "Not needed"] |
| **CI/CD Pipeline Changes?** | [e.g., "Added test quality gates - fail build on <85% coverage" or "No changes"] |
| **Recurring Audit Schedule?** | [e.g., "Added quarterly test audit to team calendar" or "Not scheduled"] |
| **Follow-up Cards Created?** | [List all follow-up cards, e.g., "TEST-123 (high), TEST-124 (medium), TEST-125 (coverage)"] |
| **Test Debt Documented?** | [e.g., "Added 10 test debt items to backlog" or "Link to test debt epic"] |
| **Team Retrospective?** | [e.g., "Scheduled for 2025-02-15 to discuss audit findings" or "Not needed"] |

### Completion Checklist

* [ ] All modules/components in scope have been audited.
* [ ] All findings are documented with severity and remediation guidance.
* [ ] High-severity issues have follow-up cards created or are fixed.
* [ ] Medium-severity issues are documented and prioritized.
* [ ] Coverage gaps are identified and remediation plan exists.
* [ ] Test infrastructure issues (flakiness, runtime) are addressed or have follow-up cards.
* [ ] Test documentation is updated to reflect current best practices.
* [ ] Final audit report is published and shared with team.
* [ ] Recurring audit schedule is established (if appropriate).

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
