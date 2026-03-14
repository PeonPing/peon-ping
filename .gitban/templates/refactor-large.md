---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for planning and executing large-scale refactoring projects using enterprise patterns like Strangler Fig, with emphasis on sprint planning, incremental delivery, TDD, comprehensive documentation, and risk mitigation to ensure safe transformation of major systems.
use_case: Use this for major refactoring projects that span multiple sprints including architecture migrations, legacy system modernization, monolith decomposition, or large-scale technical debt initiatives. Enforces sprint-based planning, Strangler Fig pattern, parallel run validation, and comprehensive safety measures.
patterns_used:
  - section: "Large Refactoring Project Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Pre-Refactoring Assessment"
    pattern: "Pattern 2: Structured Review"
  - section: "Refactoring Strategy & Architecture"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Sprint Planning & Work Breakdown"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Strangler Fig Implementation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Project Validation & Closeout"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Large-Scale Refactoring Project Template

**When to use this template:** Use this for major refactoring projects spanning multiple sprints including architecture migrations, legacy system modernization, monolith-to-microservices decomposition, or large-scale technical debt initiatives. Enforces sprint-based planning, Strangler Fig pattern, incremental delivery, and comprehensive safety measures.

**When NOT to use this template:** Do not use this for small refactorings that fit in a single sprint (use `refactor-refactor.md`), new feature development (use `feature.md`), or exploratory work (use `spike.md`). This template is specifically for large, multi-sprint refactoring projects requiring careful orchestration.

---

## Large Refactoring Project Overview

