---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for planning and executing performance optimization work with proper benchmarking, profiling, and validation to ensure improvements don't introduce regressions or break functionality.
use_case: Use this for performance optimization tasks including latency reduction, throughput improvement, memory optimization, or resource usage reduction. Enforces baseline measurement, profiling, iterative optimization, and regression testing to ensure safe performance improvements.
patterns_used:
  - section: "Performance Optimization Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Baseline & Context Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Initial Performance Assessment"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Performance Optimization Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Optimization Iterations"
    pattern: "Pattern 3: Iterative Log"
  - section: "Optimization Implementation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Performance Validation & Release"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Performance Optimization Template

**When to use this template:** Use this for systematic performance optimization work including latency reduction, throughput improvement, memory optimization, CPU usage reduction, or database query optimization. Ensures proper baseline measurement, profiling, safe implementation, and validation without breaking functionality.

**When NOT to use this template:** Do not use this for performance bugs causing immediate production issues (use `bug-production.md`), exploratory performance research (use `spike.md`), or adding performance monitoring instrumentation (use `chore.md`). This template is specifically for planned optimization work with clear performance targets.

---

## Performance Optimization Overview

* **Performance Issue:** [Brief description, e.g., "API endpoint /users has 2s p95 latency", "Dashboard loads 8MB of images", "Memory usage grows unbounded"]
* **Affected Component/Service:** [What needs optimization, e.g., "User service API", "Frontend dashboard", "Background job processor"]
* **Current Performance Baseline:** [Measurable current state, e.g., "p50: 500ms, p95: 2s, p99: 5s", "8MB initial load", "Memory grows 100MB/hour"]
* **Performance Target:** [Clear goal, e.g., "p95 < 500ms", "Initial load < 2MB", "Stable memory usage < 1GB"]
* **Business Impact:** [Why this matters, e.g., "User complaints about slowness", "Mobile users dropping off", "OOM kills every 12 hours"]
* **Environment:** [Where issue occurs, e.g., "Production (1000 req/s load)", "Mobile devices (4G connection)", "Background workers (10 concurrent jobs)"]
* **Related Work:** [Links, e.g., "Performance spike SPIKE-456", "Related optimization PERF-123", "Monitoring dashboard"]
* **Success Criteria:** [How to measure success, e.g., "p95 latency reduced by 75%", "Initial load reduced by 60%", "No memory growth over 24h"]

**Required Checks:**
* [ ] **Current performance baseline** is measured and documented.
* [ ] **Performance target** is specific, measurable, and realistic.
* [ ] **Success criteria** are defined before starting optimization work.

---

## Baseline & Context Review

Before optimization, review existing documentation, metrics, profiling data, and similar past work to understand the system.

* [ ] Architecture documentation reviewed for affected components.
* [ ] Performance monitoring dashboards reviewed (Datadog, New Relic, Grafana, etc.).
* [ ] Existing profiling data reviewed (if available - APM traces, flame graphs, memory profiles).
* [ ] Previous performance optimization tickets reviewed for similar work.
* [ ] Production traffic patterns reviewed (load, spike patterns, geographic distribution).
* [ ] SLA/SLO requirements reviewed to understand acceptable performance bounds.

Use the table below to document findings from baseline review. Add rows as needed.

| Review Source | Link / Location | Key Findings / Context |
| :--- | :--- | :--- |
| **Monitoring Dashboard** | [e.g., "Datadog: service-performance"] | [e.g., "p95 latency is 2s, increased 50% in past month"] |
| **APM Traces** | [e.g., "New Relic trace examples"] | [e.g., "Database queries account for 80% of request time"] |
| **Architecture Docs** | [e.g., "docs/architecture/user-service.md"] | [e.g., "Service uses N+1 query pattern for user profiles"] |
| **Previous Work** | [e.g., "PERF-123 - similar optimization in 2024"] | [e.g., "Similar issue fixed with caching - same pattern applicable here"] |
| **Load Patterns** | [e.g., "Analytics report Q4 2024"] | [e.g., "Peak load 1000 req/s during business hours, 200 req/s off-peak"] |
| **SLA Requirements** | [e.g., "SLA doc or customer contract"] | [e.g., "SLA requires p95 < 1s, currently violating SLA"] |

