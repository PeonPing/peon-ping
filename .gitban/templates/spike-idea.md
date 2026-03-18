---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A lightweight template for capturing ideas in the moment, from quick thoughts to partially-formed concepts that need exploration. Flexible structure supports ideas of any size or topic without heavy process overhead.
use_case: Use this for capturing spontaneous ideas, quick thoughts, brainstorming, or partially-formed concepts that need exploration. Perfect for lightweight idea capture that can evolve into more structured work later. Works for any topic - features, improvements, research questions, or experiments.
patterns_used:
  - section: "Idea Capture"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Initial Thoughts & Context"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Idea Development (optional)"
    pattern: "Pattern 3: Iterative Log"
  - section: "Idea Conclusion"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Idea Capture Template

**When to use this template:** Use this for capturing quick ideas, spontaneous thoughts, brainstorming sessions, or partially-formed concepts that need exploration. Perfect for lightweight idea capture without heavy process overhead. Works for any topic, any size - from small tweaks to big visions.

**When NOT to use this template:** Do not use this for committed work that needs structured execution (use feature/bug/refactor templates), formal research with specific questions (use spike templates), or work that's ready for implementation. This is for idea capture and exploration only.

---

## Idea Capture

* **Idea Title:** [Short, catchy description of the idea, e.g., "Add dark mode", "Use WebAssembly for performance", "Simplify onboarding flow"]
* **Topic/Area:** [What domain, e.g., "UI/UX", "Performance", "Developer experience", "Infrastructure", "Product feature", "Process improvement"]
* **Idea Size:** [Gut feeling, e.g., "Small - few hours", "Medium - few days", "Large - few weeks", "Unknown - needs exploration"]
* **Urgency:** [How pressing, e.g., "Just an idea", "Would be nice", "Should explore soon", "Urgent - blocking something"]
* **Trigger/Context:** [What prompted this idea, e.g., "Customer asked about it", "Saw it in competitor product", "Read blog post", "Random shower thought"]
* **Related Work:** [Links if any, e.g., "Similar to FEATURE-123", "Related to customer feedback FEEDBACK-456", "N/A - brand new thought"]

**Required Checks:**
* [ ] **Idea title** captures the core concept in one sentence.
* [ ] **Topic/area** identifies the domain (helps routing to right people).

---

## Initial Thoughts & Context

> Use this space to brain-dump the idea. No structure required - just capture what's in your head. You can refine later.

**The Core Idea:**
* [e.g., "What if we added a dark mode toggle to the settings? Lots of users have requested it."]
* [e.g., "I wonder if we could use WebAssembly for the image processing - might be way faster than JavaScript."]
* [e.g., "Our onboarding flow has 7 steps. What if we collapsed it to 3? Less overwhelming for new users."]
* [e.g., "Random thought: what if deployments were triggered by git tags instead of manual button clicks?"]

**Why This Might Be Valuable:**
* [e.g., "User feedback: 10 customers asked for dark mode in past month"]
* [e.g., "Performance problem: image processing takes 5s, blocking user workflow"]
* [e.g., "Conversion data: 40% of users abandon onboarding at step 4"]
* [e.g., "Developer pain: manual deployments are error-prone and slow"]

**Initial Questions / Unknowns:**
* [e.g., "Question: How hard is dark mode to implement? Never done it before."]
* [e.g., "Unknown: Does our browser support even support WebAssembly? Need to check."]
* [e.g., "Question: What happens if we remove step 4? Does that break anything?"]
* [e.g., "Unknown: Can GitHub Actions trigger on git tags? Need to research."]

**Potential Downsides / Risks:**
* [e.g., "Risk: Dark mode might be a lot of work - every component needs updating"]
* [e.g., "Risk: WebAssembly might not be worth it if only 10% performance gain"]
* [e.g., "Risk: Collapsing onboarding might hide important setup steps"]
* [e.g., "Risk: Git tag deployments might be confusing for non-technical team members"]

