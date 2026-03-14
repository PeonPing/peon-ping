---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the systematic investigation and resolution of complex, multi-variable bugs that require rigorous hypothesis testing, isolation, and process adherence to prevent circular troubleshooting.
use_case: Use this for escalated bugs where initial fixes have failed, symptoms are unclear, multiple systems are involved, or the team is going in circles. This enforces a disciplined playbook approach rather than ad-hoc troubleshooting.
patterns_used:
  - section: "Incident Overview & Classification"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Knowledge Base Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Hypothesis Testing Log"
    pattern: "Pattern 3: Iterative Log"
  - section: "Diagnostic Implementation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Isolation & Logging Strategy"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Root Cause Analysis & Validation"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Bug Escalation: Systematic Troubleshooting Template

**When to use this template:** Use this when a bug investigation has stalled, the team is going in circles, symptoms are inconsistent or unclear, multiple failed fix attempts have occurred, or the issue spans multiple systems/components. This template enforces a disciplined, hypothesis-driven approach with rigorous isolation and logging.

**When NOT to use this template:** Do not use this for straightforward bugs with clear reproduction steps and obvious fixes. Use the standard `bug.md` template for those cases. This template is specifically for complex, escalated situations requiring systematic process adherence.

---

## Incident Overview & Classification

* **Original Bug Ticket:** [Link to original bug report, e.g., BUG-1234]
* **Escalation Date:** [Date escalated to systematic troubleshooting, e.g., 2025-01-15]
* **Affected Systems/Components:** [List all systems involved, e.g., "API Gateway, Auth Service, User DB"]
* **Severity & Impact:** [e.g., "P0 - Production outage affecting 30% of users" or "P1 - Intermittent failures in checkout flow"]
* **Previous Fix Attempts:** [Summary of what has already been tried, e.g., "Restarted services (failed), increased timeouts (no effect), rolled back last 2 deployments (issue persists)"]
* **Circular Pattern Detected:** [Describe the circular troubleshooting pattern, e.g., "Team keeps suspecting database connection pool exhaustion, applies temporary fix, issue returns within hours"]

**Required Checks:**
* [ ] **Original Bug Ticket** link is included above.
* [ ] **All affected systems/components** are identified and listed.
* [ ] **Previous fix attempts** are documented to avoid repetition.
* [ ] **Circular troubleshooting pattern** (if any) is explicitly stated.

---

## Knowledge Base Review

First, confirm that all relevant documentation, runbooks, and historical context have been reviewed before beginning systematic testing.

* [ ] `Runbooks/Playbooks` for affected systems reviewed.
* [ ] `Architecture diagrams` and system dependencies documented.
* [ ] `Previous incident reports` or postmortems for similar issues reviewed.
* [ ] `Monitoring dashboards` and alerts reviewed for patterns.
* [ ] `Logs` from affected timeframes collected and preserved.

Use the table below to log findings from documentation review. Add rows as needed.

| Document Type | Link / Location | Key Findings / Action Required |
| :--- | :--- | :--- |
| **Runbook** | [Link or path] | [e.g., "Runbook last updated 6 months ago, may be outdated"] |
| **Architecture Diagram** | [Link or path] | [e.g., "Diagram shows 3 dependency chains - need to test each"] |
| **Previous Postmortem** | [Link or path] | [e.g., "Similar issue in Q3 2024 resolved by adding circuit breaker - verify implementation"] |
| **Monitoring Dashboard** | [Link] | [e.g., "CPU spikes correlate with error rate - hypothesis: resource contention"] |
| **Log Analysis** | [Path to logs] | [e.g., "Found 500 error pattern every 15 minutes - periodic job suspected"] |
| **New Artifact Required** | **N/A** (Action Item) | [e.g., "**Finding:** No load testing data exists. **Action:** Must create baseline load test."] |

---

## Isolation & Logging Strategy

Before beginning hypothesis testing, define the isolation strategy and enhanced logging that will be implemented to systematically narrow down the issue.

> Use this space to document the isolation approach and what enhanced logging/instrumentation will be added.

