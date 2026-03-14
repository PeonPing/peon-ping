---
description: Decision tracking template for stakeholder and leadership discussions. Captures decision context, options evaluated, outcomes, and rationale to maintain an audit trail.
use_case: Use when decisions require stakeholder input or leadership approval, especially when multiple options are being evaluated and the rationale needs to be documented for future reference.
patterns_used:
  - section: "Decision Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Options & Evaluation"
    pattern: "Pattern 3: Comparison Table"
  - section: "Decision Log"
    pattern: "Pattern 4: Process Workflow"
---

# [Decision Topic] - Stakeholder/Leadership Decision Tracking

**Context**: [Brief description of why these decisions are needed and what they will inform]

**Related Card/Project**: [Reference to parent card or project, if applicable]

**Note**: This template is for tracking **stakeholder/leadership decisions** (business rules, requirements, policies, approvals). For **technical research decisions** (architecture choices, technology evaluations, ADRs), use `spike-technical-design.md` instead.

---

## AI Assistant Instructions

This template is for **gathering** stakeholder decisions, not making them.

When you encounter decision checkboxes, "TBD" fields, or decision tables:

1. **Ask the stakeholder** using `AskUserQuestion` or direct questions
2. **Record their answers** verbatim in the decision log
3. **Do NOT fill in decisions** based on your own judgment
4. **Wait for input** before marking any decision checkbox complete

You are **facilitating** decision-making, not performing it. The stakeholder's input is the deliverable, not your analysis.

**Wrong approach**: Analyzing options and filling in what seems best
**Right approach**: "What is your decision on X?" then recording their answer

---

## Decision Checkboxes by Category

### Category 1: [Domain/Area Name]

- [ ] **Decision 1**: [Clear question or decision to be made]
- [ ] **Decision 2**: [Clear question or decision to be made]
- [ ] **Decision 3**: [Clear question or decision to be made]

### Category 2: [Domain/Area Name]

- [ ] **Decision 4**: [Clear question or decision to be made]
- [ ] **Decision 5**: [Clear question or decision to be made]
- [ ] **Decision 6**: [Clear question or decision to be made]

### Category 3: [Domain/Area Name]

- [ ] **Decision 7**: [Clear question or decision to be made]
- [ ] **Decision 8**: [Clear question or decision to be made]

---

## Decision Tables to Fill In

### Table 1: [Table Name/Purpose]

| [Column 1] | [Column 2] | [Column 3] | [Column 4 - Justification] |
|-----------|-----------|-----------|---------------------------|
| [Item 1] | [Current/Expected Value] | [Target/Desired Value] | [Why this decision?] |
| [Item 2] | [Current/Expected Value] | [Target/Desired Value] | [Why this decision?] |
| [Item 3] | [Current/Expected Value] | [Target/Desired Value] | [Why this decision?] |

### Table 2: [Table Name/Purpose]

| [Column 1] | [Column 2] | [Column 3] | [Column 4 - Rationale] |
|-----------|-----------|-----------|------------------------|
| [Item 1] | [Details] | [Decision/Value] | [Why important?] |
| [Item 2] | [Details] | [Decision/Value] | [Why important?] |
| [Item 3] | [Details] | [Decision/Value] | [Why important?] |

### Table 3: [Table Name/Purpose]

| [Column 1] | [Column 2] | [Column 3] | [Column 4] |
|-----------|-----------|-----------|-----------|
| [Item 1] | [Value 1] | [Value 2] | [Value 3] |
| [Item 2] | [Value 1] | [Value 2] | [Value 3] |
| [Item 3] | [Value 1] | [Value 2] | [Value 3] |

---

## Completion Checklist

### By Decision Domain

**[Domain 1]:**
- [ ] All decision checkboxes completed
- [ ] Relevant tables filled in
- [ ] Stakeholder agreement documented
- [ ] Next steps identified

**[Domain 2]:**
- [ ] All decision checkboxes completed
- [ ] Relevant tables filled in
- [ ] Stakeholder agreement documented
- [ ] Next steps identified

**[Domain 3]:**
- [ ] All decision checkboxes completed
- [ ] Relevant tables filled in
- [ ] Stakeholder agreement documented
- [ ] Next steps identified

---

## Meeting/Discussion Notes

### Meeting 1: [Meeting Name/Topic]

**Date:** [To be filled]
**Participants:** [To be filled]
**Duration:** [To be filled]

#### Key Decisions Made

[To be filled during meeting]

#### Open Questions

1. **Question:** [Description]
   - **Answer:** TBD
   - **Follow-up Required:** Yes/No
   - **Owner:** [Name]
   - **Due Date:** [Date]

#### Action Items

- [ ] **Action 1:** [Description] - Owner: [Name] - Due: [Date]
- [ ] **Action 2:** [Description] - Owner: [Name] - Due: [Date]

### Meeting 2: [Meeting Name/Topic]

**Date:** [To be filled]
**Participants:** [To be filled]
**Duration:** [To be filled]

#### Key Decisions Made

[To be filled during meeting]

#### Open Questions

[To be filled]

#### Action Items

[To be filled]

---

## Decision Log

Record all finalized decisions here for easy reference:

1. **[Decision Topic]**: [Decision made] - [Date] - [Decision maker/stakeholder]
2. **[Decision Topic]**: [Decision made] - [Date] - [Decision maker/stakeholder]
3. **[Decision Topic]**: [Decision made] - [Date] - [Decision maker/stakeholder]

---

## Next Steps

1. **Step 1**: [Description]
2. **Step 2**: [Description]
3. **Step 3**: [Description]

---

## Timeline

- **Estimated Effort**: [Duration] (including scheduling/coordination)
- **Dependencies**: [List any blocking dependencies]
- **Blocks**: [What work is blocked by these decisions]

---

## Supporting Documentation

**Reference Materials:**
- [Link or path to supporting document 1]
- [Link or path to supporting document 2]
- [Link or path to supporting document 3]

**Related Cards/Issues:**
- [Card ID]: [Card title/description]
- [Card ID]: [Card title/description]

---

## Success Criteria

This spike is complete when:

- [ ] All decision checkboxes checked
- [ ] All decision tables filled with validated input
- [ ] Stakeholder agreement/sign-off obtained
- [ ] Decisions documented in appropriate location
- [ ] Next steps identified with owners and timelines
- [ ] No blocking questions remain unresolved
