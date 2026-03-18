---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking safe code refactoring with comprehensive testing, documentation updates, style guide compliance, and regression prevention to ensure no functionality is broken during code improvement.
use_case: Use this for code restructuring, architecture improvements, dependency updates, design pattern implementation, or technical debt reduction. Enforces test coverage, documentation updates, code review, and incremental changes to prevent breaking functionality.
patterns_used:
  - section: "Refactoring Overview & Motivation"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Pre-Refactoring Context Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Refactoring Strategy & Risk Assessment"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Refactoring Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Safe Refactoring Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Refactoring Validation & Completion"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Code Refactoring Template

**When to use this template:** Use this for code restructuring, architecture improvements, dependency updates, design pattern implementation, or technical debt reduction that changes code structure without changing functionality. Ensures safe refactoring with proper testing, documentation updates, and incremental changes.

**When NOT to use this template:** Do not use this for bug fixes (use `bug.md`), new features (use `feature.md`), or simple formatting changes (use `chore-style.md`). This template is specifically for substantive code restructuring that requires careful validation to ensure no functionality is broken.

---

## Refactoring Overview & Motivation

* **Refactoring Target:** [What code is being refactored, e.g., "User authentication module", "Database access layer", "API response handler"]
* **Code Location:** [Path to code, e.g., "src/auth/", "lib/database.py", "api/handlers/users.go"]
* **Refactoring Type:** [Type of refactoring, e.g., "Extract method", "Replace conditional with polymorphism", "Introduce design pattern", "Modernize dependencies"]
* **Motivation:** [Why refactor, e.g., "Code duplication across 5 modules", "Hard to test due to tight coupling", "Performance bottleneck", "Technical debt blocking new features"]
* **Business Impact:** [Why this matters, e.g., "Enables user roles feature", "Reduces bug rate", "Improves developer velocity by 30%", "Required for compliance"]
* **Scope:** [How much code affected, e.g., "250 lines in 3 files", "Full authentication module (10 files, 2000 lines)", "Single function (50 lines)"]
* **Risk Level:** [Assessment, e.g., "Low - isolated utility function", "Medium - shared library with 10 consumers", "High - core business logic"]
* **Related Work:** [Links, e.g., "Tech debt ticket TECH-456", "ADR-030 for design pattern choice", "Performance spike PERF-789"]

**Required Checks:**
* [ ] **Refactoring motivation** clearly explains why this change is needed.
* [ ] **Scope** is specific and bounded (not open-ended "improve everything").
* [ ] **Risk level** is assessed based on code criticality and usage.

---

## Pre-Refactoring Context Review

Before refactoring, review existing code, tests, documentation, and dependencies to understand current implementation and prevent breaking changes.

