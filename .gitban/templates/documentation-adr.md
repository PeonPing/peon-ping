---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the process of creating an Architecture Decision Record (ADR) document to capture important architectural decisions, context, and consequences.
use_case: Use this when an architectural decision needs to be formally documented. The card tracks the ADR creation process, ensures stakeholder review, and verifies the ADR is properly integrated into the documentation system.
patterns_used:
  - section: "ADR Overview & Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Background Research & Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Decision Context Gathering"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "ADR Creation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "ADR Completion & Integration"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Architecture Decision Record (ADR) Creation Template

**When to use this template:** Use this when you need to formally document an important architectural decision that will impact the system design, technology choices, or development approach. ADRs capture the context, options considered, decision made, and consequences for future reference.

**When NOT to use this template:** Do not use this for minor implementation details, code-level decisions, or temporary experiments. Use `spike-technical-design.md` for exploring options before making a decision, or `documentation.md` for general documentation updates. This template is specifically for creating formal ADR documents.

---

## ADR Overview & Context

* **Decision to Document:** [Brief statement of the architectural decision, e.g., "Choose between microservices and monolithic architecture", "Select database technology for analytics workload"]
* **ADR Number:** [Sequential number, e.g., "ADR-015" or "To be assigned"]
* **Triggering Event:** [What prompted this decision, e.g., "Scaling issues with current architecture", "New compliance requirement", "Technology stack modernization"]
* **Decision Owner:** [Who is responsible for the decision, e.g., "Tech Lead", "Architecture Team", "Name"]
* **Stakeholders:** [Who needs to review/approve, e.g., "Engineering team, Product, Security team"]
* **Target ADR Location:** [Where ADR will be stored, e.g., "docs/adr/ADR-015-database-selection.md"]
* **Deadline:** [If applicable, e.g., "Must decide by 2025-02-01 for Q1 planning"]

**Required Checks:**
* [ ] **Decision to document** is clearly stated.
* [ ] **Stakeholders** who need to review are identified.
* [ ] **Target ADR location** follows project conventions (e.g., docs/adr/ADR-NNN-title.md).

---

## Background Research & Review

Before writing the ADR, gather context by reviewing existing documentation, code, and previous decisions.

* [ ] Existing ADRs reviewed for related decisions or precedents.
* [ ] System architecture documentation reviewed for current state.
* [ ] Relevant code/configuration reviewed to understand current implementation.
* [ ] Technical spike or proof-of-concept (if any) reviewed for findings.
* [ ] Stakeholder requirements gathered (compliance, performance, cost, etc.).

Use the table below to document research findings. Add rows as needed.

| Source | Link / Location | Key Information / Relevance |
| :--- | :--- | :--- |
| **Existing ADRs** | [e.g., "docs/adr/ADR-008-api-versioning.md"] | [e.g., "Established precedent for backward compatibility requirements"] |
| **Architecture Docs** | [e.g., "docs/architecture/system-overview.md"] | [e.g., "Current system uses PostgreSQL, shows data flow patterns"] |
| **Technical Spike** | [e.g., "Card SPIKE-456 or Link to PoC repo"] | [e.g., "PoC showed MongoDB performs 3x faster for analytics queries"] |
| **Stakeholder Input** | [e.g., "Email from Security team or Meeting notes"] | [e.g., "Security requires encryption at rest and audit logging"] |
| **Industry Research** | [e.g., "Link to blog post, paper, vendor docs"] | [e.g., "Netflix case study shows microservices scaling benefits"] |
| **Cost Analysis** | [e.g., "Spreadsheet or vendor pricing"] | [e.g., "AWS Aurora vs RDS cost comparison - $500/month difference"] |

---

## Decision Context Gathering

> Use this space to capture the problem, constraints, and requirements that drive this architectural decision.

**Problem Statement:**
* [Clear description of the problem or opportunity, e.g., "Current monolithic architecture cannot scale to handle 10x traffic growth expected in Q2"]

**Constraints:**
* [Technical constraints, e.g., "Must support existing PostgreSQL data model"]
* [Business constraints, e.g., "Budget limited to $2k/month for new infrastructure"]
* [Timeline constraints, e.g., "Must be production-ready by Q1 2025"]
* [Team constraints, e.g., "Team has strong Python experience, limited Go experience"]

**Requirements:**
* [Functional requirements, e.g., "Must support 10,000 requests/second"]
* [Non-functional requirements, e.g., "99.9% uptime SLA", "Sub-100ms latency"]
* [Compliance requirements, e.g., "GDPR compliance", "SOC 2 audit trail"]