* **Project Name:** [Descriptive name, e.g., "Monolith to Microservices Migration", "Legacy Payment System Modernization", "Database Layer Refactoring"]
* **System/Component:** [What's being refactored, e.g., "User authentication system", "Order processing pipeline", "Database access layer"]
* **Current State:** [Brief description, e.g., "Monolithic Rails app (50k LOC)", "Legacy Java 8 payment processor", "Direct SQL queries scattered across 200 files"]
* **Target State:** [Desired end state, e.g., "Microservices architecture (5 services)", "Modern Spring Boot with event sourcing", "Repository pattern with ORM"]
* **Motivation:** [Why this must happen, e.g., "Cannot scale beyond 1000 users/day", "PCI compliance requires modernization", "Tech debt blocking all feature work"]
* **Business Impact:** [Stakes, e.g., "Enables 10x growth", "Required for enterprise deals", "Reduces developer onboarding from 3 months to 2 weeks"]
* **Project Duration:** [Estimate, e.g., "6 sprints (12 weeks)", "Q1-Q2 2025 (6 months)", "3 phases over 4 months"]
* **Team Size:** [Resources, e.g., "2 senior engineers full-time", "1 architect + 3 engineers", "Full team (6 engineers) dedicated"]
* **Budget/Cost:** [If applicable, e.g., "3000 engineering hours", "$150k external consulting", "No additional budget - existing team"]

**Required Checks:**
* [ ] **Business justification** is clear and compelling (not just "tech wants to").
* [ ] **Project duration** is realistic with buffer for unknowns (not overly optimistic).
* [ ] **Team commitment** is secured and protected from competing priorities.

---

## Pre-Refactoring Assessment

Before planning sprints, conduct comprehensive assessment of current system, dependencies, risks, and constraints.

* [ ] Current architecture documented (diagrams, component relationships, data flows).
* [ ] Test coverage assessed (integration tests, unit tests, E2E tests).
* [ ] Dependencies mapped (internal modules, external services, database schemas).
* [ ] Performance baselines captured (latency, throughput, error rates).
* [ ] Deployment pipeline assessed (CI/CD capabilities, rollback procedures).
* [ ] Team expertise assessed (skills gaps, training needs, external help required).
* [ ] Stakeholder alignment confirmed (product, executive, customer success bought in).
* [ ] Similar refactoring projects reviewed (learn from past successes/failures).

Use the table below to document assessment findings. Add rows as needed.

| Assessment Area | Current State / Findings | Risk / Constraint |
| :--- | :--- | :--- |
| **Architecture** | [e.g., "Monolithic app, 50k LOC, 200 models, 15 controllers"] | [e.g., "High coupling - changes ripple across codebase"] |
| **Test Coverage** | [e.g., "45% unit test coverage, 10 E2E tests, no integration tests"] | [e.g., "Insufficient safety net - must add tests before refactoring"] |
| **Dependencies** | [e.g., "30 internal modules, 5 external APIs, shared PostgreSQL DB"] | [e.g., "Shared DB is bottleneck - must decompose carefully"] |
| **Performance Baseline** | [e.g., "p95 latency: 2s, throughput: 100 req/s, error rate: 2%"] | [e.g., "Cannot degrade performance - customers will churn"] |
| **CI/CD Pipeline** | [e.g., "GitHub Actions, 15min build, manual staging deploy, blue-green prod"] | [e.g., "Manual staging deploy slows validation - needs automation"] |
| **Team Skills** | [e.g., "Strong Rails, weak microservices patterns, no K8s experience"] | [e.g., "Need K8s training and architecture mentorship"] |
| **Stakeholder Buy-in** | [e.g., "Product wants features, not refactoring - limited patience"] | [e.g., "Must show incremental value - no 'big bang' allowed"] |
| **Historical Context** | [e.g., "2022 attempt failed after 3 months - team gave up mid-project"] | [e.g., "Previous attempt too ambitious - must be incremental this time"] |

---

## Refactoring Strategy & Architecture

> Use this space for refactoring approach, architecture decisions, and detailed strategy including Strangler Fig pattern application.

**Refactoring Pattern Choice: Strangler Fig**

The Strangler Fig pattern gradually replaces the old system by growing new functionality around it:
1. Create new system alongside old system (parallel implementation)
2. Route subset of traffic to new system (gradual migration)
3. Validate new system works correctly (parallel run, shadowing)
4. Increase traffic to new system incrementally (0% -> 10% -> 50% -> 100%)
5. Decommission old system once fully replaced (sunset)

**Why Strangler Fig for This Project:**
* [e.g., "Allows incremental delivery - can show value every sprint"]
* [e.g., "Reduces risk - old system remains fallback if issues arise"]
* [e.g., "Enables parallel run validation - prove new system before committing"]
* [e.g., "Supports gradual rollout - catch issues with 10% traffic before full migration"]

**Alternative Patterns Considered:**
* [e.g., "Big Bang Rewrite: Rejected - too risky, no incremental value, team lost patience historically"]
* [e.g., "Branch by Abstraction: Rejected - doesn't work for our architecture (monolith to services)"]
* [e.g., "Feature Toggles Only: Rejected - insufficient isolation for this scale of change"]

**Architecture Evolution Plan:**

**Phase 1: Foundation (Sprints 1-2)**
* [e.g., "Extract domain models to shared library (enables code reuse)"]
* [e.g., "Implement API gateway (routing layer for Strangler Fig)"]
* [e.g., "Setup new service infrastructure (K8s, monitoring, CI/CD)"]

**Phase 2: First Service Extraction (Sprints 3-4)**
* [e.g., "Extract User Service: authentication, profile management"]
* [e.g., "Implement parallel run: new service shadows old code (validation)"]
* [e.g., "Gradual rollout: 0% -> 10% -> 50% -> 100% over 2 sprints"]

**Phase 3: Remaining Services (Sprints 5-6)**
* [e.g., "Extract Order Service, Payment Service, Notification Service"]
* [e.g., "Repeat parallel run + gradual rollout for each service"]

**Phase 4: Decommissioning (Sprint 7)**
* [e.g., "Remove old monolith code (sunset)"]
* [e.g., "Archive legacy documentation"]
* [e.g., "Celebrate victory"]

**Risk Mitigation Strategies:**

**Technical Risks:**
* [e.g., "Risk: Data consistency across services. Mitigation: Use event sourcing + saga pattern for distributed transactions"]
* [e.g., "Risk: Performance regression. Mitigation: Benchmark every sprint, p95 latency cannot exceed 2.2s (10% buffer)"]
* [e.g., "Risk: New system has bugs. Mitigation: Parallel run for 2 weeks, shadow traffic before routing real users"]

**Organizational Risks:**
* [e.g., "Risk: Stakeholders lose patience. Mitigation: Show working feature every sprint (not just infrastructure)"]
* [e.g., "Risk: Team burnout. Mitigation: Sustainable pace, no overtime, celebrate small wins"]
* [e.g., "Risk: Scope creep. Mitigation: Strict 'refactor only' rule - no new features during project"]

**Rollback Strategy:**
* [e.g., "Every sprint: Feature flag allows instant revert to old system (traffic routing)"]
* [e.g., "Database: Dual-write to old and new schema during transition (enables rollback)"]
* [e.g., "Deployment: Blue-green deployments with automated rollback on error spike (>5%)"]

**Success Metrics:**
* [e.g., "Performance: p95 latency ≤ 2.2s (10% buffer from 2s baseline)"]
* [e.g., "Reliability: Error rate ≤ 2% (maintain baseline)"]
* [e.g., "Quality: Test coverage ≥ 80% (improve from 45%)"]
* [e.g., "Velocity: Feature delivery speed 2x after project (measure story points per sprint)"]

---

## Sprint Planning & Work Breakdown

Break the large refactoring project into sprint-sized work packages. Each sprint must deliver working, validated functionality.

| Sprint # | Sprint Goal | Deliverables / Cards | Universal Check |
| :---: | :--- | :--- | :---: |
| **Sprint 1** | [e.g., "Foundation: API Gateway + Infrastructure"] | [e.g., "Card REFACTOR-001: API Gateway, Card REFACTOR-002: K8s Setup, Card REFACTOR-003: Monitoring"] | - [ ] Sprint delivers working, deployable infrastructure. |
| **Sprint 2** | [e.g., "Foundation: Shared Libraries + Test Suite"] | [e.g., "Card REFACTOR-004: Domain Models Library, Card REFACTOR-005: Integration Test Framework"] | - [ ] Sprint establishes test safety net (80% coverage target). |
| **Sprint 3** | [e.g., "User Service: Extract + Parallel Run"] | [e.g., "Card REFACTOR-006: User Service Implementation, Card REFACTOR-007: Parallel Run Setup"] | - [ ] User service runs in parallel with old code (shadowing). |
| **Sprint 4** | [e.g., "User Service: Gradual Rollout + Validation"] | [e.g., "Card REFACTOR-008: 10% Rollout, Card REFACTOR-009: 50% Rollout, Card REFACTOR-010: 100% Rollout"] | - [ ] User service handles 100% production traffic successfully. |
| **Sprint 5** | [e.g., "Order Service: Extract + Parallel Run"] | [e.g., "Card REFACTOR-011: Order Service, Card REFACTOR-012: Parallel Run"] | - [ ] Order service runs in parallel, validation passing. |
| **Sprint 6** | [e.g., "Payment/Notification Services: Extract + Rollout"] | [e.g., "Card REFACTOR-013: Payment Service, Card REFACTOR-014: Notification Service, Card REFACTOR-015: Rollout"] | - [ ] All services migrated, 100% traffic on new system. |
| **Sprint 7** | [e.g., "Decommission: Remove Old Code + Documentation"] | [e.g., "Card REFACTOR-016: Remove Monolith Code, Card REFACTOR-017: Archive Docs, Card REFACTOR-018: Retro"] | - [ ] Old system fully decommissioned, project complete. |

### Sprint-Level Constraints

**Every Sprint Must:**
* [ ] Deliver working functionality (not just setup or planning)
* [ ] Pass full regression test suite (no breaking changes)
* [ ] Be demonstrable to stakeholders (show progress)
* [ ] Maintain performance baseline (no degradation)
* [ ] Update documentation (architecture diagrams, runbooks)

**No Sprint Should:**
* [ ] Last longer than 2 weeks (keep feedback loops tight)
* [ ] Deliver "almost done" work (every sprint = production-ready)
* [ ] Introduce new features (refactor only - no scope creep)
* [ ] Skip testing or validation (TDD is mandatory)

---

## Strangler Fig Implementation Workflow

Follow this workflow for each service extraction. Repeat for every component being refactored.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Comprehensive Tests** | [e.g., "Added 50 integration tests for user auth flow" or "Link to PR"] | - [ ] Existing behavior fully tested (80%+ coverage). |
| **2. Establish Performance Baseline** | [e.g., "Baseline: p95 2s, throughput 100 req/s, error rate 2%" or "Link to benchmark"] | - [ ] Performance baseline captured for comparison. |
| **3. Implement New Service** | [e.g., "Created UserService in Go, matches old Rails behavior" or "Link to PR"] | - [ ] New service implemented with identical behavior. |
| **4. Setup API Gateway Routing** | [e.g., "API Gateway routes /auth/* to old or new based on feature flag" or "Link to config"] | - [ ] Routing layer enables gradual traffic shift. |
| **5. Deploy New Service (0% Traffic)** | [e.g., "UserService deployed to prod, receiving 0% traffic" or "Link to deployment"] | - [ ] New service deployed but not yet serving production traffic. |
| **6. Enable Parallel Run (Shadowing)** | [e.g., "Enabled shadowing: new service processes requests, results discarded" or "Link to logs"] | - [ ] New service processes production traffic in shadow mode. |
| **7. Validate Parallel Run** | [e.g., "Validated: 99.8% result match between old and new for 100k requests" or "Link to report"] | - [ ] New service produces identical results to old system. |
| **8. Gradual Rollout: 10%** | [e.g., "Routed 10% traffic to new service, monitoring for 48h" or "Link to dashboard"] | - [ ] 10% traffic validated successfully (no error spike). |
| **9. Gradual Rollout: 50%** | [e.g., "Routed 50% traffic to new service, monitoring for 48h" or "Link to dashboard"] | - [ ] 50% traffic validated successfully (no error spike). |
| **10. Gradual Rollout: 100%** | [e.g., "Routed 100% traffic to new service, old code inactive" or "Link to dashboard"] | - [ ] 100% traffic successfully migrated to new service. |
| **11. Monitor for 1 Week** | [e.g., "Monitored for 7 days: error rate 1.8% (improved), latency 1.9s (improved)" or "Report"] | - [ ] New service proven stable over 1 week monitoring period. |
| **12. Remove Old Code** | [e.g., "Deleted old Rails auth code, removed feature flag" or "Link to PR"] | - [ ] Old implementation removed, migration complete. |

#### Strangler Fig Best Practices

**Parallel Run / Shadowing:**
* Run new system alongside old system for validation period (recommended: 1-2 weeks)
* Compare results: log mismatches for investigation
* Shadow mode = new system processes requests but results are discarded (no impact to users)
* Goal: 99%+ result match between old and new (some variation acceptable for timestamps, IDs)

**Gradual Rollout Strategy:**
* Start conservative: 1% -> 5% -> 10% (catch issues early)
* Accelerate if stable: 10% -> 25% -> 50% -> 100%
* Monitor for 24-48h at each stage (longer for critical systems)
* Rollback immediately on error rate spike (>10% increase)

**Feature Flag Architecture:**
```python
# Example: API Gateway routing logic
def route_auth_request(request):
    user_id = request.user_id
    rollout_percentage = get_rollout_percentage("user_service")

    if should_use_new_service(user_id, rollout_percentage):
        return new_user_service.handle(request)
    else:
        return old_monolith.handle(request)
```

---

## Project Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Sprint Retrospective Summary** | [Link to retro notes for all sprints, e.g., "docs/retros/refactor-project-retros.md"] |
| **Final Architecture** | [Link to updated architecture diagrams, e.g., "docs/architecture/microservices-architecture.md"] |
| **Performance Comparison** | [Before/after metrics, e.g., "Baseline: 2s/100req/s/2%, Final: 1.9s/120req/s/1.8%"] |
| **Test Coverage** | [Coverage improvement, e.g., "Before: 45%, After: 85% (40 percentage point improvement)"] |
| **Documentation** | [Links to all updated docs: runbooks, API specs, architecture, troubleshooting] |
| **Team Knowledge Transfer** | [e.g., "Conducted 3 training sessions, published 5 tech talks" or "Links to recordings"] |
| **Old System Decommissioned** | [Confirmation, e.g., "Monolith code removed in PR #999, deployed 2025-06-01"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Project Success Metrics?** | [e.g., "Success: p95 latency improved 5%, error rate reduced 10%, test coverage +40%"] |
| **Velocity Improvement?** | [e.g., "Feature velocity increased 2x (measured: 8 points/sprint -> 16 points/sprint)"] |
| **Team Morale?** | [e.g., "High - team feels accomplished, celebrating success, recruiting easier"] |
| **Stakeholder Satisfaction?** | [e.g., "High - product team appreciates faster feature delivery, exec team pleased with stability"] |
| **Technical Debt Remaining?** | [e.g., "Low - addressed 80% of known tech debt, remaining items documented in backlog"] |
| **Similar Projects Planned?** | [e.g., "Yes - created REFACTOR-567 for reporting system using same Strangler Fig approach"] |
| **Process Improvements?** | [e.g., "Document Strangler Fig playbook for future projects, add to team wiki"] |
| **Celebration?** | [e.g., "Team offsite planned for 2025-06-15 to celebrate project success"] |

### Completion Checklist

* [ ] All planned sprints completed with deliverables met.
* [ ] 100% of production traffic migrated to new system.
* [ ] Old system code completely removed (decommissioned).
* [ ] Performance targets achieved (no regression, ideally improvement).
* [ ] Test coverage targets achieved (80%+ coverage).
* [ ] Full regression test suite passing.
* [ ] Architecture documentation updated and published.
* [ ] Runbooks and troubleshooting guides updated.
* [ ] Team knowledge transfer completed (training, tech talks).
* [ ] Stakeholder sign-off received (product, exec, customers).
* [ ] Retrospectives completed for all sprints.
* [ ] Lessons learned documented for future large refactoring projects.
* [ ] Celebration event held to recognize team achievement.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
