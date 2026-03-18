---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the development of API features with enforced best practices for contract design, versioning, documentation, security, and comprehensive testing.
use_case: Use this for building new API endpoints, modifying existing APIs, or adding API functionality. Ensures proper API design review, OpenAPI documentation, backward compatibility, security validation, and integration testing.
patterns_used:
  - section: "API Feature Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "API Design & Contract Review"
    pattern: "Pattern 2: Structured Review"
  - section: "API Development Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "TDD Implementation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "API Validation & Release"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# API Feature Development Template

**When to use this template:** Use this for developing new API endpoints, modifying existing API functionality, adding API resources, or implementing API features that require contract design, versioning considerations, and comprehensive testing.

**When NOT to use this template:** Do not use this for internal service-to-service communication that doesn't expose an API contract, simple bug fixes (use `bug.md`), or UI-only features (use `feature-ui.md`). This template is specifically for public or external API development.

---

## API Feature Overview

* **Feature Description:** [Brief description of the API feature, e.g., "Add user profile management endpoints", "Implement search API with pagination"]
* **API Resource/Endpoint:** [Primary endpoint(s), e.g., "GET/POST /api/v2/users/{id}/profile", "GET /api/v2/search"]
* **HTTP Methods:** [Methods to implement, e.g., "GET, POST, PUT, DELETE", "GET only (read-only)"]
* **API Version:** [Version this feature targets, e.g., "v2", "v1 (backward compatible change)"]
* **Related Work:** [Links to design docs, spike cards, ADRs, e.g., "Design spike SPIKE-456", "ADR-020 for versioning strategy"]
* **Client Impact:** [Who uses this API, e.g., "Mobile app, Web frontend", "External partners via API keys", "Internal services only"]
* **Target Release:** [Release version or date, e.g., "Q1 2025 release", "Sprint 24"]

**Required Checks:**
* [ ] **API resource/endpoint** path is clearly defined.
* [ ] **API version** is specified and versioning strategy is understood.
* [ ] **Client impact** is identified (who will consume this API).

---

## API Design & Contract Review

Before implementation, review API design standards, existing contracts, and ensure the new API follows team conventions.

* [ ] API design guidelines reviewed (REST conventions, naming, HTTP status codes).
* [ ] Existing API contracts reviewed for consistency (similar endpoints, patterns).
* [ ] OpenAPI/Swagger specification template reviewed for documentation format.
* [ ] Authentication/authorization requirements reviewed (OAuth, API keys, JWT).
* [ ] Rate limiting and quota policies reviewed for this endpoint.
* [ ] Versioning strategy reviewed (URL versioning, header versioning, deprecation policy).

Use the table below to document design decisions and requirements. Add rows as needed.

| Design Aspect | Decision / Requirement | Rationale / Notes |
| :--- | :--- | :--- |
| **Resource Naming** | [e.g., "/users/{id}/profile" (singular), "/users" (plural for collection)] | [e.g., "Follows REST convention: singular for resource, plural for collection"] |
| **HTTP Methods** | [e.g., "GET (read), POST (create), PUT (full update), PATCH (partial update)"] | [e.g., "PATCH for partial updates to avoid overwriting unspecified fields"] |
| **Request Format** | [e.g., "JSON body with Content-Type: application/json"] | [e.g., "Team standard, aligns with existing APIs"] |
| **Response Format** | [e.g., "JSON with standard envelope: {data, meta, errors}"] | [e.g., "Consistent envelope structure across all endpoints"] |
| **Status Codes** | [e.g., "200 OK, 201 Created, 400 Bad Request, 401 Unauthorized, 404 Not Found"] | [e.g., "Standard HTTP semantics, documented in API guide"] |
| **Pagination** | [e.g., "Cursor-based pagination with limit/cursor query params"] | [e.g., "Better performance for large datasets than offset/limit"] |
| **Authentication** | [e.g., "Bearer token (JWT) in Authorization header"] | [e.g., "OAuth 2.0 standard, existing auth middleware"] |
| **Authorization** | [e.g., "User can only access own profile, admins can access any"] | [e.g., "RBAC policy enforced in middleware"] |
| **Rate Limiting** | [e.g., "100 requests/minute per API key"] | [e.g., "Standard rate limit for authenticated endpoints"] |
| **Versioning** | [e.g., "URL versioning (/api/v2/), v1 endpoint deprecated in 6 months"] | [e.g., "Team standard, ADR-015 versioning strategy"] |
| **Error Format** | [e.g., "RFC 7807 Problem Details JSON"] | [e.g., "Team standard, provides machine-readable error codes"] |
| **Backward Compatibility** | [e.g., "Must not break existing v2 clients, additive changes only"] | [e.g., "v2 is stable, breaking changes require v3"] |

---

## API Development Phases

Track the major phases of API development from design through deployment. This acts as a table of contents for the work.

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **API Contract Design** | [e.g., "OpenAPI spec drafted in docs/api/openapi-v2.yaml" or "Link to PR"] | - [ ] OpenAPI/Swagger spec is complete and reviewed. |
| **Contract Review** | [e.g., "Reviewed with team in API review meeting 2025-01-15" or "Feedback collected"] | - [ ] API contract is reviewed and approved by team/stakeholders. |
| **TDD Implementation** | [e.g., "Feature branch: feature/user-profile-api" or "Link to PR #789"] | - [ ] TDD workflow followed (tests first, then implementation). |
| **Integration Tests** | [e.g., "Added 15 integration tests in tests/api/test_user_profile.py" or "Link to tests"] | - [ ] Integration tests cover happy path and error cases. |
| **Security Review** | [e.g., "Security team reviewed auth/authz logic" or "Self-review against OWASP checklist"] | - [ ] Security requirements validated (auth, input validation, rate limiting). |
| **API Documentation** | [e.g., "Generated API docs at docs.example.com/api/v2" or "README updated"] | - [ ] API documentation is complete with examples and error codes. |
| **Client SDK Updates** | [e.g., "Updated Python SDK, created FRONTEND-567 for JS SDK" or "N/A - no SDK"] | - [ ] Client SDKs updated [if applicable] or follow-up cards created. |
| **Deployment** | [e.g., "Deployed to staging 2025-01-20, production 2025-01-25" or "Link to release"] | - [ ] API is deployed and verified in production. |

