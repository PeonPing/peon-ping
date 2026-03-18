---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A general template for investigation spikes focused on answering specific questions or exploring problems through structured research and experimentation. Enforces hypothesis-driven investigation with clear outcomes.
use_case: Use this for time-boxed investigations to answer specific technical questions, explore problems, or validate assumptions before committing to implementation. Perfect for exploring unknowns, prototyping solutions, or researching technical decisions.
patterns_used:
  - section: "Spike Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Context & Background Research"
    pattern: "Pattern 2: Structured Review"
  - section: "Initial Hypotheses & Questions"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Investigation Log"
    pattern: "Pattern 3: Iterative Log"
  - section: "Spike Findings & Recommendation"
    pattern: "Pattern 5: Closeout & Follow-up (with Pattern 8 nested)"
---

# General Investigation Spike Template

**When to use this template:** Use this for time-boxed investigations to answer specific technical questions, explore problems, validate assumptions, or research approaches before committing to full implementation.

**When NOT to use this template:** Do not use this for complex bugs requiring escalation (use bug-escalation), quick idea capture (use spike-idea), designing large refactoring sprints (use refactor-large), or formal project planning. This is for focused investigation work.

---

## Spike Overview

* **Investigation Question:** [The primary question to answer, e.g., "Can we use Redis for session storage?", "Why is the API slow under load?", "What's the best approach for implementing SSO?"]
* **Problem/Opportunity:** [The underlying problem or opportunity, e.g., "Current file-based sessions don't scale", "API response times exceed SLA", "Users want single sign-on"]
* **Time Box:** [Investigation limit, e.g., "4 hours", "1 day", "2 days max"]
* **Success Criteria:** [What defines a successful spike, e.g., "Working PoC showing Redis integration", "Root cause identified", "Recommendation doc with 3 viable approaches"]
* **Priority:** [Urgency, e.g., "P0 - Blocking feature work", "P1 - Needed for Q2 planning", "P2 - Nice to know"]
* **Related Work:** [Links, e.g., "Related to FEATURE-123", "Follow-up from incident POST-456", "Customer request FEEDBACK-789"]

**Required Checks:**
* [ ] **Investigation question** is specific and answerable.
* [ ] **Time box** is defined (prevents endless investigation).
* [ ] **Success criteria** clearly defines what "done" looks like.

---

## Context & Background Research

Before diving into investigation, review existing knowledge, related work, and available documentation.

* [ ] Existing documentation reviewed (internal docs, ADRs, wiki).
* [ ] Related tickets/issues reviewed (past spikes, bug reports, feature requests).
* [ ] Similar systems/implementations reviewed (other teams, open source projects).
* [ ] Team knowledge consulted (asked team members with relevant experience).
* [ ] External research reviewed (blog posts, papers, vendor docs if applicable).

Use the table below to document background research findings. Add rows as needed.

| Source Type | Link / Location | Key Findings / Relevant Context |
| :--- | :--- | :--- |
| **Internal Docs** | [e.g., "docs/architecture/session-management.md"] | [e.g., "Current system uses file-based sessions, known to be slow"] |
| **Past Tickets** | [e.g., "SPIKE-100 from 2024"] | [e.g., "Previous spike explored Redis but didn't implement - worth revisiting"] |
| **Similar Systems** | [e.g., "Team Foo uses Redis for caching"] | [e.g., "Team Foo has working Redis integration we can learn from"] |
| **Team Knowledge** | [e.g., "Alice worked on similar problem"] | [e.g., "Alice suggests looking at session serialization bottleneck"] |
| **External Research** | [e.g., "Redis session store guide"] | [e.g., "Common pattern: use Redis with TTL for auto-expiry"] |

---

## Initial Hypotheses & Questions

> Use this space to brainstorm initial hypotheses, key questions to answer, potential approaches, and known unknowns before investigation begins.

**Initial Hypotheses:**
* [e.g., "Hypothesis: Redis will be faster than file-based sessions due to in-memory storage"]
* [e.g., "Hypothesis: Current API slowness is due to N+1 query problem"]
* [e.g., "Hypothesis: SSO integration will require OAuth 2.0 implementation"]

**Key Questions to Answer:**
* [e.g., "Question: Can Redis handle our session volume (10k concurrent users)?"]
* [e.g., "Question: What's causing the API slowness - database, serialization, or network?"]
* [e.g., "Question: Which SSO providers do we need to support?"]

**Potential Approaches to Explore:**
* [e.g., "Approach 1: Drop-in Redis session store (easiest)"]
* [e.g., "Approach 2: Custom Redis implementation with compression (more complex)"]
* [e.g., "Approach 3: Hybrid approach - Redis for hot sessions, database for cold"]

**Known Unknowns:**
* [e.g., "Unknown: Redis operational overhead (monitoring, backup, failover)"]
* [e.g., "Unknown: Migration path from file-based to Redis sessions"]
* [e.g., "Unknown: Cost of Redis infrastructure (hosting, licensing)"]