**First Steps (If I Were to Pursue This):**
* [e.g., "Step 1: Research dark mode implementation patterns (React docs, blog posts)"]
* [e.g., "Step 1: Benchmark current image processing performance (establish baseline)"]
* [e.g., "Step 1: Review analytics for onboarding drop-off points (validate assumption)"]
* [e.g., "Step 1: Spike git tag deployment with GitHub Actions (1 hour timebox)"]

**Related Ideas / Alternatives:**
* [e.g., "Alternative: Instead of full dark mode, just offer high contrast theme (easier)"]
* [e.g., "Alternative: Instead of WebAssembly, use Web Workers (simpler)"]
* [e.g., "Alternative: Keep 7 steps but add progress bar so users see end is near"]
* [e.g., "Related idea: Also automate rollback if deployment fails (not just trigger)"]

---

## Idea Development (optional)

If you start exploring the idea, use this section to track your investigation. This is optional - only fill in if you actually start working on it.

| Exploration # | Goal / Experiment | Action Taken | Finding / Learning |
| :---: | :--- | :--- | :--- |
| **1** | [e.g., "Validate interest: check customer feedback for dark mode requests"] | [e.g., "Searched support tickets, Slack, surveys"] | [e.g., "Finding: 15 requests in 3 months, mostly from power users"] |
| **2** | [e.g., "Research feasibility: how hard is dark mode?"] | [e.g., "Read React docs, checked design system support"] | [e.g., "Learning: CSS custom properties make it easy, ~2 days work"] |
| **3** | [Goal...] | [Action...] | [Finding...] |

---

#### Exploration 1: [Exploration Summary, e.g., "Customer Interest Validation"]

**Goal / Experiment:** [e.g., "Validate that customers actually want dark mode - don't build something nobody asked for"]

**Action Taken:** [e.g., "Searched support tickets for 'dark mode', checked Slack #feedback channel, reviewed Q4 user survey results"]

**Finding / Learning:** [e.g., "Finding: 15 support tickets requesting dark mode in past 3 months, mostly from power users who spend 4+ hours/day in app. Q4 survey: dark mode was #3 requested feature (125 votes). Clear demand exists."]

---

#### Exploration 2: [Exploration Summary, e.g., "Technical Feasibility Research"]

**Goal / Experiment:** [e.g., "Figure out if dark mode is technically feasible and estimate effort"]

**Action Taken:** [e.g., "Read React dark mode docs, checked if design system supports theming, reviewed component library for theme-able components"]

**Finding / Learning:** [e.g., "Learning: Our design system uses CSS custom properties (great for theming). ~80% of components already theme-ready. Estimate: 2 days to implement toggle + update remaining 20% of components. Feasible!"]

---

## Idea Conclusion

| Task | Detail/Link |
| :--- | :--- |
| **Decision** | [e.g., "Pursue - creating feature card FEATURE-789", "Defer - not enough value", "Spike first - need more research", "Abandon - too risky"] |
| **Next Steps** | [e.g., "Created FEATURE-789 to implement dark mode", "Scheduled spike for Q2", "Documented in ideas backlog", "No action - closing"] |
| **Artifacts Created** | [e.g., "Design mockup in Figma", "PoC branch: feature/dark-mode-poc", "Research doc: docs/research/dark-mode.md", "None - just notes"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Outcome?** | [e.g., "Pursued - implemented in Sprint 25", "Deferred to Q2 backlog", "Abandoned - not valuable", "Still exploring"] |
| **Value Delivered?** | [e.g., "Yes - 20% of users enabled dark mode in first week", "N/A - deferred", "N/A - abandoned"] |
| **Lessons Learned?** | [e.g., "Good practice: validated customer interest before building", "Learning: quick spikes are valuable for feasibility"] |
| **Similar Ideas?** | [e.g., "Yes - created IDEA-890 for high contrast theme", "No - one-off idea"] |

### Completion Checklist

* [ ] Core idea is captured (even if just rough notes).
* [ ] Initial thoughts and questions are documented.
* [ ] Decision made: pursue, defer, spike first, or abandon.
* [ ] Next steps documented (follow-up card created or logged in backlog).
* [ ] If pursued: implementation tracked in proper card (feature/bug/etc).
* [ ] If deferred/abandoned: reason documented for future reference.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
