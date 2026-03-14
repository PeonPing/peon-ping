---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the process of triaging cards using systematic categorization (not validation).
use_case: "Use this for backlog grooming, sprint planning, draft card review, feedback processing, or any scenario requiring systematic card review and categorization."
patterns_used:
  - section: "Overview & Triage Scope"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Triage Log"
    pattern: "Pattern 3: Iterative Log (adapted for card dispositions)"
  - section: "Batch Summary & Metrics"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Card Triage Session: [Triage Scope, e.g., Q4 Backlog Review or Draft Card Cleanup]

**When to use this template:** Use this when you need to systematically review and categorize a batch of cards using triage dispositions (ACT/DONE/STALE/DUPE/REJECT/JUNK). Perfect for backlog grooming, sprint planning, draft card review, or feedback processing sessions.

**When NOT to use this template:** Don't use this for validating card structure, fixing incomplete cards, or moving cards through workflows. Triage is categorization only - if you're trying to validate or fix cards, you're doing something wrong.

## Overview & Triage Scope

* **Triage Context:** [e.g., Sprint Planning for Q1 2025, or Quarterly Backlog Cleanup, or Feedback Import Batch]
* **Card Source:** [e.g., Status: backlog, or Location: draft/, or Tag: FEEDBACK]
* **Target Batch Size:** [e.g., 10 cards (recommended 5-10 for quality decisions)]
* **Time Box:** [e.g., 60 minutes (recommended 60-90 min max)]

**Required Pre-Triage Checks:**
* [ ] Triage framework reviewed (6 dispositions understood).
* [ ] Card list identified using list_cards() or search_cards().
* [ ] Batch size is reasonable (5-10 cards recommended).

## Triage Decision Framework Reference

### Core Principle: Triage = Categorization, NOT Validation

**CRITICAL**: If you're trying to validate or fix cards during triage, you've done something wrong.

**What Triage IS:**
- ✅ Assign dispositions (ACT/DONE/STALE/DUPE/REJECT/JUNK)
- ✅ Add banners to flag human review
- ✅ Adjust priority based on relevance
- ✅ Document rationale for decisions

**What Triage is NOT:**
- ❌ Validating card structure against templates
- ❌ Fixing incomplete content or adding missing sections
- ❌ Moving cards through validation workflows
- ❌ Completing work that cards describe

### Decision Rule

Choose the FIRST matching disposition (top to bottom):
- **Be THOROUGH for DONE/DUPE** - These require verification (git search, PRs, search_cards tool)
- **Trust instincts for ACT/STALE/REJECT/JUNK** - These are judgment calls, decide quickly

### 6 Dispositions with Anti-Patterns

| Disposition | When to Use | Example Triggers | ⚠️ CRITICAL ANTI-PATTERNS |
|:------------|:------------|:-----------------|:-------------------------|
| **ACT** | Any intentional work (even unclear/small/questionable) | Feature idea, bug report, chore note, "update that docstring", rough sketch | **NEVER** skip ACT because work seems "too small" or card is incomplete. If it's intentional (not stale/dupe/junk), it's ACT |
| **DONE** | Work already completed | "This was implemented in v2.1", "Bug fixed by PR #456" | **MUST** verify work is done, then move to backlog with "VERIFY AND CLOSE" banner. NEVER archive without verification |
| **STALE** | No longer relevant (context changed) | Architecture made obsolete, >6mo inactive AND requirements shifted, market pivot | **FORBIDDEN** for valid work that's incomplete or unclear. Context must have changed, not card quality. Use ACT + backlog instead |
| **DUPE** | Duplicate of existing card | Same issue/feature already tracked elsewhere | **MUST** cite duplicate card ID. If unsure, use ACT + backlog with "VERIFY DUPLICATE" banner |
| **REJECT** | Explicit decision not to do | Against product principles, technically infeasible, team said "no" | Requires explicit team decision. Document who decided and when. Not for "seems like a bad idea" - use ACT + P2 |
| **JUNK** | No intentional content | Test cards, spam, empty, truly unintelligible | ONLY for cards with zero intentional work. "Bad idea" ≠ junk. Incomplete ≠ junk. Use ACT instead |

### Critical Safeguards Against Lazy Archival