**Investigation Constraints:**
* [e.g., "Constraint: Must work with existing framework (Django)"]
* [e.g., "Constraint: Cannot modify database schema during investigation"]
* [e.g., "Constraint: Time box is 1 day - no deep implementation work"]

---

## Investigation Log

| Iteration # | Hypothesis / Goal | Test/Action Taken | Outcome / Findings |
| :---: | :--- | :--- | :--- |
| **1** | [e.g., Hypothesis: Redis is faster than files] | [e.g., Benchmark file sessions vs local Redis] | [e.g., Outcome: Confirmed - Redis 10x faster (5ms vs 50ms)] |
| **2** | [e.g., Goal: Validate Redis scales to 10k users] | [e.g., Load test with simulated 10k sessions] | [e.g., Finding: Redis handles load easily, memory usage: 500MB] |
| **3** | [Hypothesis... or Goal...] | [Test... or Action...] | [Outcome... or Finding...] |

---

#### Iteration 1: [Iteration Summary, e.g., "Baseline Performance Comparison"]

**Hypothesis/Goal:** [e.g., "Hypothesis: Redis session storage will be significantly faster than file-based storage"]

**Test/Action Taken:** [e.g., "Created minimal PoC with both file-based and Redis session stores. Ran 1000 session read/write operations and measured latency. Used local Redis instance for fair comparison."]

**Outcome:** [e.g., "Outcome: Hypothesis confirmed. Redis averaged 5ms per operation vs 50ms for file-based storage (10x improvement). Redis showed consistent performance even under load. File-based storage degraded significantly with concurrent access."]

---

#### Iteration 2: [Iteration Summary, e.g., "Scalability Validation"]

**Hypothesis/Goal:** [e.g., "Goal: Validate that Redis can handle our production load of 10,000 concurrent users"]

**Test/Action Taken:** [e.g., "Used load testing tool to simulate 10,000 concurrent sessions with realistic read/write patterns (80% reads, 20% writes). Monitored Redis memory usage, CPU, and latency metrics."]

**Outcome:** [e.g., "Finding: Redis handled load easily with no degradation. Peak memory usage: 500MB. P95 latency: 8ms. P99 latency: 12ms. CPU usage remained under 20%. Redis is more than capable of handling our production load."]

---

#### Iteration 3: [Iteration Summary]

**Hypothesis/Goal:** [Goal or hypothesis...]

**Test/Action Taken:** [Action taken...]

**Outcome:** [Findings...]

*(Copy and paste the 'Iteration N' block above for each subsequent investigation cycle.)*

---

## Spike Findings & Recommendation

| Task | Detail/Link |
| :--- | :--- |
| **PoC Code** | [e.g., Link to PoC branch or repo] |
| **Test Results** | [e.g., Link to benchmark results or load test report] |
| **Recommendation Doc** | [e.g., Link to detailed recommendation document] |
| **Presentation/Demo** | [e.g., Link to demo recording or slides] |

### Final Synthesis & Recommendation

#### Summary of Findings
[Provide a narrative summary of all findings from the investigation log, directly answering the original research question. Example: "After investigating Redis as a session store replacement, we found that Redis provides 10x performance improvement over file-based sessions (5ms vs 50ms), easily handles our production load of 10k concurrent users with minimal resource usage (500MB memory), and integrates cleanly with our existing Django framework using the django-redis library. The migration path is straightforward with low risk."]

#### Recommendation
[State the clear, actionable recommendation. Example: "We recommend proceeding with Redis session storage implementation. The performance benefits are significant, the integration is straightforward, and the operational overhead is manageable. Next step: Create feature card FEATURE-789 to implement production-ready Redis session store with proper monitoring, backup, and failover."]

#### Alternative Approaches Considered
[Document alternatives that were explored but not recommended, and why. Example: "Alternative 1: Database-backed sessions - Rejected due to performance concerns. Alternative 2: Memcached - Redis offers better persistence and data structure support with similar performance."]

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Implementation Card Created?** | [e.g., Yes - created FEATURE-789 for Redis implementation] |
| **Further Investigation Needed?** | [e.g., No - spike answered all questions] |
| **Documentation Updated?** | [e.g., Yes - added Redis recommendation to architecture docs] |
| **PoC Code Preserved?** | [e.g., Yes - PoC branch preserved for reference: spike/redis-sessions] |
| **Team Communicated?** | [e.g., Yes - presented findings at architecture meeting 2025-01-26] |
| **Lessons Learned?** | [e.g., Lesson: Load testing early in spike saves time later] |

### Completion Checklist

* [ ] Investigation question was clearly answered.
* [ ] All hypotheses were tested and outcomes documented.
* [ ] Success criteria were met (PoC/report/recommendation delivered).
* [ ] Time box was respected (investigation completed within limit).
* [ ] Findings are documented in investigation log.
* [ ] Final recommendation is clear and actionable.
* [ ] Alternative approaches were considered and documented.
* [ ] Follow-up work is captured (implementation cards created).
* [ ] PoC code is preserved [if applicable].
* [ ] Team was communicated findings (demo/presentation/doc).
* [ ] Related tickets updated or closed.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
