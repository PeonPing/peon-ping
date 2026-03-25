---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A comprehensive template for formally closing out major projects and roadmap milestones with enterprise best practices including documentation audits, security reviews, technical debt cleanup, knowledge transfer, and roadmap updates before moving to the next initiative.
use_case: Use this for closing out completed major projects, roadmap milestones, or large initiatives before the team transitions to new work. Ensures all loose ends are tied up including docs, security, tech debt, knowledge transfer, celebrations, and roadmap/retrospective archiving.
patterns_used:
  - section: "Project Closeout Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Closeout Audit Checklist"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Documentation & Knowledge Audit"
    pattern: "Pattern 2: Structured Review"
  - section: "Closeout Execution Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Final Project Summary & Transition"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Project Closeout & Transition Template

**When to use this template:** Use this for formally closing out completed major projects, roadmap milestones, large refactoring initiatives, or multi-sprint efforts before the team transitions to new work. Ensures all enterprise best practices are followed including documentation audits, security reviews, technical debt cleanup, knowledge transfer, celebrations, and roadmap archiving.

**When NOT to use this template:** Do not use this for individual cards or small tasks (those close automatically), ongoing maintenance work, or incomplete projects being canceled (use retrospective for those). This is specifically for successful completion of major initiatives that deserve formal closeout.

---

## Project Closeout Overview

* **Project Name:** [Completed project, e.g., "User Authentication System v2", "Monolith to Microservices Migration", "Q4 2024 Roadmap Milestone"]
* **Project Type:** [Category, e.g., "Feature development", "Infrastructure migration", "Roadmap milestone", "Large refactoring"]
* **Completion Date:** [When project finished, e.g., "2025-01-25"]
* **Project Duration:** [How long, e.g., "6 sprints (12 weeks)", "Q4 2024 (3 months)"]
* **Team Members:** [Who worked on it, e.g., "Alice (lead), Bob, Carol, 2 contractors"]
* **Roadmap Reference:** [Link to roadmap, e.g., "roadmap.yaml v1 > m1 > feature-auth", "Q4 milestone"]
* **Related Cards:** [Links, e.g., "Cards FEATURE-100 through FEATURE-125 (25 total)"]
* **Success Criteria Met?** [Assessment, e.g., "Yes - all acceptance criteria achieved", "Mostly - 2 items deferred to v2"]

**Required Checks:**
* [ ] **Project is actually complete** (not just "mostly done" - no loose ends).
* [ ] **Success criteria assessed** (know whether project achieved its goals).
* [ ] **Roadmap reference** documented (for archiving and historical tracking).

---

## Closeout Audit Checklist

Complete all audit areas before final closeout. Each area must be reviewed and signed off.

| Audit Area | Status / Owner | Universal Check |
| :--- | :--- | :---: |
| **Documentation Audit** | [e.g., "Complete - Alice reviewed all docs" or "Link to audit log"] | - [ ] All documentation is current, accurate, and complete. |
| **Security Review** | [e.g., "Complete - Security team signed off 2025-01-20" or "Link to review"] | - [ ] Security review completed, no critical issues remain. |
| **Technical Debt Cleanup** | [e.g., "Complete - 12 tech debt items addressed" or "Link to remaining items"] | - [ ] Technical debt is addressed or documented in backlog. |
| **Test Coverage Audit** | [e.g., "Complete - 85% coverage, all critical paths tested" or "Link to report"] | - [ ] Test coverage meets standards, no critical gaps. |
| **Performance Validation** | [e.g., "Complete - all SLAs met, benchmarks within targets" or "Link to validation"] | - [ ] Performance validated, meets SLAs and targets. |
| **Monitoring & Alerting** | [e.g., "Complete - 15 alerts configured, dashboards published" or "Link to dashboards"] | - [ ] Monitoring, alerts, and dashboards are operational. |
| **Runbook & Operations** | [e.g., "Complete - runbook published, on-call trained" or "Link to runbook"] | - [ ] Runbooks complete, operations team trained. |
| **Knowledge Transfer** | [e.g., "Complete - 3 training sessions, docs published" or "Link to training materials"] | - [ ] Knowledge transferred to team, successors, or stakeholders. |
| **Dependency Cleanup** | [e.g., "Complete - removed 5 unused dependencies, updated 10 outdated" or "List"] | - [ ] Dependencies are up-to-date, unused deps removed. |
| **Code Cleanup** | [e.g., "Complete - removed feature flags, deleted dead code" or "Link to cleanup PR"] | - [ ] Dead code, feature flags, and temporary scaffolding removed. |
| **License Compliance** | [e.g., "Complete - all deps have approved licenses" or "Link to license report"] | - [ ] All dependencies comply with license policies. |
| **Accessibility Audit** | [e.g., "Complete - WCAG 2.1 AA compliant, axe scan passed" or "Link to report"] | - [ ] Accessibility standards met (if applicable to project). |

