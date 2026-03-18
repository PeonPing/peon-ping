---
# Template Schema Overview
description: A template for gathering user input and clarifying requirements before starting implementation work.
use_case: "Use this before burning tokens on a task - validate assumptions, clarify architecture, and confirm requirements with the user first."
patterns_used:
  - section: "Context Summary"
    pattern: "Pattern 1: Section Header with current understanding"
  - section: "Assumptions to Validate"
    pattern: "Pattern 2: Structured assumption checklist"
  - section: "Questions for User"
    pattern: "Pattern 3: Categorized question blocks"
  - section: "User Responses"
    pattern: "Pattern 4: Response capture log"
  - section: "Decision Record"
    pattern: "Pattern 5: Decision documentation"
---

# User Input Spike

**When to use this template:** When important decisions would benefit from the user's input. Helps with: Being certain about the approach, getting unblocked, and preventing wasted effort from misunderstanding the task.

**When NOT to use this template:** If you don't have any decisions that would benefit from the user's input.

**Examples**: business rules, product requirements, technical decisions, architecture approvals, technology evaluations, ADRs, etc.

---

## Context Summary

**Task Being Planned:** [Brief description of the work you're about to start]

**Related Cards:** [Link to feature/bug/spike cards this supports]

**Current Understanding:**
[Write 2-3 sentences summarizing what you think you're supposed to do. This helps the user spot misunderstandings immediately.]

---

## Assumptions to Validate

List your assumptions that could derail the work if wrong:

| # | Assumption | Confidence | Impact if Wrong |
|---|------------|------------|-----------------|
| 1 | [e.g., "We're using PostgreSQL, not SQLite"] | [High/Medium/Low] | [High/Medium/Low] |
| 2 | [e.g., "This needs to work with the existing auth system"] | [High/Medium/Low] | [High/Medium/Low] |
| 3 | [e.g., "Performance isn't critical for MVP"] | [High/Medium/Low] | [High/Medium/Low] |
| 4 | [e.g., "We can add a new dependency if needed"] | [High/Medium/Low] | [High/Medium/Low] |

---

## Questions for User

### Architecture & Design
Use these for fundamental technical decisions:

**Q1: [Architecture question]**
- Option A: [First approach]
- Option B: [Second approach]
- Option C: [Third approach / "Other - please specify"]

**Q2: [Design pattern question]**
- Option A: [First approach]
- Option B: [Second approach]

### Requirements Clarification
Use these to pin down scope and behavior:

**Q3: [Scope question - what's in/out]**
- [ ] Include [feature A]
- [ ] Include [feature B]
- [ ] Include [feature C]
- [ ] Other: ___________

**Q4: [Behavior question - how should X work]**
[Open-ended question requiring explanation]

### Constraints & Preferences
Use these for non-functional requirements:

**Q5: [Performance/scale question]**
- Option A: [e.g., "Optimize for speed"]
- Option B: [e.g., "Optimize for simplicity"]
- Option C: [e.g., "Balance both"]

**Q6: [Style/convention question]**
[e.g., "Any specific patterns or conventions to follow?"]

---

## Suggested Tool Usage

For AI assistants (Claude Code, etc.), consider using structured input tools:

### AskUserQuestion Pattern
```
Use AskUserQuestion tool with:
- questions: Array of 1-4 questions
- Each question has:
  - question: "The actual question?"
  - header: "Short label" (max 12 chars)
  - options: 2-4 choices with label + description
  - multiSelect: true/false
```

### Example Question Block
```json
{
  "questions": [
    {
      "question": "Which database should we use for this feature?",
      "header": "Database",
      "multiSelect": false,
      "options": [
        {"label": "PostgreSQL", "description": "Existing production database"},
        {"label": "SQLite", "description": "Simpler, file-based for prototyping"},
        {"label": "Redis", "description": "If this is primarily caching"}
      ]
    }
  ]
}
```

---

## User Responses

Record answers as they come in:

| Question | User Response | Timestamp |
|----------|---------------|-----------|
| Q1 | [Answer] | [Date/time] |
| Q2 | [Answer] | [Date/time] |
| Q3 | [Answer] | [Date/time] |

### Assumption Validations
| # | Assumption | Validated? | Correction (if any) |
|---|------------|------------|---------------------|
| 1 | [From above] | [Yes/No/Partial] | [User's correction] |
| 2 | [From above] | [Yes/No/Partial] | [User's correction] |

---

## Decision Record

Summarize the key decisions made:

### Confirmed Decisions
- **Decision 1:** [What was decided and why]
- **Decision 2:** [What was decided and why]

### Out of Scope (Confirmed)
- [Thing explicitly excluded]
- [Another thing excluded]

### Open Items (Need Follow-up)
- [ ] [Item still needing clarification]
- [ ] [Another open item]

---

## Ready to Proceed Checklist

- [ ] All high-impact assumptions validated
- [ ] Critical architecture questions answered
- [ ] Scope boundaries clear (what's in/out)
- [ ] No blocking open items remain
- [ ] User has explicitly approved proceeding

---

## Notes

[Any additional context, edge cases mentioned, or future considerations noted during discussion]