---

## TDD Implementation Workflow

Follow test-driven development to ensure API correctness, contract adherence, and proper error handling.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Contract Tests** | [e.g., "Wrote tests for OpenAPI spec validation, request/response schemas" or "Link to commit"] | - [ ] Contract tests validate API adheres to OpenAPI spec. |
| **2. Write Failing Integration Tests** | [e.g., "Wrote tests for GET/POST/PUT/DELETE endpoints, all failing" or "Link to commit"] | - [ ] Integration tests written covering all endpoints and methods. |
| **3. Implement API Endpoints** | [e.g., "Implemented handlers in src/api/v2/users.py" or "PR #789 in review"] | - [ ] API endpoints implemented, returning correct status codes. |
| **4. Run Passing Tests** | [e.g., "All 15 integration tests passing" or "Link to CI run"] | - [ ] All integration tests pass, API behavior verified. |
| **5. Add Error Handling Tests** | [e.g., "Added tests for 400, 401, 404, 500 error cases" or "Link to commit"] | - [ ] Error handling tests written and passing. |
| **6. Security Tests** | [e.g., "Added tests for unauthorized access, invalid tokens, SQL injection" or "Link to commit"] | - [ ] Security tests validate auth, input sanitization, rate limiting. |
| **7. Performance Tests** | [e.g., "Load tested 1000 req/s, latency <100ms at p95" or "Benchmark results"] | - [ ] Performance validated against requirements [if applicable]. |
| **8. Regression Suite** | [e.g., "Full API test suite passed (200 tests)" or "Link to CI run"] | - [ ] Full regression suite passed, no existing APIs broken. |

#### API Implementation Notes

> Document key implementation decisions, middleware used, database queries, caching strategies.

**Middleware Stack:**
```python
# Example: Express.js middleware stack
app.use('/api/v2/users', [
    authMiddleware,      // JWT validation
    rateLimitMiddleware, // 100 req/min
    validationMiddleware // Request schema validation
])
```

**Database Queries:**
* [e.g., "GET /users/{id}/profile: Single SELECT with JOIN on profiles table"]
* [e.g., "POST /users/{id}/profile: INSERT with transaction, rollback on error"]

**Caching Strategy:**
* [e.g., "GET requests cached in Redis for 5 minutes, invalidated on PUT/DELETE"]

---

## API Validation & Release

| Task | Detail/Link |
| :--- | :--- |
| **OpenAPI Spec Location** | [Path to spec, e.g., "docs/api/openapi-v2.yaml"] |
| **API Documentation URL** | [e.g., "https://docs.example.com/api/v2/users" or "Link to generated docs"] |
| **Integration Test Coverage** | [Count and location, e.g., "15 tests in tests/api/test_user_profile.py, 100% endpoint coverage"] |
| **Security Validation** | [Checklist or review, e.g., "OWASP checklist complete, SQL injection tests pass"] |
| **Performance Metrics** | [If tested, e.g., "p50: 45ms, p95: 95ms, p99: 150ms at 500 req/s"] |
| **Client Communication** | [How clients were notified, e.g., "Posted to API changelog, emailed partners"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **API Changelog Updated?** | [e.g., "Yes - added v2.3.0 entry with new endpoints" or "Link to changelog"] |
| **Client SDK Updates?** | [e.g., "Python SDK updated in PR #890, JS SDK pending (FRONTEND-567)" or "N/A"] |
| **Deprecation Notices?** | [e.g., "Yes - v1 endpoint deprecated, sunset date 2025-07-01" or "No deprecations"] |
| **Monitoring/Alerts?** | [e.g., "Added Datadog metrics for endpoint latency, error rate alerts" or "Link to dashboard"] |
| **Rate Limit Tuning?** | [e.g., "100 req/min sufficient, no changes needed" or "Increased to 200 req/min after launch"] |
| **API Versioning Review?** | [e.g., "No breaking changes needed" or "Created ADR-025 for v3 planning"] |
| **Documentation Feedback?** | [e.g., "3 users requested more examples - created DOC-678" or "No feedback yet"] |

### Completion Checklist

* [ ] OpenAPI/Swagger specification is complete and merged.
* [ ] API contract is reviewed and approved by team/stakeholders.
* [ ] TDD workflow followed: tests written first, then implementation.
* [ ] All integration tests pass (happy path + error cases).
* [ ] Security requirements validated (authentication, authorization, input validation, rate limiting).
* [ ] API documentation is complete with request/response examples and error codes.
* [ ] Performance validated against requirements [if applicable].
* [ ] Client SDKs updated or follow-up cards created.
* [ ] API changelog updated with new endpoints and changes.
* [ ] Monitoring and alerts configured for the new API.
* [ ] API is deployed to production and verified working.
* [ ] Client communication sent (email, Slack, API portal announcement).

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
