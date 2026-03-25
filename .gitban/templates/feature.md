---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the complete lifecycle of feature development using TDD, from planning through deployment.
use_case: Use this for any new feature work that requires design, implementation, testing, and documentation. Enforces TDD workflow and comprehensive validation.
patterns_used:
  - section: "Feature Overview & Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Documentation & Prior Art Review"
    pattern: "Pattern 2: Structured Review (Doc Review)"
  - section: "Design & Planning"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Feature Work Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "TDD Implementation Workflow"
    pattern: "Pattern 4: Process Workflow (TDD)"
  - section: "Validation & Closeout"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Feature Development Template

**When to use this template:** Use this for any new feature work that requires planning, design, implementation, testing, and documentation. Perfect for features following TDD methodology with clear acceptance criteria and quality gates.

**When NOT to use this template:** Do not use for bug fixes (use bug template), refactoring work (use refactor template), or research/exploration (use spike template). For simple chores or maintenance, use the chore template.

## Feature Overview & Context

* **Associated Ticket/Epic:** [e.g., Link to JIRA ticket, GitHub issue, or epic]
* **Feature Area/Component:** [e.g., "Authentication System", "API Gateway", "User Dashboard"]
* **Target Release/Milestone:** [e.g., "v2.1.0", "Q4 2024", "Sprint 15"]

**Required Checks:**
* [ ] **Associated Ticket/Epic** link is included above.
* [ ] **Feature Area/Component** is identified.
* [ ] **Target Release/Milestone** is confirmed.

## Documentation & Prior Art Review

First, confirm the minimum required documentation has been reviewed for context.

* [ ] `README.md` or project documentation reviewed.
* [ ] Existing architecture documentation or ADRs reviewed.
* [ ] Related feature implementations or similar code reviewed.
* [ ] API documentation or interface specs reviewed [if applicable].

Use the table below to log findings. Add rows for other document types as needed.

| Document Type | Link / Location | Key Findings / Action Required |
| :--- | :--- | :--- |
| **README.md** | [Link] | [e.g., "Setup instructions current, no conflicts expected"] |
| **Architecture Docs** | [Link] | [e.g., "Existing auth flow documented, can extend pattern"] |
| **Similar Features** | [Link] | [e.g., "User profile feature has similar validation needs"] |
| **API Specs** | [Link] | [e.g., "OpenAPI spec needs new endpoint definitions"] |
| **ADR (New)** | **N/A** (Action Item) | [e.g., "**Finding:** Feature requires new data persistence pattern. **Action:** Must write ADR for storage approach."] |
| **Other Documentation** | [Link] | [Findings...] |

## Design & Planning

### Initial Design Thoughts & Requirements

> Use this space for initial design ideas, key requirements, constraints, and architectural considerations.

* [e.g., Requirement: "Must support OAuth2 and SAML authentication"]
* [e.g., Constraint: "Must maintain backward compatibility with v1 API"]
* [e.g., Design thought: "Could use adapter pattern for multiple auth providers"]
* [e.g., Known unknown: "Need to verify performance requirements for concurrent users"]
* [e.g., Dependency: "Requires Redis for session storage"]

### Acceptance Criteria

Define clear, testable acceptance criteria for this feature:

* [ ] [Criterion 1, e.g., "Users can log in using OAuth2 providers (Google, GitHub)"]
* [ ] [Criterion 2, e.g., "Session tokens expire after 24 hours"]
* [ ] [Criterion 3, e.g., "Failed login attempts are logged for security audit"]
* [ ] [Criterion 4, e.g., "API returns 401 with clear error message for invalid tokens"]
* [ ] [Criterion 5, e.g., "All endpoints maintain <200ms response time"]

## Feature Work Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Design & Architecture** | [e.g., Link to ADR, design doc, or Figma] | - [ ] Design Complete |
| **Test Plan Creation** | [e.g., Link to test strategy doc or test cases] | - [ ] Test Plan Approved |
| **TDD Implementation** | [e.g., Link to PR(s) or implementation branch] | - [ ] Implementation Complete |
| **Integration Testing** | [e.g., Link to test results or CI pipeline] | - [ ] Integration Tests Pass |
| **Documentation** | [e.g., Link to updated README, API docs, user guide] | - [ ] Documentation Complete |
| **Code Review** | [e.g., Link to PR review or approval] | - [ ] Code Review Approved |
| **Deployment Plan** | [e.g., Link to deployment runbook or rollout plan] | - [ ] Deployment Plan Ready |

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | [e.g., Link to commit with test suite] | - [ ] Failing tests are committed and documented |
| **2. Implement Feature Code** | [e.g., Summary of files changed, link to implementation commits] | - [ ] Feature implementation is complete |
| **3. Run Passing Tests** | [e.g., Test run ID, CI pipeline link] | - [ ] Originally failing tests now pass |
| **4. Refactor** | [e.g., Link to refactoring commits] | - [ ] Code is refactored for clarity and maintainability |
| **5. Full Regression Suite** | [e.g., Link to full test run, CI pipeline] | - [ ] All tests pass (unit, integration, e2e) |
| **6. Performance Testing** | [e.g., Link to performance test results] | - [ ] Performance requirements are met |

### Implementation Notes

> Document key implementation decisions, test approach, and code examples here.

**Test Strategy:**
[e.g., "Using pytest fixtures for auth mocking. Integration tests use real Redis instance in Docker. E2E tests use Playwright for browser automation."]

**Key Implementation Decisions:**
[e.g., "Selected FastAPI dependency injection for auth middleware. Using JWT with RS256 signing for token security."]

```python
# Example: Paste key code snippets or test examples here
def test_oauth_login_success():
    """Test successful OAuth2 login flow"""
    # Test implementation...
```

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | [e.g., Link to approved PR] |
| **QA Verification** | [e.g., Verified by QA Team on Date] |
| **Staging Deployment** | [e.g., Deployed to staging environment on Date] |
| **Production Deployment** | [e.g., Deployed to production on Date] |
| **Monitoring Setup** | [e.g., Link to dashboard, alerts configured] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Postmortem Required?** | [e.g., No (smooth deployment) or Yes (minor issues, document learnings)] |
| **Further Investigation?** | [e.g., Yes (Monitor performance under load for 2 weeks)] |
| **Technical Debt Created?** | [e.g., Yes (Created ticket TECH-456 to refactor legacy auth module)] |
| **Future Enhancements** | [e.g., Created feature request FEAT-789 for biometric authentication] |

### Completion Checklist

* [ ] All acceptance criteria are met and verified.
* [ ] All tests are passing (unit, integration, e2e, performance).
* [ ] Code review is approved and PR is merged.
* [ ] Documentation is updated (README, API docs, user guides).
* [ ] Feature is deployed to production.
* [ ] Monitoring and alerting are configured.
* [ ] Stakeholders are notified of completion.
* [ ] Follow-up actions are documented and tickets created.
* [ ] Associated ticket/epic is closed.

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