---

## Initial Performance Assessment

> Use this space for initial observations, hypotheses about bottlenecks, quick wins identified, and risks to consider.

**Initial Observations:**
* [e.g., "APM traces show 1.5s spent in database queries"]
* [e.g., "Frontend loads all images at once, no lazy loading"]
* [e.g., "Memory profiler shows large object retention in cache"]

**Bottleneck Hypotheses:**
* [e.g., "Hypothesis 1: N+1 query pattern loading user profiles (high confidence)"]
* [e.g., "Hypothesis 2: Large unoptimized images causing slow load (confirmed by network waterfall)"]
* [e.g., "Hypothesis 3: Cache not evicting old entries (need to profile)"]

**Quick Wins Identified:**
* [e.g., "Add database indexes on frequently queried columns (low risk, high impact)"]
* [e.g., "Enable gzip compression for API responses (trivial change, 60% size reduction)"]
* [e.g., "Implement image lazy loading (well-tested pattern, low risk)"]

**Risks to Consider:**
* [e.g., "Risk: Caching could introduce stale data issues - need cache invalidation strategy"]
* [e.g., "Risk: Database query changes could affect other services - need to verify dependencies"]
* [e.g., "Risk: Memory optimization might increase CPU usage - need to measure trade-offs"]

---

## Performance Optimization Phases

Track the major phases of optimization work from profiling through deployment. This acts as a table of contents for the optimization effort.

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Profiling & Bottleneck Analysis** | [e.g., "Profiling report in docs/perf/analysis-2025-01.md" or "Status: Complete"] | - [ ] Profiling data collected and bottlenecks identified. |
| **Optimization Strategy** | [e.g., "Strategy documented in this card" or "Link to design doc"] | - [ ] Optimization approach is documented with risk assessment. |
| **Baseline Benchmarks** | [e.g., "Benchmark suite created in tests/benchmarks/" or "Link to results"] | - [ ] Baseline performance benchmarks are automated and repeatable. |
| **Optimization Implementation** | [e.g., "PR #789 - optimization changes" or "Status: In Progress"] | - [ ] Optimization changes are implemented and code reviewed. |
| **Performance Validation** | [e.g., "Benchmarks show 70% improvement" or "Link to validation report"] | - [ ] Performance improvement is validated with benchmarks. |
| **Regression Testing** | [e.g., "Full test suite passed, integration tests pass" or "Link to CI run"] | - [ ] Functional regression testing passed (no functionality broken). |
| **Staging Verification** | [e.g., "Deployed to staging, load tested with 1000 req/s" or "Status: Complete"] | - [ ] Performance improvement verified in staging environment. |
| **Production Rollout** | [e.g., "Deployed to production, monitoring for 7 days" or "Link to release"] | - [ ] Optimization is deployed and monitored in production. |

---

## Optimization Iterations

Use this section to track iterative optimization attempts, measurements, and learnings. Each iteration should test a specific optimization hypothesis.

| Iteration # | Optimization Hypothesis | Implementation / Change | Performance Impact | Outcome |
| :---: | :--- | :--- | :--- | :--- |
| **1** | [e.g., "Add database indexes will reduce query time by 50%"] | [e.g., "Added indexes on users.email, profiles.user_id"] | [e.g., "p95: 2s -> 1.2s (40% improvement)"] | [e.g., "Success - keeping change"] |
| **2** | [e.g., "Caching user profiles will reduce DB load"] | [e.g., "Added Redis cache with 5min TTL"] | [e.g., "p95: 1.2s -> 800ms (33% improvement)"] | [e.g., "Success - monitoring for stale data"] |
| **3** | [Hypothesis...] | [Implementation...] | [Impact...] | [Outcome...] |

---

#### Iteration 1: [Optimization Summary, e.g., "Database Index Optimization"]

