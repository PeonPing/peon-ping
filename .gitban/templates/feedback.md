---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for capturing, organizing, and tracking feedback about any topic, feature, process, or system. Supports structured feedback collection with categorization, prioritization, and action tracking.
use_case: Use this for collecting feedback from users, stakeholders, team members, or customers about any topic. Ideal for feature requests, process improvements, UX feedback, or general suggestions. Tracks feedback through analysis to actionable outcomes.
patterns_used:
  - section: "Feedback Overview & Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Initial Feedback Collection"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Feedback Analysis & Categorization"
    pattern: "Pattern 3: Iterative Log"
  - section: "Related Context Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Feedback Processing & Action Planning"
    pattern: "Pattern 4: Process Workflow"
  - section: "Feedback Resolution & Follow-up"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Feedback Capture Template

**When to use this template:** Use this for capturing feedback from any source (users, stakeholders, team members, customers) about any topic including features, processes, UX, bugs, or general suggestions. Ideal for organizing feedback into actionable items with clear prioritization and tracking.

**When NOT to use this template:** Do not use this for confirmed bugs (use `bug.md`), planned features (use `feature.md`), or active research (use `spike.md`). This template is specifically for capturing, analyzing, and triaging feedback before it becomes a formal work item.

---

## Feedback Overview & Context

* **Feedback Topic:** [What is the feedback about, e.g., "User dashboard performance", "API documentation clarity", "Team sprint process"]
* **Feedback Source:** [Who provided it, e.g., "Customer via support ticket", "Internal team survey", "User interview", "Product analytics"]
* **Source Details:** [Link or reference, e.g., "Support ticket #12345", "Survey results Q4 2025", "Interview notes: docs/interviews/user-001.md"]
* **Feedback Date:** [When received, e.g., "2025-01-15" or "Q4 2025 survey period"]
* **Feedback Channel:** [How received, e.g., "Email", "Slack #feedback", "User interview", "Survey", "GitHub issue"]
* **Urgency Level:** [Priority assessment, e.g., "High - blocking user workflow", "Medium - quality of life improvement", "Low - nice to have"]
* **Affected Stakeholders:** [Who this impacts, e.g., "All mobile users", "API consumers", "Internal engineering team", "Specific customer segment"]

**Required Checks:**
* [ ] **Feedback topic** is clearly stated.
* [ ] **Feedback source** is documented with reference link/details.
* [ ] **Urgency level** is assigned based on impact and scope.

---

## Initial Feedback Collection

> Use this space to capture the raw feedback as received. Include direct quotes, observations, pain points, and any context provided by the feedback source.

**Raw Feedback / Quotes:**
* [e.g., "The dashboard takes 10+ seconds to load on mobile"]
* [e.g., "We can't figure out how to authenticate - the docs are confusing"]
* [e.g., "Why do we have three different retrospective formats? It's inconsistent"]
* [e.g., Quote from user: "I love the feature but wish it had dark mode"]

**Observed Pain Points:**
* [e.g., Performance issue affecting mobile users]
* [e.g., Documentation clarity gap for new API users]
* [e.g., Process inconsistency causing team confusion]

**Context / Background:**
* [e.g., User is on 4G connection in rural area]
* [e.g., New developer onboarding, first week with API]
* [e.g., Team has grown from 5 to 15 people in 6 months]

**Initial Hypotheses / Questions:**
* [e.g., Hypothesis: Dashboard loads too many assets at once]
* [e.g., Question: Are other users experiencing the same docs confusion?]
* [e.g., Question: When did the process divergence start?]

---

## Related Context Review

Before analyzing the feedback, review any existing documentation, similar feedback, or related work that provides context.

* [ ] Existing documentation reviewed (README, wiki, user guides).
* [ ] Similar feedback or related issues reviewed (support tickets, GitHub issues, past surveys).
* [ ] Product roadmap reviewed for planned work in this area.
* [ ] Analytics or metrics reviewed (if applicable - usage data, error rates, performance metrics).
* [ ] Team knowledge gathered (asked relevant team members for context).

Use the table below to document what was reviewed and what was learned. Add rows as needed.

| Review Source | Link / Location | Key Findings / Relevance |
| :--- | :--- | :--- |
| **Similar Feedback** | [e.g., "Support tickets #11234, #11567, #11890"] | [e.g., "3 other users reported same dashboard slowness on mobile"] |
| **Analytics** | [e.g., "Datadog dashboard: dashboard-performance"] | [e.g., "p95 load time is 12s on mobile vs 2s on desktop"] |
| **Roadmap** | [e.g., "Q1 2025 roadmap doc"] | [e.g., "Dashboard performance optimization already planned for Q1"] |
| **Documentation** | [e.g., "docs/api/authentication.md"] | [e.g., "Auth docs were last updated 2 years ago, need refresh"] |
| **Team Input** | [e.g., "Slack thread in #engineering"] | [e.g., "Frontend team aware of issue, has PoC fix in progress"] |

---

## Feedback Analysis & Categorization

Analyze the feedback to understand root causes, categorize by type, and assess impact. Track analysis iterations if needed.

| Iteration # | Analysis Goal | Investigation / Action | Finding / Insight |
| :---: | :--- | :--- | :--- |
| **1** | [e.g., Understand scope - how many users affected?] | [e.g., Queried support tickets for similar issues] | [e.g., Finding: 15 users reported this in past 30 days] |
| **2** | [e.g., Validate root cause hypothesis] | [e.g., Profiled dashboard load on mobile device] | [e.g., Finding: 8MB of images loaded on initial render] |
| **3** | [Analysis goal...] | [Investigation...] | [Finding...] |

