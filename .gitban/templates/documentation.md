---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking documentation hygiene, review, and maintenance tasks to ensure docs stay current and well-organized.
use_case: Use this when you need to track doc updates after feature work, audit existing documentation, or ensure documentation best practices are followed. Prevents doc cruft and ensures homework is done before creating new docs.
patterns_used:
  - section: "Documentation Scope & Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Pre-Work Documentation Audit"
    pattern: "Pattern 2: Structured Review (e.g., Doc Review)"
  - section: "Documentation Work"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Validation & Closeout"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Documentation Maintenance & Review

## Documentation Scope & Context

* **Related Work:** [e.g., Feature card ID, sprint name, or "Quarterly doc review"]
* **Documentation Type:** [e.g., Runbooks, API docs, README updates, Architecture docs]
* **Target Audience:** [e.g., Engineers, operators, external users, new hires]

**Required Checks:**
* [ ] Related work/context is identified above
* [ ] Documentation type and audience are clear
* [ ] Existing documentation locations are known (avoid creating duplicates)

---

## Pre-Work Documentation Audit

Before creating new documentation or updating existing docs, review what's already there to avoid duplication and ensure proper organization.

* [ ] Repository root reviewed for doc cruft (stray .md files, outdated READMEs)
* [ ] `/docs` directory (or equivalent) reviewed for existing coverage
* [ ] Related service/component documentation reviewed
* [ ] Team wiki or internal docs reviewed

Use the table below to log findings and identify what needs attention:

| Document Location | Current State | Action Required |
| :--- | :--- | :--- |
| **README.md** | [e.g., "Outdated setup instructions"] | [e.g., "Update for new config format"] |
| **docs/runbooks/** | [e.g., "Missing incident response playbook"] | [e.g., "Create new runbook for X service"] |
| **Internal Wiki** | [e.g., "Architecture diagram out of date"] | [e.g., "Update diagram with new components"] |
| **API Docs** | [e.g., "New endpoints not documented"] | [e.g., "Add OpenAPI specs for /v2 endpoints"] |
| **Other Location** | [Findings...] | [Action...] |

**Documentation Organization Check:**
* [ ] No duplicate documentation found across locations
* [ ] Documentation follows team's organization standards
* [ ] Cross-references between docs are working
* [ ] Orphaned or outdated docs identified for cleanup

---

## Documentation Work

Track the actual documentation tasks that need to be completed:

| Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **[e.g., Update README]** | [e.g., PR #123 or "In Progress"] | - [ ] Complete |
| **[e.g., Create Runbook]** | [e.g., Link to runbook doc] | - [ ] Complete |
| **[e.g., Update API Docs]** | [e.g., Link to OpenAPI spec] | - [ ] Complete |
| **[e.g., Clean Up Old Docs]** | [e.g., PR #124 removing outdated files] | - [ ] Complete |
| **[e.g., Update Wiki]** | [e.g., Link to wiki page] | - [ ] Complete |

**Documentation Quality Standards:**
* [ ] All code examples tested and working
* [ ] All commands verified
* [ ] All links working (no 404s)
* [ ] Consistent formatting and style
* [ ] Appropriate for target audience
* [ ] Follows team's documentation style guide

---

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Final Location** | [e.g., Merged to docs/ directory or Published to wiki] |
| **Path to final** | [e.g., path/to/the/exact/file/youre/probably/looking/for] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Documentation Gaps Identified?** | [e.g., Yes - created card for monitoring docs or No gaps found] |
| **Style Guide Updates Needed?** | [e.g., Yes - proposed update for handling examples or No changes needed] |
| **Future Maintenance Plan** | [e.g., Added to quarterly review checklist or Created reminder for next release] |

### Completion Checklist

* [ ] All documentation tasks from work plan are complete
* [ ] Documentation is in the correct location (not in root dir or random places)
* [ ] Cross-references to related docs are added
* [ ] Documentation is peer-reviewed for accuracy
* [ ] No doc cruft left behind (old files cleaned up)
* [ ] Future maintenance plan identified [if applicable]
* [ ] Related work cards are updated [if applicable]

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
