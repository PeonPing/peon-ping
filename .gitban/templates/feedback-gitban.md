---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for capturing and tracking client feedback about the gitban MCP server
use_case: Use this for any type of client feedback - bug reports, feature requests, usability issues, or general suggestions about gitban.
patterns_used:
  - section: "Feedback Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Initial Notes"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Response & Action"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Resolution & Follow-up"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Gitban Feedback Template

**When to use this template:** Use this for capturing any client feedback about the gitban MCP server, including bug reports, feature requests, usability concerns, documentation issues, or general suggestions.

**When NOT to use this template:** Do not use this for internal development work on gitban itself - use the appropriate feature, bug, or spike templates instead.

## Feedback Overview

* **Client/Source:** [e.g., John Doe, GitHub Issue #123, Email from Team X]
* **Feedback Type:** [e.g., Bug Report, Feature Request, Usability Issue, Documentation Gap, General Suggestion]
* **Date Received:** [e.g., 2025-11-23]
* **gitban Version:** [e.g., v1.2.3 or "unknown"]
* **Environment:** [e.g., VSCode, Claude Desktop, API Integration]

**Required Checks:**
* [ ] Client/source is documented above.
* [ ] Feedback type is identified.
* [ ] Date received is recorded.

### Initial Notes

> Use this space to capture the raw feedback exactly as received. Include direct quotes, screenshots, error messages, or any context provided by the client.

* [e.g., Client quote: "The card creation flow is confusing when dealing with templates"]
* [e.g., Error message: "Failed to load help article: 'getting-started'"]
* [e.g., Screenshot: [Link or path to image]]
* [e.g., Context: "User was trying to create their first card and got stuck"]
* [e.g., Additional notes: "This is the third time we've heard about this issue"]

### Response & Action

| Phase / Task | Status / Assignee / Link | Universal Check |
| :--- | :--- | :---: |
| **Initial Assessment** | [e.g., Reviewed by Alice, Valid Issue] | - [ ] Feedback assessed |
| **Priority Decision** | [e.g., P1 - High Priority] | - [ ] Priority assigned |
| **Response to Client** | [e.g., Acknowledged via email on 2025-11-24] | - [ ] Client acknowledged |
| **Investigation** | [e.g., Link to investigation card or notes] | - [ ] Root cause identified |
| **Implementation** | [e.g., Link to bug card, feature card, or docs update] | - [ ] Fix/improvement implemented |
| **Client Verification** | [e.g., Asked client to verify fix] | - [ ] Client verified resolution |

### Resolution & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Final Resolution** | [e.g., Fixed in v1.3.0, Documentation updated, Feature added] |
| **Client Communication** | [e.g., Emailed client on 2025-11-30 with resolution] |
| **Related Work** | [e.g., Link to PR, card, or docs update] |

#### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Pattern Recognition** | [e.g., Similar feedback received 3 times - indicates systemic issue] |
| **Documentation Needed** | [e.g., Created FAQ entry or Added example to docs] |
| **Further Investigation** | [e.g., Identified broader usability concern - created UX research card] |
| **Process Improvement** | [e.g., Updated onboarding flow to prevent this confusion] |

#### Completion Checklist

* [ ] Feedback was assessed and prioritized.
* [ ] Client was acknowledged and kept informed.
* [ ] Root cause was identified [if applicable].
* [ ] Resolution was implemented or decision was documented.
* [ ] Client was notified of resolution.
* [ ] Any follow-up work was created and tracked.
* [ ] Lessons learned were documented.

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