**Isolation Strategy:**
* [e.g., "Isolate API Gateway from downstream services using synthetic responses"]
* [e.g., "Test each microservice independently with mock data"]
* [e.g., "Create minimal reproduction environment with only essential components"]
* [e.g., "Use feature flags to disable suspected code paths"]

**Enhanced Logging/Instrumentation:**
* [e.g., "Add distributed tracing IDs across all service calls"]
* [e.g., "Increase log verbosity for auth service to DEBUG level"]
* [e.g., "Add custom metrics for connection pool utilization"]
* [e.g., "Enable query-level logging on database for slow query detection"]
* [e.g., "Deploy APM agent to capture method-level performance data"]

**Data Collection Requirements:**
* [e.g., "Capture full request/response headers for 100 sample failures"]
* [e.g., "Record thread dumps every 5 seconds during incident window"]
* [e.g., "Export metrics with 1-second granularity instead of 1-minute"]

---

## Hypothesis Testing Log

This section enforces the scientific method: form hypothesis, design test, execute, record outcome, refine hypothesis. Each iteration must be completed before moving to the next.

| Iteration # | Hypothesis | Test/Action Taken | Outcome / Findings |
| :---: | :--- | :--- | :--- |
| **1** | [e.g., "Database connection pool is exhausted during peak load"] | [e.g., "Monitor pool metrics during load test, increase pool size by 50%"] | [e.g., "REJECTED: Pool utilization remained at 40%, issue still occurred"] |
| **2** | [e.g., "Periodic batch job causes resource contention"] | [e.g., "Disable batch job for 24 hours, monitor error rate"] | [e.g., "CONFIRMED: Error rate dropped to zero when job disabled"] |
| **3** | [Hypothesis...] | [Test/Action...] | [Outcome...] |

---

#### Iteration 1: [Hypothesis Summary]

**Hypothesis:** [State the specific hypothesis being tested, e.g., "The database connection pool is being exhausted during peak load, causing timeout errors in the API layer."]

**Rationale:** [Why this hypothesis was formed, e.g., "Error logs show 'connection timeout' messages, and previous incidents involved connection pool issues."]

**Test Design:**
* [Describe the specific test that will validate or reject this hypothesis]
* [e.g., "Deploy enhanced monitoring to capture real-time connection pool metrics"]
* [e.g., "Run controlled load test with 2x normal traffic while monitoring pool utilization"]
* [e.g., "Temporarily increase pool size from 50 to 75 connections as a test"]

**Isolation Applied:**
* [What was isolated to ensure test validity, e.g., "Disabled non-critical background jobs to eliminate noise"]
* [e.g., "Tested against staging environment with production-equivalent load"]

**Data Collected:**
* [List specific data points captured, e.g., "Connection pool utilization: 35-42% throughout test"]
* [e.g., "Error rate: 15% during test (unchanged from baseline)"]
* [e.g., "Database query latency: 50ms avg (normal)"]

**Outcome:** [CONFIRMED / REJECTED / INCONCLUSIVE]

**Conclusion:** [e.g., "REJECTED: Connection pool utilization remained well below capacity during the entire test. Errors continued even with increased pool size. This is NOT the root cause."]

**Next Hypothesis:** [What hypothesis will be tested next based on these findings, e.g., "Theory 2: Periodic batch job causes CPU contention"]

---

#### Iteration 2: [Hypothesis Summary]

**Hypothesis:** [State the specific hypothesis being tested]

**Rationale:** [Why this hypothesis was formed based on previous iteration]

**Test Design:**
* [Describe the specific test]
* [...]

**Isolation Applied:**
* [What was isolated]
* [...]

**Data Collected:**
* [List specific data points]
* [...]

**Outcome:** [CONFIRMED / REJECTED / INCONCLUSIVE]

**Conclusion:** [Detailed conclusion]