---

## Documentation & Knowledge Audit

Review all documentation types to ensure completeness, accuracy, and accessibility before closeout.

* [ ] Architecture documentation reviewed and updated.
* [ ] API documentation reviewed and updated [if applicable].
* [ ] Runbooks and troubleshooting guides reviewed and updated.
* [ ] README files reviewed and updated.
* [ ] Code comments and docstrings reviewed for accuracy.
* [ ] ADRs (Architecture Decision Records) reviewed for completeness.
* [ ] User-facing documentation reviewed and updated [if applicable].
* [ ] Knowledge base articles created or updated.

Use the table below to document documentation audit findings. Add rows as needed.

| Documentation Type | Location | Audit Status / Actions Required |
| :--- | :--- | :--- |
| **Architecture Docs** | [e.g., "docs/architecture/auth-system.md"] | [e.g., "Updated - added new OAuth flow diagram, removed outdated sections"] |
| **API Documentation** | [e.g., "OpenAPI spec: docs/api/openapi-v2.yaml"] | [e.g., "Current - all new endpoints documented, examples added"] |
| **Runbooks** | [e.g., "docs/runbooks/auth-troubleshooting.md"] | [e.g., "Created - covers common issues, escalation procedures"] |
| **README** | [e.g., "services/auth-service/README.md"] | [e.g., "Updated - setup instructions, deployment guide current"] |
| **Code Comments** | [e.g., "src/auth/ (200 files)"] | [e.g., "Reviewed - removed outdated TODOs, added context to complex logic"] |
| **ADRs** | [e.g., "docs/adr/ADR-025-oauth-provider.md"] | [e.g., "Complete - documented all major decisions during project"] |
| **User Docs** | [e.g., "help.example.com/auth"] | [e.g., "Published - user guide, FAQs, video tutorials"] |
| **Knowledge Base** | [e.g., "Wiki: Authentication System v2"] | [e.g., "Created - troubleshooting, FAQs, common issues"] |

---

## Closeout Execution Workflow