**The Lazy Archival Anti-Pattern:** Archiving valid features because validation is "too hard" or content is "incomplete" is FORBIDDEN.

**MANDATORY Verification Before Archive:**

**1. DONE Disposition:**
- ✅ REQUIRED: Verify work is actually complete (check PRs, commits, code, docs, deployed features)
- ✅ REQUIRED: Take time to be thorough - search git history, check issue trackers, ask teammates
- ✅ IF VERIFIED: Move card to backlog status with banner: `## COMPLETED: [Brief summary]. Verified on [date].`
- ✅ IF UNCERTAIN: Keep in current location with banner: `## POSSIBLY DONE: [What you found]. Needs verification before archiving.`
- ❌ NEVER: Archive without thorough verification

**2. STALE Disposition:**
- ✅ VALID: Architecture made feature obsolete (cite new design)
- ✅ VALID: Market/strategy shift made feature irrelevant (cite business decision)
- ✅ VALID: >6mo inactive AND requirements changed significantly
- ❌ FORBIDDEN: "Content is incomplete" - incomplete ≠ stale. Use ACT + backlog
- ❌ FORBIDDEN: "Card structure is unclear" - structure ≠ relevance. Use ACT + backlog
- ❌ FORBIDDEN: "I don't understand this" - then don't triage it, let someone else handle it

**3. DUPE Disposition:**
- ✅ REQUIRED: Search for similar cards (use search_cards tool, check titles, read content)
- ✅ REQUIRED: Cite specific duplicate card ID
- ✅ REQUIRED: Verify the "duplicate" actually covers the same scope (not just similar wording)
- ❌ NEVER: Assume similarity = duplicate. Features can have overlapping descriptions but different scope
- ❌ IF UNSURE: Keep in current location with banner: `## POSSIBLE DUPLICATE: May be duplicate of [card_id]. Verify before working.`

**4. ACT Cards That Need Work:**
- ❌ NEVER ARCHIVE: Cards with incomplete content
- ❌ NEVER ARCHIVE: Cards that need "more work" or clarification
- ❌ NEVER ARCHIVE: P2 cards that seem low priority
- ❌ NEVER TRY TO FIX: Triage categorizes, it doesn't validate or complete cards
- ✅ CORRECT ACTION: Leave in current location (draft/ or main/)
- ✅ CORRECT ACTION: Downgrade priority if needed (P1 → P2)
- ✅ CORRECT ACTION: Add banner at the very top of card content:
  ```markdown
  ⚠️ **TRIAGED: Intentional work, needs refinement**

  This card represents intentional work worth doing. It may need more detail, clarification, or structure before being worked on.

  **Priority:** [P0/P1/P2] | **Triage Date:** [date]

  ---

  [existing card content follows...]
  ```

### Decision Tree (Use This for Every Card)

```
Is there intentional work here? (not spam/test/empty)
├─ YES → Check for duplicates (search similar titles/content)
│  ├─ DUPLICATE FOUND (verified) → Archive as DUPE
│  ├─ NO DUPLICATE → Check if work is already done (search git, PRs, features)
│  │  ├─ DONE (verified thoroughly) → Move to backlog + "COMPLETED" banner → archive later
│  │  ├─ POSSIBLY DONE (uncertain) → Keep in place + "POSSIBLY DONE" banner
│  │  └─ NOT DONE → Check if still relevant (architecture/market context)
│  │     ├─ RELEVANT → ACT disposition
│  │     │              Leave in current location (draft/ or main/)
│  │     │              Add "TRIAGED" banner at top
│  │     │              Downgrade priority if needed (P1→P2)
│  │     └─ NO LONGER RELEVANT → Archive as STALE (cite specific reason)
│  └─ UNSURE IF DUPLICATE → Keep in place + "POSSIBLE DUPLICATE" banner
└─ NO (spam/test/empty) → Archive as JUNK
```

### Understanding Card Locations

- **draft/ folder** = Cards that haven't been structured yet (someone needs to flesh them out)
- **main/ cards with backlog status** = Structured cards, low priority
- **Banners** signal "triaged" vs "untouched" - shows human reviewed it
- **Low priority doesn't mean no value** - someone may work on it when they have time
- **Archiving intentional work LOSES that work permanently**
- **Backlog is EXPECTED to have many P2s and downgraded P1s**

### Performance Guidelines