**Optimization Hypothesis:** [e.g., "Adding database indexes on frequently queried columns (users.email, profiles.user_id) will reduce query execution time by 50% based on EXPLAIN ANALYZE showing full table scans"]

**Implementation / Change:**
[e.g., "Added B-tree indexes:
- CREATE INDEX idx_users_email ON users(email);
- CREATE INDEX idx_profiles_user_id ON profiles(user_id);
Verified index usage with EXPLAIN ANALYZE showing index scans instead of sequential scans."]

**Benchmarks Before:**
* [e.g., "p50: 450ms, p95: 2s, p99: 5s"]
* [e.g., "Database query time: 1.5s average"]
* [e.g., "Throughput: 100 req/s"]

**Benchmarks After:**
* [e.g., "p50: 300ms, p95: 1.2s, p99: 3s"]
* [e.g., "Database query time: 600ms average"]
* [e.g., "Throughput: 150 req/s"]

**Performance Impact:** [e.g., "40% reduction in p95 latency (2s -> 1.2s), 60% reduction in DB query time (1.5s -> 600ms), 50% throughput increase (100 -> 150 req/s)"]

**Functional Testing:** [e.g., "All integration tests pass, manual testing confirms correct behavior, no regressions detected"]

**Outcome:** [e.g., "Success - keeping change. Index maintenance overhead is negligible (<1% write performance impact). Moving to next optimization."]

---

#### Iteration 2: [Optimization Summary, e.g., "User Profile Caching"]

**Optimization Hypothesis:** [e.g., "Caching user profiles in Redis with 5-minute TTL will reduce database load by 80% for repeated requests (based on analytics showing 60% cache hit rate potential)"]

**Implementation / Change:**
[e.g., "Implemented write-through cache in Redis:
- Cache key: user_profile:{user_id}
- TTL: 5 minutes
- Invalidation: On profile update
- Fallback: Query DB on cache miss"]

**Benchmarks Before:**
* [e.g., "p50: 300ms, p95: 1.2s, p99: 3s (post index optimization)"]
* [e.g., "Database load: 1000 queries/s"]

**Benchmarks After:**
* [e.g., "p50: 150ms, p95: 800ms, p99: 2s"]
* [e.g., "Database load: 400 queries/s (60% cache hit rate)"]

**Performance Impact:** [e.g., "33% reduction in p95 latency (1.2s -> 800ms), 60% reduction in DB load (1000 -> 400 queries/s), achieved target p95 < 1s"]

**Functional Testing:** [e.g., "All tests pass. Cache invalidation verified working correctly on profile updates. No stale data observed in 24h monitoring."]

**Outcome:** [e.g., "Success - meets performance target. Monitoring for stale data issues. Added cache metrics dashboard."]

---

#### Iteration 3: [Optimization Summary]

[Copy iteration block for additional optimization attempts]

---

## Optimization Implementation Workflow

Follow this workflow to ensure safe optimization with proper validation at each step.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Profile & Identify Bottleneck** | [e.g., "Used APM traces + flame graphs, bottleneck is N+1 queries" or "Link to profiling report"] | - [ ] Bottleneck is identified with profiling data. |
| **2. Create Baseline Benchmarks** | [e.g., "Created benchmark suite in tests/benchmarks/api_performance.py" or "Link to commit"] | - [ ] Baseline benchmarks are automated and committed. |
| **3. Run Baseline Benchmarks** | [e.g., "p50: 450ms, p95: 2s, p99: 5s (baseline established)" or "Link to results"] | - [ ] Baseline performance is measured and documented. |
| **4. Implement Optimization** | [e.g., "Added database indexes in migration 2025_01_15_add_indexes.sql" or "PR #789"] | - [ ] Optimization is implemented following best practices. |
| **5. Run Performance Tests** | [e.g., "p50: 300ms, p95: 1.2s, p99: 3s (40% improvement)" or "Link to benchmark results"] | - [ ] Performance improvement is validated with benchmarks. |
| **6. Run Functional Tests** | [e.g., "Full test suite passed (500 tests), no regressions" or "Link to CI run"] | - [ ] All functional tests pass (no behavior broken). |
| **7. Code Review** | [e.g., "PR #789 approved by 2 reviewers" or "Status: In review"] | - [ ] Changes are code reviewed for correctness and safety. |
| **8. Deploy to Staging** | [e.g., "Deployed to staging, load tested with production traffic replay" or "Status: Complete"] | - [ ] Optimization is validated in staging environment. |
| **9. Production Rollout** | [e.g., "Deployed to 10% canary, monitoring metrics" or "Full rollout complete"] | - [ ] Gradual production rollout with monitoring. |

#### Implementation Notes

> Document optimization techniques used, trade-offs considered, and implementation details.

**Optimization Techniques:**
* [e.g., "Database indexing on hot query paths"]
* [e.g., "Write-through caching with TTL-based expiration"]
* [e.g., "Query optimization: replaced N+1 with batch loading"]

**Trade-offs & Considerations:**
* [e.g., "Index maintenance adds ~5% write overhead - acceptable for 40% read improvement"]
* [e.g., "Cache introduces 5-minute staleness window - acceptable per product requirements"]
* [e.g., "Memory usage increased 200MB for cache - well within server capacity"]

**Monitoring Added:**
* [e.g., "Added cache hit rate metric to Datadog"]
* [e.g., "Added p95/p99 latency alerts (threshold: 1s)"]
* [e.g., "Added database query slow log monitoring"]

---

## Performance Validation & Release

| Task | Detail/Link |
| :--- | :--- |
| **Baseline Benchmark Results** | [Link to baseline results, e.g., "tests/benchmarks/results/baseline-2025-01-15.json"] |
| **Optimized Benchmark Results** | [Link to optimized results, e.g., "tests/benchmarks/results/optimized-2025-01-22.json"] |
| **Performance Improvement** | [Summary, e.g., "p95: 2s -> 800ms (60% improvement), meets target <1s"] |
| **Functional Test Results** | [e.g., "500 tests passed, 0 regressions" or "Link to CI run"] |
| **Staging Load Test Results** | [e.g., "Load tested 1000 req/s for 1 hour - stable performance" or "Link to report"] |
| **Production Monitoring** | [e.g., "Monitored for 7 days - performance stable, no issues" or "Link to dashboard"] |
| **Code Review** | [e.g., "PR #789 approved by Alice, Bob"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Further Optimization Needed?** | [e.g., "Yes - p99 still at 2s, created PERF-567 for next phase" or "No - target achieved"] |
| **Monitoring & Alerts Updated?** | [e.g., "Yes - added p95 latency alert, cache hit rate dashboard" or "Link to dashboards"] |
| **Documentation Updated?** | [e.g., "Yes - updated architecture docs with caching strategy" or "Link to docs"] |
| **Performance Regression Tests?** | [e.g., "Yes - added to CI pipeline, runs on every PR" or "Link to test suite"] |
| **Team Knowledge Sharing?** | [e.g., "Yes - presented optimization techniques in team meeting 2025-01-25" or "Not needed"] |
| **Similar Optimizations Applicable?** | [e.g., "Yes - same pattern can be applied to Orders service (created PERF-568)" or "No"] |
| **Performance Budget Established?** | [e.g., "Yes - documented p95 < 1s as performance budget in SLA doc" or "Not yet"] |

### Completion Checklist

* [ ] Bottleneck is identified with profiling data (not guesswork).
* [ ] Baseline benchmarks are created and automated.
* [ ] Baseline performance is measured and documented.
* [ ] Optimization is implemented following best practices.
* [ ] Performance improvement is validated with before/after benchmarks.
* [ ] All functional tests pass (no regressions introduced).
* [ ] Changes are code reviewed for correctness and safety.
* [ ] Optimization is validated in staging environment with realistic load.
* [ ] Performance target is achieved (or documented why not).
* [ ] Production rollout is gradual with monitoring (canary or percentage-based).
* [ ] Performance metrics and alerts are updated.
* [ ] Documentation is updated (architecture, performance budgets, optimization techniques).
* [ ] Performance regression tests are added to CI (prevent future degradation).

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