**Success Criteria:**
* [How will we know this decision was right?, e.g., "Achieves 10x scaling target", "Team velocity maintained or improved"]

---

## ADR Creation Workflow

Follow this workflow to draft, review, and finalize the ADR document.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Draft ADR Structure** | [e.g., "Created ADR-015-database-selection.md skeleton" or "Link to draft"] | - [ ] ADR file created with standard structure (Title, Status, Context, Decision, Consequences). |
| **2. Write Context Section** | [e.g., "Documented current architecture, scaling challenges" or "Status: In Progress"] | - [ ] Context section explains the problem and why decision is needed. |
| **3. Document Options** | [e.g., "Listed 3 options: keep PostgreSQL, migrate to MongoDB, hybrid approach" or "Section complete"] | - [ ] At least 2 options documented with pros/cons for each. |
| **4. State Decision** | [e.g., "Decision: Hybrid approach - PostgreSQL for transactional, MongoDB for analytics" or "Draft written"] | - [ ] Decision section clearly states the chosen option and rationale. |
| **5. Document Consequences** | [e.g., "Listed consequences: new tech to learn, dual database ops, improved analytics" or "Complete"] | - [ ] Consequences section covers both positive and negative impacts. |
| **6. Stakeholder Review** | [e.g., "Shared with team in Slack, scheduling review meeting" or "Feedback collected"] | - [ ] All identified stakeholders have reviewed and provided feedback. |
| **7. Address Feedback** | [e.g., "Updated decision based on Security team input" or "No changes needed"] | - [ ] Stakeholder feedback is addressed in the ADR. |
| **8. Finalize & Merge** | [e.g., "PR #890 approved and merged" or "Committed to main branch"] | - [ ] ADR is finalized, merged, and published. |

#### ADR Structure Reference

> The ADR should follow this standard structure:

```markdown
# ADR-NNN: [Title of Decision]

**Status:** Proposed | Accepted | Deprecated | Superseded

**Date:** YYYY-MM-DD

**Decision Makers:** [Names]

## Context
[What is the issue we're addressing? What factors are driving this decision?]

## Decision
[What is the change we're making? This should be a clear, declarative statement.]

## Consequences
[What are the positive and negative consequences of this decision?]
- Positive: [List benefits]
- Negative: [List drawbacks, trade-offs, risks]

## Options Considered
### Option 1: [Name]
- Pros: [...]
- Cons: [...]

### Option 2: [Name]
- Pros: [...]
- Cons: [...]

## References
[Links to supporting materials, research, RFCs, etc.]
```

---

## ADR Completion & Integration

| Task | Detail/Link |
| :--- | :--- |
| **Final ADR Location** | [Path, e.g., "docs/adr/ADR-015-database-selection.md"] |
| **ADR Status** | [Status in ADR, e.g., "Accepted", "Proposed (pending budget approval)"] |
| **Stakeholder Approval** | [Who approved, e.g., "Approved by: Tech Lead (Alice), Security (Bob), Product (Carol)"] |
| **Communication** | [How decision was shared, e.g., "Announced in all-hands meeting", "Posted in #engineering Slack"] |
| **Related Work** | [Links to implementation cards, e.g., "Created FEATURE-789 to implement hybrid database approach"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Implementation Cards?** | [e.g., "Yes - created FEATURE-789, INFRA-234, DOCS-456" or "No implementation needed (rejected option documented)"] |
| **ADR Index Updated?** | [e.g., "Yes - added ADR-015 to docs/adr/README.md" or "Link to index"] |
| **Architecture Diagrams?** | [e.g., "Yes - updated system diagram to show dual database" or "No changes needed"] |
| **Team Training Needed?** | [e.g., "Yes - scheduled MongoDB training for 2025-02-15" or "No - team has expertise"] |
| **Monitoring/Alerts?** | [e.g., "Yes - created INFRA-345 to add MongoDB health checks" or "Covered in implementation cards"] |
| **Future Review Date?** | [e.g., "Review decision after 6 months (2025-08-01)" or "N/A"] |

### Completion Checklist

* [ ] ADR document is complete with all required sections (Context, Decision, Consequences, Options).
* [ ] At least 2 options were documented and compared.
* [ ] All identified stakeholders reviewed and approved the ADR.
* [ ] ADR is merged into the repository at the correct location.
* [ ] ADR index (e.g., docs/adr/README.md) is updated with new entry.
* [ ] Decision is communicated to relevant teams (Slack, email, meeting).
* [ ] Implementation cards are created if decision requires action.
* [ ] Architecture documentation is updated to reflect the decision [if applicable].
* [ ] Future review date is set (if decision needs periodic reassessment).

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