Follow this workflow to systematically complete all closeout activities. Check off each step as completed.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Complete Audit Checklist** | [e.g., "All 12 audit areas complete" or "Link to audit log"] | - [ ] All audit areas completed and signed off. |
| **2. Archive Completed Cards** | [e.g., "Archived 25 cards to sprint: project-auth-v2-complete" or "Link to archive"] | - [ ] All project cards archived using `archive_cards()` tool. |
| **3. Update Roadmap Status** | [e.g., "Updated roadmap.yaml: v1 > m1 > feature-auth status=done" or "Link to commit"] | - [ ] Roadmap updated to reflect project completion. |
| **4. Generate Sprint Summary** | [e.g., "Generated SUMMARY.md for sprint archive" or "Link to summary"] | - [ ] Sprint summary generated using `generate_archive_summary()` tool. |
| **5. Security Final Review** | [e.g., "Security team final sign-off received 2025-01-22" or "Link to approval"] | - [ ] Final security review completed, no blockers. |
| **6. Performance Final Validation** | [e.g., "Load tested with 2x production traffic, all SLAs met" or "Link to report"] | - [ ] Final performance validation passed. |
| **7. Documentation Final Publish** | [e.g., "All docs published to internal wiki and external help site" or "Links"] | - [ ] All documentation published to appropriate locations. |
| **8. Knowledge Transfer Sessions** | [e.g., "Conducted 3 sessions: arch overview, ops training, dev deep-dive" or "Links to recordings"] | - [ ] Knowledge transfer completed, recorded, and accessible. |
| **9. Cleanup Feature Flags** | [e.g., "Removed 8 feature flags for completed features" or "Link to cleanup PR"] | - [ ] Feature flags removed for completed, stable features. |
| **10. Cleanup Technical Debt** | [e.g., "Addressed 12 tech debt items, documented 3 remaining in backlog" or "Link to backlog"] | - [ ] Technical debt addressed or documented. |
| **11. Dependency Audit & Update** | [e.g., "Updated 10 deps, removed 5 unused, all CVEs patched" or "Link to audit"] | - [ ] Dependencies audited, updated, and compliant. |
| **12. Team Retrospective** | [e.g., "Retro held 2025-01-26, action items created" or "Link to retro notes"] | - [ ] Project retrospective completed with lessons learned. |
| **13. Stakeholder Communication** | [e.g., "Sent project completion email to exec team, product, customers" or "Link to communication"] | - [ ] Stakeholders notified of project completion. |
| **14. Celebration Event** | [e.g., "Team lunch scheduled for 2025-02-01" or "Virtual happy hour held"] | - [ ] Team celebration event held to recognize achievement. |

---

## Gitban Roadmap Integration

Update gitban roadmap to reflect project completion and archive sprint.

### Roadmap Update Steps

1. **Update Project/Feature Status in roadmap.yaml:**
   ```bash
   # Use upsert_roadmap tool to update status to "done"
   # Example: Update feature status in roadmap
   upsert_roadmap(
       content={"status": "done", "completion_date": "2025-01-25"},
       scope="feature",
       version_id="v1",
       milestone_id="m1",
       feature_id="auth-system"
   )
   ```

2. **Add Changelog Entry:**
   ```bash
   # Use update_changelog tool to document completion
   update_changelog(
       entry={
           "version": "2.0.0",
           "date": "2025-01-25",
           "changes": [
               "Completed Authentication System v2 with OAuth support",
               "Migrated 100% of users to new system",
               "Decommissioned legacy auth code"
           ]
       },
       mode="append"
   )
   ```

3. **Archive Project Cards:**
   ```bash
   # Use archive_cards tool to create sprint retrospective
   archive_cards(
       archive_name="project-auth-v2-complete",
       all_done=True,  # Archive all completed cards for this project
       preview=False   # Actually execute the archive
   )
   ```

4. **Generate Sprint Summary:**
   ```bash
   # Use generate_archive_summary tool to create narrative summary
   generate_archive_summary(
       archive_folder_name="sprint-project-auth-v2-complete-20250125",
       mode="enhanced",
       executive_summary="Successfully completed Authentication System v2...",
       lessons_learned={
           "what_went_well": [
               "Strangler Fig pattern worked excellently",
               "Parallel run caught issues before production",
               "Strong team collaboration across disciplines"
           ],
           "what_could_improve": [
               "Stakeholder communication could be more frequent",
               "Performance testing earlier would save time"
           ]
       },
       next_steps=[
           "Add OAuth provider support (scheduled for Q2)",
           "Implement MFA (feature request from enterprise customers)"
       ]
   )
   ```

### Gitban Tools Used for Closeout