* [ ] Existing code reviewed and behavior fully understood.
* [ ] Test coverage reviewed - current test suite provides safety net.
* [ ] Documentation reviewed (README, docstrings, inline comments).
* [ ] Style guide and coding standards reviewed for compliance.
* [ ] Dependencies reviewed (internal modules, external libraries).
* [ ] Usage patterns reviewed (who calls this code, how it's used).
* [ ] Previous refactoring attempts reviewed (if any - learn from history).

Use the table below to document findings from pre-refactoring review. Add rows as needed.

| Review Source | Link / Location | Key Findings / Constraints |
| :--- | :--- | :--- |
| **Existing Code** | [e.g., "src/auth/login.py lines 45-150"] | [e.g., "200 line function with 5 responsibilities - violates SRP"] |
| **Test Coverage** | [e.g., "tests/auth/test_login.py"] | [e.g., "80% coverage - missing edge case tests for token expiry"] |
| **Documentation** | [e.g., "docs/auth.md, docstrings in login.py"] | [e.g., "Docstrings outdated - describe old behavior from 2023"] |
| **Style Guide** | [e.g., "docs/style-guide.md"] | [e.g., "Must use type hints (PEP 484), max function length 50 lines"] |
| **Dependencies** | [e.g., "Used by: user service, admin service, mobile API"] | [e.g., "3 services depend on this - breaking changes affect multiple teams"] |
| **Usage Patterns** | [e.g., "grep analysis, call graph"] | [e.g., "Called 10000 times/day, hot path in API - performance critical"] |
| **Previous Attempts** | [e.g., "TECH-234 (2024) - incomplete refactor"] | [e.g., "Previous attempt abandoned due to test failures - be cautious"] |

---

## Refactoring Strategy & Risk Assessment

> Use this space for refactoring approach, incremental steps, risk mitigation, and rollback plan.

**Refactoring Approach:**
* [e.g., "Extract Method: Split 200-line login function into 6 smaller functions (authenticate, validate_token, check_permissions, etc.)"]
* [e.g., "Introduce Strategy Pattern: Replace conditional logic with pluggable authentication strategies"]
* [e.g., "Strangler Fig: Incrementally replace old implementation with new, run both in parallel temporarily"]

**Incremental Steps:**
1. [e.g., "Step 1: Add comprehensive tests to lock in current behavior (100% coverage target)"]
2. [e.g., "Step 2: Extract token validation logic to separate function (smallest safe change)"]
3. [e.g., "Step 3: Extract permission checking logic to separate function"]
4. [e.g., "Step 4: Extract authentication logic to separate function"]
5. [e.g., "Step 5: Refactor main function to orchestrate extracted functions"]
6. [e.g., "Step 6: Update docstrings and inline comments"]

**Risk Mitigation:**
* [e.g., "Risk: Breaking existing API consumers. Mitigation: Use feature flag to toggle between old/new implementation"]
* [e.g., "Risk: Performance regression. Mitigation: Benchmark before/after, target <5% latency increase"]
* [e.g., "Risk: Test suite insufficient. Mitigation: Add tests BEFORE refactoring to achieve 95% coverage"]

**Rollback Plan:**
* [e.g., "Rollback: Feature flag allows instant revert to old code path"]
* [e.g., "Rollback: Git revert + hotfix deployment (estimated 15 minutes)"]
* [e.g., "Rollback: Keep old implementation as deprecated function for 1 release cycle"]

**Success Criteria:**
* [e.g., "All existing tests pass without modification"]
* [e.g., "Test coverage maintained or improved (target: 95%)"]
* [e.g., "Code complexity reduced (cyclomatic complexity <10)"]
* [e.g., "No performance regression (latency within 5% of baseline)"]
* [e.g., "Style guide compliance (linting passes)"]
* [e.g., "Documentation updated to reflect new structure"]

---

## Refactoring Phases

Track the major phases of refactoring from test establishment through deployment.

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Pre-Refactor Test Suite** | [e.g., "Added 15 tests, achieved 95% coverage" or "PR #789"] | - [ ] Comprehensive tests exist before refactoring starts. |
| **Baseline Measurements** | [e.g., "Baseline: cyclomatic complexity 25, latency 120ms" or "Link to metrics"] | - [ ] Baseline metrics captured (complexity, performance, coverage). |
| **Incremental Refactoring** | [e.g., "Completed 5/6 steps, PR #790 in review" or "Status: In Progress"] | - [ ] Refactoring implemented incrementally with passing tests at each step. |
| **Documentation Updates** | [e.g., "Updated docstrings, README, architecture docs" or "PR #791"] | - [ ] All documentation updated to reflect refactored code. |
| **Code Review** | [e.g., "PR #790 reviewed by Alice, Bob" or "Status: Approved"] | - [ ] Code reviewed for correctness, style guide compliance, maintainability. |
| **Performance Validation** | [e.g., "Latency 115ms (4% improvement), no regression" or "Link to benchmark"] | - [ ] Performance validated - no regression, ideally improvement. |
| **Staging Deployment** | [e.g., "Deployed to staging 2025-01-20, validated" or "Link to environment"] | - [ ] Refactored code validated in staging environment. |
| **Production Deployment** | [e.g., "Deployed to production 2025-01-25 with monitoring" or "Link to release"] | - [ ] Refactored code deployed to production with monitoring. |

---

## Safe Refactoring Workflow

Follow this workflow to ensure safe refactoring with no functionality broken. Each step must pass before proceeding.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Establish Test Safety Net** | [e.g., "Added 15 tests, coverage 95%" or "Link to test PR"] | - [ ] Comprehensive tests exist covering current behavior. |
| **2. Run Baseline Tests** | [e.g., "All 50 tests passing" or "Link to CI run"] | - [ ] All tests pass before any refactoring begins. |
| **3. Capture Baseline Metrics** | [e.g., "Complexity: 25, Coverage: 80%, Latency: 120ms" or "Link to report"] | - [ ] Baseline metrics captured for comparison. |
| **4. Make Smallest Refactor** | [e.g., "Extracted validate_token function (30 lines)" or "Link to commit"] | - [ ] Smallest possible refactoring change made. |
| **5. Run Tests (Iteration)** | [e.g., "All 50 tests passing after change" or "Link to CI run"] | - [ ] All tests pass after refactoring change. |
| **6. Commit Incremental Change** | [e.g., "Committed refactor step 1 of 6" or "Link to commit"] | - [ ] Incremental change committed (enables easy rollback). |
| **7. Repeat Steps 4-6** | [e.g., "Completed 6/6 refactor steps, all tests passing" or "Status: Complete"] | - [ ] All incremental refactoring steps completed with passing tests. |
| **8. Update Documentation** | [e.g., "Updated docstrings, README, inline comments" or "Link to commit"] | - [ ] All documentation updated (docstrings, README, comments, architecture docs). |
| **9. Style & Linting Check** | [e.g., "Linting passed, type checking passed" or "Link to CI run"] | - [ ] Code passes linting, type checking, and style guide validation. |
| **10. Code Review** | [e.g., "PR #790 approved by 2 reviewers" or "Status: Approved"] | - [ ] Changes reviewed for correctness and maintainability. |
| **11. Performance Validation** | [e.g., "Latency 115ms (4% improvement), no regression" or "Link to benchmark"] | - [ ] Performance validated - no regression detected. |
| **12. Deploy to Staging** | [e.g., "Deployed to staging, smoke tests passed" or "Link to deployment"] | - [ ] Refactored code validated in staging environment. |
| **13. Production Deployment** | [e.g., "Deployed to 10% canary, monitoring metrics" or "Full rollout complete"] | - [ ] Gradual production rollout with monitoring. |

#### Refactoring Implementation Notes

> Document refactoring techniques used, design patterns introduced, and complexity improvements.

**Refactoring Techniques Applied:**
* [e.g., "Extract Method: Broke 200-line function into 6 focused functions"]
* [e.g., "Replace Conditional with Polymorphism: Created AuthenticationStrategy interface"]
* [e.g., "Introduce Parameter Object: Created LoginRequest class to reduce parameter count"]

**Design Patterns Introduced:**
* [e.g., "Strategy Pattern: Pluggable authentication strategies (JWT, OAuth, SAML)"]
* [e.g., "Factory Pattern: AuthenticationStrategyFactory creates appropriate strategy"]

**Code Quality Improvements:**
* [e.g., "Cyclomatic complexity: 25 -> 8 (68% reduction)"]
* [e.g., "Function length: 200 lines -> max 50 lines per function"]
* [e.g., "Test coverage: 80% -> 95% (added 15 tests)"]
* [e.g., "Type hints: 0% -> 100% (full type coverage)"]

**Before/After Comparison:**
```python
# Before: 200-line monolithic function
def login(username, password, remember_me, two_factor_code):
    # 200 lines of mixed concerns...
    pass

# After: Refactored into focused functions
def authenticate_user(credentials: Credentials) -> User:
    """Authenticate user with provided credentials."""
    pass

def validate_two_factor(user: User, code: str) -> bool:
    """Validate two-factor authentication code."""
    pass

def create_session(user: User, remember_me: bool) -> Session:
    """Create authenticated session for user."""
    pass

def login(request: LoginRequest) -> LoginResponse:
    """Orchestrate login flow with proper separation of concerns."""
    user = authenticate_user(request.credentials)
    if request.two_factor_code:
        validate_two_factor(user, request.two_factor_code)
    session = create_session(user, request.remember_me)
    return LoginResponse(session=session)
```

---

## Refactoring Validation & Completion

| Task | Detail/Link |
| :--- | :--- |
| **Code Location** | [Path to refactored code, e.g., "src/auth/login.py (refactored), tests/auth/test_login.py (expanded)"] |
| **Test Suite** | [e.g., "50 tests (15 new), 95% coverage, all passing" or "Link to test results"] |
| **Baseline Metrics (Before)** | [e.g., "Complexity: 25, Coverage: 80%, Latency: 120ms, Function length: 200 lines"] |
| **Final Metrics (After)** | [e.g., "Complexity: 8, Coverage: 95%, Latency: 115ms, Function length: max 50 lines"] |
| **Performance Validation** | [e.g., "No regression, 4% latency improvement" or "Link to benchmark comparison"] |
| **Style & Linting** | [e.g., "All checks passed: pylint, mypy, black" or "Link to CI run"] |
| **Code Review** | [e.g., "PR #790 approved by Alice, Bob" or "Link to PR"] |
| **Documentation Updates** | [e.g., "Updated: docstrings, README, docs/auth.md" or "Links to updated docs"] |
| **Staging Validation** | [e.g., "Deployed to staging 2025-01-20, smoke tests passed" or "Link to deployment"] |
| **Production Deployment** | [e.g., "Deployed to production 2025-01-25, monitoring active" or "Link to release"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Refactoring Needed?** | [e.g., "Yes - created REFACTOR-567 for similar pattern in admin module" or "No - complete"] |
| **Design Patterns Reusable?** | [e.g., "Yes - documented Strategy pattern in team wiki for reuse" or "Link to pattern doc"] |
| **Test Suite Improvements?** | [e.g., "Yes - added 15 tests, coverage increased to 95%" or "Already comprehensive"] |
| **Documentation Complete?** | [e.g., "Yes - updated all docstrings, README, architecture docs" or "Link to docs"] |
| **Performance Impact?** | [e.g., "Positive - 4% latency improvement" or "Neutral - no measurable change"] |
| **Team Knowledge Sharing?** | [e.g., "Yes - presented refactoring patterns in team meeting 2025-01-26" or "Not needed"] |
| **Technical Debt Reduced?** | [e.g., "Yes - removed from tech debt backlog" or "Partially - created follow-up TECH-890"] |
| **Code Quality Metrics Improved?** | [e.g., "Yes - complexity 25->8, coverage 80%->95%, type hints 0%->100%"] |

### Completion Checklist

* [ ] Comprehensive tests exist before refactoring (95%+ coverage target).
* [ ] All tests pass before refactoring begins (baseline established).
* [ ] Baseline metrics captured (complexity, coverage, performance).
* [ ] Refactoring implemented incrementally (small, safe steps).
* [ ] All tests pass after each refactoring step (continuous validation).
* [ ] Documentation updated (docstrings, README, inline comments, architecture docs).
* [ ] Code passes style guide validation (linting, type checking).
* [ ] Code reviewed by at least 2 team members.
* [ ] No performance regression (ideally improvement).
* [ ] Refactored code validated in staging environment.
* [ ] Production deployment successful with monitoring.
* [ ] Code quality metrics improved (complexity, coverage, maintainability).
* [ ] Rollback plan documented and tested (if high-risk refactor).

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
