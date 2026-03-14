---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for triaging and planning multiple issues during a planning session, producing appropriate gitban cards for each based on complexity and type.
use_case: "Use this for planning meetings where you need to understand scope, categorize work, and create follow-up cards for a mixed batch of issues."
patterns_used:
  - section: "Planning Session Overview"
    pattern: "Pattern 1: Section Header"
  - section: "Initial Issue Brainstorm"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Issue Triage & Analysis"
    pattern: "Pattern 3: Iterative Log (adapted for issue categorization)"
  - section: "Card Generation Plan"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Session Closeout & Follow-up"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Planning Session Spike

## Planning Session Overview

* **Session Date:** [e.g., 2025-11-19]
* **Meeting Context:** [e.g., Sprint Planning, Incident Review, Roadmap Planning, Technical Debt Review]
* **Attendees:** [e.g., Engineering Team, Product, QA]

**Required Checks:**
* [ ] **Session Date** is recorded above.
* [ ] **Meeting Context** is identified.
* [ ] **Attendees** are listed.

## Time Box

**Maximum Duration:** [e.g., 2 hours, 4 hours, 1 day]

**Success Criteria:**
* [ ] All issues from the meeting are triaged and categorized
* [ ] Each issue has a complexity estimate (small/medium/large)
* [ ] Each issue has a proposed card type (feature/bug/spike/chore/docs/refactor)
* [ ] Follow-up cards are created for all high-priority items
* [ ] Backlog cards are created for deferred items

## Context & Background

**Why This Planning Session:**
[Explain the trigger for this planning session - e.g., "After architecture review meeting, several improvement areas identified" or "Post-mortem from production incident revealed multiple follow-up actions"]

**What's Blocking:**
[Describe what needs clarity - e.g., "Need to categorize and scope these issues before committing to sprint" or "Unclear which issues are quick wins vs. major projects"]

**Cost of Not Planning:**
[Explain urgency - e.g., "Team capacity planning depends on understanding scope" or "Some issues may be blocking other work"]

---

### Initial Issue Brainstorm

> Use this space to capture all issues mentioned during the meeting. Don't worry about structure yet - just capture everything.

* [e.g., "API timeout on user endpoint"]
* [e.g., "Need better error messages in UI"]
* [e.g., "Documentation missing for deployment process"]
* [e.g., "Tech debt in auth module - needs refactoring"]
* [e.g., "Research new caching strategy"]
* [e.g., "Add integration tests for payment flow"]
* [e.g., "Known Unknown: Not sure if the database schema needs changes for this"]

---

### Issue Triage & Analysis

| Issue # | Issue Summary | Type (feature/bug/spike/chore/docs/refactor) | Complexity (small/medium/large) | Priority (P0/P1/P2) | Notes & Dependencies |
| :---: | :--- | :--- | :--- | :--- | :--- |
| **1** | [e.g., API timeout on user endpoint] | [e.g., bug] | [e.g., medium] | [e.g., P0] | [e.g., "Affects production users. Quick fix possible but needs investigation first."] |
| **2** | [e.g., Better error messages in UI] | [e.g., feature] | [e.g., small] | [e.g., P1] | [e.g., "Nice to have, can be done in one sprint."] |
| **3** | [e.g., Deployment docs missing] | [e.g., docs] | [e.g., small] | [e.g., P2] | [e.g., "Low priority but needed for onboarding."] |
| **4** | [e.g., Auth module refactor] | [e.g., refactor] | [e.g., large] | [e.g., P1] | [e.g., "Big project, may need dedicated sprint. Depends on security review."] |
| **5** | [e.g., Research caching strategy] | [e.g., spike] | [e.g., medium] | [e.g., P1] | [e.g., "Need spike first to understand approach. Time-box to 1 day."] |

---
#### Issue 1: [Summary]

**Type:** [feature/bug/spike/chore/docs/refactor]

**Complexity Assessment:** [small/medium/large]

**Reasoning:** [e.g., "Small: Can be done in <4 hours with existing code. No new dependencies." or "Large: Requires architecture changes, new infrastructure, and affects multiple services."]

**Proposed Card Type & Template:** [e.g., "bug-production.md" or "feature.md" or "spike-technical-design.md"]

**Dependencies:** [e.g., "Blocked by Issue #5 (caching spike)" or "None - can start immediately"]

**Recommended Action:** [e.g., "Create P0 bug card and assign to on-call engineer" or "Create spike card first, then follow-up feature card after spike completes" or "Defer to next quarter - create P2 backlog card"]

*(Copy and paste the 'Issue N' block above for each issue from the triage table.)*

---

### Card Generation Plan

| Card to Create | Type | Priority | Template to Use | Status / Link to Card | Universal Check |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **[e.g., API timeout investigation]** | [e.g., bug] | [e.g., P0] | [e.g., bug-production.md] | [e.g., Link to card abc123 or Status: TODO] | - [ ] Card created |
| **[e.g., Caching strategy research]** | [e.g., spike] | [e.g., P1] | [e.g., spike-technical-design.md] | [e.g., Link to card def456 or Status: TODO] | - [ ] Card created |
| **[e.g., Auth refactor epic]** | [e.g., refactor] | [e.g., P1] | [e.g., refactor.md] | [e.g., Link to card ghi789 or Status: TODO] | - [ ] Card created |
| **[e.g., Deployment documentation]** | [e.g., docs] | [e.g., P2] | [e.g., docs.md] | [e.g., Link to card jkl012 or Status: TODO] | - [ ] Card created |

---

## Session Closeout & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Total Issues Triaged** | [e.g., 12 issues] |
| **Cards Created** | [e.g., 8 cards (5 immediate, 3 backlog)] |
| **Issues Deferred** | [e.g., 4 issues deferred to Q2] |
| **Meeting Notes** | [e.g., Link to meeting doc or Confluence page] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Sprint Capacity Impact** | [e.g., "P0 bug will consume 20% of sprint. Adjust other commitments." or "All issues fit in current sprint plan."] |
| **Dependencies Identified?** | [e.g., "Issue #4 blocked by Issue #5 spike. Spike must complete first."] |
| **Architecture Review Needed?** | [e.g., "Yes - auth refactor needs architecture approval before starting." or "No - all issues are implementation-ready."] |
| **Further Planning Required?** | [e.g., "Yes - need separate technical design meeting for auth refactor" or "No - ready to start work."] |

### Completion Checklist

* [ ] All issues from the meeting are documented in the triage table.
* [ ] Each issue has complexity estimate and proposed card type.
* [ ] High-priority cards (P0/P1) are created and assigned.
* [ ] Backlog cards (P2) are created for deferred work.
* [ ] Dependencies between cards are documented.
* [ ] Sprint capacity impact is assessed.
* [ ] Follow-up actions (architecture review, design meetings, etc.) are scheduled.
* [ ] Planning session notes are linked or attached.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