- **DON'T** fix, validate, or complete cards during triage (wrong phase)
- **DO** categorize (ACT/DONE/STALE/DUPE/REJECT/JUNK) and add banners
- **Content improvement happens later** when someone picks up the card
- **Exception: BE THOROUGH** checking for DONE and DUPE - these require research to verify

## Triage Log

| Card ID | Disposition | Rationale | Action Taken |
| :---: | :--- | :--- | :--- |
| **[e.g., F0123]** | [ACT/DONE/STALE/DUPE/REJECT/JUNK] | [e.g., Valid feature idea, aligns with roadmap but needs refinement.] | [e.g., Banner added, priority P1→P2, left in backlog] |
| **[e.g., B0456]** | [Disposition...] | [Rationale...] | [Action...] |

---
#### Card 1: [Card ID] - [Card Title]

**Disposition:** [ACT / DONE / STALE / DUPE / REJECT / JUNK]

**Rationale:** [1-2 sentence explanation of why this disposition was chosen. For DONE, cite verification evidence. For DUPE, cite duplicate card ID.]

**Action Taken:**
- [e.g., Added banner: "TRIAGED: Intentional work, needs refinement"]
- [e.g., Priority adjusted: P1 → P2]
- [e.g., Location: Remained in backlog status]
- [e.g., Archived to: 2025-Q4-triage sprint]
- [e.g., Verification: Checked git history, found PR #456, confirmed completed in v2.1.0]
- [e.g., Search results: Used search_cards("authentication"), found duplicate in F0789]

**RICE/ICE Score (if ACT):** [e.g., RICE: 850 or ICE: 7.5 or N/A]

---

*(Copy and paste the 'Card N' block above for each card in your triage batch.)*

## Batch Summary & Metrics

### Disposition Distribution

| Disposition | Count | Percentage | Notes |
| :--- | :---: | :---: | :--- |
| **ACT** | [e.g., 5] | [e.g., 50%] | [e.g., Mostly valid feature ideas needing work] |
| **DONE** | [e.g., 2] | [e.g., 20%] | [e.g., All verified via git history] |
| **STALE** | [e.g., 1] | [e.g., 10%] | [e.g., Architecture change made obsolete] |
| **DUPE** | [e.g., 1] | [e.g., 10%] | [e.g., Verified duplicate with search] |
| **REJECT** | [e.g., 1] | [e.g., 10%] | [e.g., Team decision documented] |
| **JUNK** | [e.g., 0] | [e.g., 0%] | [e.g., No test/spam cards in this batch] |
| **Total** | [e.g., 10] | 100% | |

### Archive Actions

| Archive Sprint Name | Card IDs Archived | Dispositions |
| :--- | :--- | :--- |
| [e.g., 2025-Q4-triage] | [e.g., F0123, B0456, C0789] | [e.g., DONE (1), STALE (1), DUPE (1)] |

**Archive Command Used:**
```python
# Example command for reference
archive_cards(
    archive_name="2025-Q4-triage",
    card_ids=["F0123", "B0456", "C0789"]
)
```

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **ACT Cards Requiring Work** | [e.g., 5 cards flagged with banners, remain in backlog for future work] |
| **Verification Quality** | [e.g., All DONE dispositions verified via git/PRs, no assumptions made] |
| **Duplicate Detection** | [e.g., Used search_cards effectively, found 1 true duplicate] |
| **Time Performance** | [e.g., 60 minutes for 10 cards = 6 min/card (within target)] |
| **Future Improvements** | [e.g., Consider automated staleness detection for >6mo cards] |

### Completion Checklist

* [ ] All cards in batch have been reviewed and assigned dispositions.
* [ ] DONE dispositions were thoroughly verified (git search, PR check, teammate confirmation).
* [ ] DUPE dispositions include cited duplicate card IDs (search_cards used).
* [ ] ACT cards have banners added and priorities adjusted as needed.
* [ ] Archive batch created for DONE/STALE/DUPE/REJECT cards (if any).
* [ ] No cards were archived with ACT disposition (ACT cards remain in place).
* [ ] Triage metrics recorded in summary table above.
* [ ] Follow-up actions documented.
* [ ] Time performance is within target (60-90 min for 5-10 cards).

=== MANDATORY CARD FOOTER ===
### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carefully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