**Next Hypothesis:** [What's next]

---

#### Iteration 3: [Hypothesis Summary]

[Continue pattern for each iteration - copy and paste this block as many times as needed]

---

## Diagnostic Implementation Workflow

This section tracks the implementation of diagnostic changes, enhanced monitoring, and eventual fix. Each step must be completed in order.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Deploy Enhanced Logging** | [e.g., "Deployed to staging 2025-01-15, production 2025-01-16" or "PR #456 - awaiting approval"] | - [ ] Enhanced logging is deployed and verified working. |
| **2. Establish Baseline Metrics** | [e.g., "Captured 24-hour baseline 2025-01-16 to 2025-01-17" or "Link to dashboard"] | - [ ] Baseline metrics are captured and documented. |
| **3. Execute Controlled Tests** | [e.g., "Load test completed 2025-01-18, data in Iteration 1 log" or "Status: In Progress"] | - [ ] All hypothesis tests are executed and logged. |
| **4. Implement Root Cause Fix** | [e.g., "Rescheduled batch job to off-peak hours, deployed 2025-01-19" or "PR #789"] | - [ ] Root cause fix is implemented and deployed. |
| **5. Validate Fix in Production** | [e.g., "Monitored for 72 hours post-fix, zero errors observed" or "Link to validation report"] | - [ ] Fix is validated in production with monitoring data. |
| **6. Rollback Plan Verified** | [e.g., "Rollback tested in staging, documented in runbook" or "Link to rollback procedure"] | - [ ] Rollback plan is tested and documented. |

#### Diagnostic Code & Configuration

> Paste any diagnostic code, configuration changes, or scripts used for enhanced logging and testing here.

```python
# Example: Enhanced logging decorator
@log_performance_metrics
def critical_function():
    # Function implementation
    pass
```

```yaml
# Example: Enhanced monitoring configuration
monitoring:
  log_level: DEBUG
  trace_enabled: true
  sample_rate: 1.0  # 100% sampling during investigation
```

---

## Root Cause Analysis & Validation

| Task | Detail/Link |
| :--- | :--- |
| **Root Cause Statement** | [One-sentence statement of the confirmed root cause, e.g., "Periodic batch job running at 3:15 AM caused CPU saturation, leading to request timeouts across all API endpoints."] |
| **Confirming Evidence** | [Link to data/logs that definitively prove root cause, e.g., "Iteration 2 test results, CPU metrics dashboard"] |
| **Fix Implementation** | [Link to PR/change, e.g., "PR #789 - Rescheduled batch job to 2 AM off-peak window with CPU throttling"] |
| **Validation Period** | [How long fix was monitored, e.g., "72 hours post-deployment, 2025-01-19 to 2025-01-22"] |
| **Validation Data** | [Link to metrics showing fix effectiveness, e.g., "Error rate dashboard - zero errors observed"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Postmortem Required?** | [Yes/No - if Yes, link to postmortem card] |
| **Monitoring Gaps Identified?** | [e.g., "Yes - need to add CPU saturation alerts for batch job processes, created INFRA-456"] |
| **Runbook Updates** | [e.g., "Updated runbook with new diagnostic procedure, link to runbook"] |
| **Architecture Changes Needed?** | [e.g., "Yes - need to implement resource isolation for batch jobs, created ARCH-789"] |
| **Technical Debt Created** | [e.g., "Enhanced logging adds 5% overhead, need to optimize, created TECH-321"] |
| **Similar Systems at Risk?** | [e.g., "Yes - report generation service has same pattern, created BUG-654 for audit"] |

### Completion Checklist

* [ ] Root cause is definitively identified with confirming evidence.
* [ ] Fix is implemented and deployed to production.
* [ ] Fix is validated with at least 72 hours of production monitoring data.
* [ ] All enhanced logging and diagnostics are either removed or optimized for long-term use.
* [ ] Rollback plan is tested and documented.
* [ ] Runbooks/playbooks are updated with lessons learned.
* [ ] Monitoring gaps are addressed or follow-up tickets created.
* [ ] Postmortem is completed (if P0/P1 incident).
* [ ] Original bug ticket is updated with root cause and closed.
* [ ] Follow-up tickets for related risks or tech debt are created.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
