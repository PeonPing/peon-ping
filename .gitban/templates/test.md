---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the implementation of tests across unit, integration, E2E, and performance testing.
use_case: "Use this when you need to ensure test coverage for a specific feature, fix, or system component."
patterns_used:
  - section: "Test Overview"
    pattern: "Pattern 1: Section Header with metadata"
  - section: "Test Strategy"
    pattern: "Pattern 2: Structured Review with test pyramid guidance"
  - section: "Test Scenarios"
    pattern: "Pattern 3: BDD Given/When/Then format"
  - section: "Implementation Checklist"
    pattern: "Pattern 4: Progressive Checklist"
  - section: "Test Data & Fixtures"
    pattern: "Pattern 5: Structured Data Requirements"
  - section: "Acceptance Criteria"
    pattern: "Pattern 6: Exit Criteria Checklist"
---

# Test Implementation Card

**When to use this template:** Use this when you need to add, improve, or verify test coverage for any part of the system - whether unit tests, integration tests, E2E tests, or performance benchmarks.

**When NOT to use this template:** Don't use this for test audits across multiple systems (use `test-audit`), user acceptance testing (use `test-user`), or when tests are a small part of a larger feature card.

---

## Test Overview

**Test Type:** [Unit | Integration | E2E | Performance | Contract | Smoke]

**Target Component:** [Module, service, or feature being tested]

**Related Cards:** [Link to feature/bug cards this testing supports]

**Coverage Goal:** [Specific coverage target or "comprehensive coverage of X"]

---

## Test Strategy

### Test Pyramid Placement
Where do these tests fit in the testing pyramid?

| Layer | Tests Planned | Rationale |
|-------|---------------|-----------|
| Unit | [Number or "N/A"] | [Why this layer] |
| Integration | [Number or "N/A"] | [Why this layer] |
| E2E | [Number or "N/A"] | [Why this layer] |
| Performance | [Number or "N/A"] | [Why this layer] |

### Testing Approach
- **Framework:** [pytest, Jest, Playwright, k6, etc.]
- **Mocking Strategy:** [What to mock, what to use real implementations for]
- **Isolation Level:** [Full isolation / Shared fixtures / Database per test]

---

## Test Scenarios

### Scenario 1: [Happy Path - Primary Use Case]
- **Given:** [Initial state/preconditions]
- **When:** [Action or trigger]
- **Then:** [Expected outcome]
- **Priority:** [Critical | High | Medium | Low]

### Scenario 2: [Edge Case - Boundary Condition]
- **Given:** [Initial state/preconditions]
- **When:** [Action at boundary]
- **Then:** [Expected behavior at edge]
- **Priority:** [Critical | High | Medium | Low]

### Scenario 3: [Error Case - Invalid Input]
- **Given:** [Initial state/preconditions]
- **When:** [Invalid action or bad data]
- **Then:** [Expected error handling]
- **Priority:** [Critical | High | Medium | Low]

### Scenario 4: [Negative Case - Unauthorized/Forbidden]
- **Given:** [Unauthorized state]
- **When:** [Attempted action]
- **Then:** [Expected rejection/error]
- **Priority:** [Critical | High | Medium | Low]

[Add more scenarios as needed using the same format]

---

## Test Data & Fixtures

### Required Test Data
| Data Type | Description | Source |
|-----------|-------------|--------|
| [e.g., User] | [Valid user with permissions] | [Factory / Fixture / Mock] |
| [e.g., Config] | [Test configuration] | [Environment / File] |

### Edge Case Data
- **Empty/Null:** [How to test empty states]
- **Maximum Values:** [Boundary testing data]
- **Invalid Formats:** [Malformed input examples]
- **Unicode/Special Chars:** [Internationalization test data]

### Fixture Setup
```
[Pseudocode or actual setup code for test fixtures]
```

---

## Implementation Checklist

### Setup Phase
- [ ] Test file[s] created in correct location
- [ ] Test fixtures/factories defined
- [ ] Mocks and stubs configured
- [ ] Test database/state initialized [if needed]

### Test Implementation
- [ ] Happy path tests written and passing
- [ ] Edge case tests written and passing
- [ ] Error handling tests written and passing
- [ ] Negative/security tests written and passing
- [ ] Performance assertions added [if applicable]

### Quality Gates
- [ ] All tests pass locally
- [ ] All tests pass in CI
- [ ] No flaky tests introduced
- [ ] Test execution time acceptable
- [ ] Code coverage meets target [if applicable]

### Documentation
- [ ] Test file has clear docstrings/comments
- [ ] Complex test logic explained
- [ ] Setup/teardown documented

---

## Acceptance Criteria

- [ ] All planned scenarios have corresponding tests
- [ ] Tests are deterministic [no flakiness]
- [ ] Tests run in isolation [no order dependency]
- [ ] Tests are fast enough for CI [<X seconds]
- [ ] Coverage target met: [X%] or [specific areas covered]
- [ ] Tests follow project conventions

---

## Troubleshooting Log (optional)

Use this section to track issues encountered during test implementation:

| Issue | Investigation | Resolution |
|-------|---------------|------------|
| [Test failure description] | [What you tried] | [How it was fixed] |

---

## Notes

[Any additional context, lessons learned, or follow-up items]