| Tool | Purpose | Example Usage |
| :--- | :--- | :--- |
| **`archive_cards()`** | Archive completed project cards into retrospective | `archive_cards("project-auth-v2", all_done=True)` |
| **`generate_archive_summary()`** | Generate narrative summary with lessons learned | `generate_archive_summary("sprint-...", mode="enhanced")` |
| **`upsert_roadmap()`** | Update roadmap feature/project status to "done" | `upsert_roadmap({status: "done"}, scope="feature", ...)` |
| **`update_changelog()`** | Add completion entry to roadmap changelog | `update_changelog({version: "2.0.0", ...})` |
| **`read_roadmap()`** | Review roadmap to verify all items complete | `read_roadmap(scope="milestone", milestone_id="m1")` |
| **`list_roadmap()`** | List all features/projects in milestone to verify completion | `list_roadmap(scope="features", milestone_id="m1")` |

---

## Final Project Summary & Transition

| Task | Detail/Link |
| :--- | :--- |
| **Project Completion Date** | [e.g., "2025-01-25"] |
| **Final Deliverables** | [Links to all major deliverables, e.g., "Auth Service: github.com/..., Docs: docs.example.com/auth"] |
| **Success Metrics** | [Actual vs. target, e.g., "Target: p95 <1s, Actual: 850ms. Target: 100% migration, Actual: 100%"] |
| **Roadmap Archive** | [Link to archived sprint, e.g., "archive/sprints/sprint-project-auth-v2-complete-20250125/"] |
| **Sprint Summary** | [Link to SUMMARY.md, e.g., "archive/sprints/.../SUMMARY.md"] |
| **Documentation Hub** | [Central docs location, e.g., "docs.example.com/auth-v2"] |
| **Monitoring Dashboards** | [Links to dashboards, e.g., "Datadog: auth-v2-health, auth-v2-performance"] |
| **Retrospective** | [Link to retro notes, e.g., "docs/retrospectives/project-auth-v2-retro.md"] |
| **Celebration Event** | [When held, e.g., "Team lunch 2025-02-01, offsite planned for Q2"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Success Metrics Achieved?** | [e.g., "Yes - exceeded all targets: perf +15%, reliability +10%, user satisfaction 95%"] |
| **Deferred Items?** | [e.g., "Yes - created 3 follow-up cards for v2.1: FEATURE-126, FEATURE-127, FEATURE-128"] |
| **Technical Debt Created?** | [e.g., "Minimal - 2 items documented in backlog (low priority)"] |
| **Team Morale?** | [e.g., "High - team proud of accomplishment, celebrating success"] |
| **Stakeholder Satisfaction?** | [e.g., "Very high - exec team pleased, customers praising new features"] |
| **Process Improvements?** | [e.g., "Document Strangler Fig playbook for future large refactorings"] |
| **Next Project Transition?** | [e.g., "Team transitioning to Q1 milestone: payment system modernization"] |
| **Knowledge Retained?** | [e.g., "Yes - comprehensive docs, training materials, recorded sessions"] |

### Completion Checklist

* [ ] All audit areas completed and signed off (12 audit areas).
* [ ] All documentation is current, accurate, and published.
* [ ] Security final review completed, no critical issues.
* [ ] Performance final validation passed, meets SLAs.
* [ ] Technical debt addressed or documented in backlog.
* [ ] Test coverage meets standards, no critical gaps.
* [ ] Monitoring, alerts, and dashboards operational.
* [ ] Runbooks complete, operations team trained.
* [ ] Knowledge transfer completed (sessions, docs, recordings).
* [ ] Feature flags removed for completed features.
* [ ] Dependencies audited, updated, and compliant.
* [ ] All project cards archived using `archive_cards()` tool.
* [ ] Roadmap updated using `upsert_roadmap()` tool.
* [ ] Sprint summary generated using `generate_archive_summary()` tool.
* [ ] Changelog updated using `update_changelog()` tool.
* [ ] Team retrospective completed with lessons learned.
* [ ] Stakeholders notified of completion.
* [ ] Team celebration event held.
* [ ] Successor project identified and team transitioned.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