---

#### Iteration 1: [Analysis Goal Summary, e.g., "Scope Assessment"]

**Analysis Goal:** [e.g., Determine how many users are affected by this feedback and whether it's an isolated case or systemic issue]

**Investigation / Action Taken:** [e.g., Queried support ticket database for similar complaints, checked analytics for mobile user counts, reviewed user forum discussions]

**Finding / Insight:** [e.g., Found 15 support tickets in past 30 days with similar complaint, 40% of mobile users have load times >8s, multiple forum posts confirm this is a known pain point]

---

#### Iteration 2: [Analysis Goal Summary, e.g., "Root Cause Validation"]

**Analysis Goal:** [e.g., Validate the hypothesis that dashboard is loading too many assets on mobile]

**Investigation / Action Taken:** [e.g., Profiled dashboard load on real mobile device (iPhone 12, 4G connection), analyzed network waterfall in Chrome DevTools]

**Finding / Insight:** [e.g., Dashboard loads 8MB of unoptimized images on initial render, images are not lazy-loaded, no responsive image sizes configured - clear root cause identified]

---

### Feedback Categorization

| Category | Value / Notes |
| :--- | :--- |
| **Feedback Type** | [e.g., "Bug Report", "Feature Request", "UX Improvement", "Process Change", "Documentation Gap"] |
| **Severity** | [e.g., "Critical - blocking users", "High - major pain point", "Medium - inconvenience", "Low - nice to have"] |
| **Scope** | [e.g., "All mobile users (40% of user base)", "New API users", "Internal team only"] |
| **Root Cause** | [e.g., "Dashboard loads 8MB of unoptimized images", "Auth docs outdated", "Process never formalized"] |
| **Effort Estimate** | [e.g., "Medium - 1 week", "Small - 1 day", "Large - 1 month", "Unknown - needs spike"] |
| **Business Impact** | [e.g., "High - affects user retention", "Medium - affects developer experience", "Low - internal efficiency"] |

---

## Feedback Processing & Action Planning

Track the workflow for converting feedback into actionable work items, linking to follow-up cards or documenting decisions.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Validate Feedback** | [e.g., "Validated with 15 support tickets and analytics" or "Status: Complete"] | - [ ] Feedback is validated with evidence (not just anecdotal). |
| **2. Prioritize** | [e.g., "Prioritized as P0 - affects 40% of users" or "P2 - nice to have"] | - [ ] Priority assigned based on impact, scope, and urgency. |
| **3. Define Action** | [e.g., "Action: Optimize dashboard images" or "Action: Rewrite auth docs"] | - [ ] Clear action is defined to address the feedback. |
| **4. Create Follow-up Card(s)** | [e.g., "Created BUG-456 for image optimization" or "No action - marked as won't fix"] | - [ ] Follow-up card created OR decision documented to not act. |
| **5. Communicate Decision** | [e.g., "Replied to user with timeline" or "Posted update in #feedback Slack"] | - [ ] Feedback source is notified of decision/timeline. |
| **6. Track to Completion** | [e.g., "Linked to BUG-456 (in progress)" or "Closed - completed in v2.3.0"] | - [ ] Follow-up work is tracked to completion or closure. |

#### Action Decision

> Document the decision made based on feedback analysis.

**Decision:** [e.g., "Proceed with dashboard image optimization as P0 bug fix" or "Defer API docs rewrite to Q2 2025" or "Won't fix - edge case affecting <1% of users"]

**Rationale:** [e.g., "Affects 40% of user base with measurable performance impact. Clear root cause identified with straightforward fix. High ROI."]

**Follow-up Cards Created:**
* [e.g., "BUG-456: Optimize dashboard image loading for mobile" or "N/A - no action taken"]
* [e.g., "DOCS-789: Rewrite API authentication guide" or "Link to card"]

**Estimated Timeline:** [e.g., "Fix targeted for v2.3.0 release (Sprint 25, 2 weeks)" or "Scheduled for Q2 2025"]

---

## Feedback Resolution & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Follow-up Card(s)** | [Links to created cards, e.g., "BUG-456, DOCS-789" or "N/A - no action"] |
| **Decision Rationale** | [Summary, e.g., "Prioritized as P0 due to impact on 40% of users" or "Deferred - low impact"] |
| **Communication Sent** | [How feedback source was notified, e.g., "Replied to support ticket #12345 with timeline" or "Posted update in forum"] |
| **Completion Status** | [e.g., "Resolved in v2.3.0" or "In progress - see BUG-456" or "Closed - won't fix"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Similar Feedback Expected?** | [e.g., "Yes - added to FAQ and monitoring for similar reports" or "No - isolated case"] |
| **Process Improvement?** | [e.g., "Yes - added mobile performance testing to CI" or "No changes needed"] |
| **Documentation Needed?** | [e.g., "Yes - updated troubleshooting guide with this scenario" or "Already documented"] |
| **Proactive Communication?** | [e.g., "Yes - posted release notes announcing fix" or "Sent email to affected users"] |
| **Feedback Loop Closed?** | [e.g., "Yes - user confirmed fix resolved issue" or "Waiting for v2.3.0 release"] |

### Completion Checklist

* [ ] Feedback is validated with supporting evidence or data.
* [ ] Root cause is understood [if applicable].
* [ ] Priority and scope are assessed based on impact.
* [ ] Decision is made: act on feedback, defer, or close as won't fix.
* [ ] Follow-up card is created (if actionable) or decision is documented.
* [ ] Feedback source is notified of decision and timeline.
* [ ] Action is tracked to completion (or documented as closed).
* [ ] Lessons learned are captured for process improvement.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
