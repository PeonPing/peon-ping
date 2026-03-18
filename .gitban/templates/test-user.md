---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for planning, executing, and analyzing user testing sessions to validate features, workflows, or system capabilities through real user interaction. Enforces structured test planning, observation protocols, and actionable findings.
use_case: Use this for any user testing spike where you need to validate user experience, discover usability issues, or gather qualitative feedback through structured observation of real users interacting with your product, feature, or system. Flexible enough to test individual features, complete workflows, or system integrations.
patterns_used:
  - section: "User Testing Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Test Planning & Preparation"
    pattern: "Pattern 2: Structured Review"
  - section: "Test Scenarios & Tasks"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "User Testing Sessions Log"
    pattern: "Pattern 3: Iterative Log"
  - section: "Findings & Recommendations"
    pattern: "Pattern 5: Closeout & Follow-up (with Pattern 8 nested)"
---

# User Testing Spike Template

**When to use this template:** Use this for planning and executing user testing sessions to validate features, workflows, or system capabilities through real user interaction and observation.

**When NOT to use this template:** Do not use this for automated testing (use test templates), load testing (use performance templates), or security testing (use security audit templates). This is specifically for qualitative user experience testing with real users.

---

## User Testing Overview

* **Testing Focus:** [What's being tested, e.g., "New checkout flow", "Dashboard redesign", "Search functionality", "Mobile navigation", "Onboarding workflow"]
* **Testing Type:** [Type of test, e.g., "Usability testing", "Feature validation", "Workflow validation", "Integration testing with users", "Exploratory testing"]
* **Target Users:** [Who will test, e.g., "3 new users", "2 experienced users", "5 potential customers", "Internal team members", "External beta testers"]
* **Testing Goals:** [Primary objectives, e.g., "Validate workflow is intuitive", "Identify friction points", "Confirm feature meets user needs", "Discover usability issues"]
* **Success Criteria:** [What defines success, e.g., "Users complete all tasks without help", "Less than 2 usability issues per task", "Users rate experience 4/5 or higher"]
* **Duration:** [Time commitment, e.g., "30 min per user", "1 hour per session", "2 days total for all sessions"]
* **Related Work:** [Links, e.g., "Feature FEATURE-123", "Design mockups in Figma", "Previous testing results SPIKE-456"]

**Required Checks:**
* [ ] **Testing focus** is clearly defined and scoped.
* [ ] **Target users** are identified and recruited.
* [ ] **Success criteria** are measurable and specific.

---

## Test Planning & Preparation

Before conducting user testing, prepare test materials, scenarios, and logistics.

* [ ] Test scenarios defined (specific tasks users will perform).
* [ ] Test environment prepared (tools, accounts, data seeded).
* [ ] Test script/guide created (facilitator instructions, questions to ask).
* [ ] Observation protocol defined (what to observe, how to record).
* [ ] User recruitment completed (participants confirmed, scheduled).
* [ ] Consent forms prepared (if recording sessions or collecting data).
* [ ] Testing tools ready (screen recording, note-taking, feedback forms).

Use the table below to document test preparation status. Add rows as needed.

| Preparation Item | Status / Link | Notes |
| :--- | :--- | :--- |
| **Test Scenarios** | [e.g., "5 scenarios defined - see below"] | [e.g., "Scenarios cover key user journeys and workflows"] |
| **Test Environment** | [e.g., "Staging environment with test data seeded"] | [e.g., "Users will have their own test accounts"] |
| **Test Script** | [e.g., "Script in docs/testing/user-test-script.md"] | [e.g., "Includes intro, tasks, debrief questions"] |
| **Observation Protocol** | [e.g., "Recording clicks, time on task, verbal feedback"] | [e.g., "Using screen recording + facilitator notes"] |
| **User Recruitment** | [e.g., "3 users recruited, sessions scheduled Mon-Wed"] | [e.g., "Alice (new user), Bob (experienced), Carol (power user)"] |
| **Consent Forms** | [e.g., "Consent forms signed by all participants"] | [e.g., "Recording permission granted"] |
| **Testing Tools** | [e.g., "Zoom for recording, Google Forms for feedback"] | [e.g., "Test accounts created: test1@example.com, test2@example.com"] |

---

## Test Scenarios & Tasks

Define the specific scenarios and tasks users will perform during testing. Each scenario should have clear success criteria.

| Scenario # | Scenario Description | Tasks to Complete | Success Criteria | Status |
| :---: | :--- | :--- | :--- | :---: |
| **1** | [e.g., "Complete checkout purchase"] | [e.g., "1. Add item to cart, 2. Enter shipping info, 3. Complete payment"] | [e.g., "Purchase completed successfully in under 3 minutes, no errors"] | - [ ] Tested |
| **2** | [e.g., "Search and filter results"] | [e.g., "1. Enter search term, 2. Apply filters, 3. Sort results"] | [e.g., "User finds desired item within 1 minute, filters work as expected"] | - [ ] Tested |
| **3** | [e.g., "Navigate mobile menu"] | [e.g., "1. Open menu, 2. Find category, 3. Navigate to page"] | [e.g., "User completes navigation without confusion, menu is intuitive"] | - [ ] Tested |
| **4** | [e.g., "Complete onboarding"] | [e.g., "1. Create account, 2. Set preferences, 3. Complete tutorial"] | [e.g., "User completes onboarding, understands key features"] | - [ ] Tested |
| **5** | [Scenario...] | [Tasks...] | [Success criteria...] | - [ ] Tested |

---

## User Testing Sessions Log

| Session # | User / Profile | Scenario Tested | Observations / Issues | Outcome |
| :---: | :--- | :--- | :--- | :--- |
| **1** | [e.g., "Alice - new user, first time using product"] | [e.g., "Scenario 1: Complete checkout"] | [e.g., "Confused by shipping options, took 5 min vs expected 3 min"] | [e.g., "Completed but struggled - needs clearer labels"] |
| **2** | [e.g., "Bob - experienced user, uses product daily"] | [e.g., "Scenario 2: Search and filter"] | [e.g., "Smooth workflow, completed in 30 seconds, no issues"] | [e.g., "Success - workflow is intuitive for experienced users"] |
| **3** | [User...] | [Scenario...] | [Observations...] | [Outcome...] |

---

#### Session 1: [Session Summary, e.g., "Alice - New User Testing Checkout Flow"]

**User Profile:** [e.g., "Alice - 28 years old, shops online weekly, first time using this site. Comfortable with technology but not a power user."]

**Scenario Tested:** [e.g., "Scenario 1: Complete checkout purchase"]

**Observations:**
* [e.g., "User successfully added item to cart in 10 seconds"]
* [e.g., "User confused by shipping options - spent 2 minutes reading options"]
* [e.g., "User asked: 'What's the difference between standard and express shipping?'"]
* [e.g., "Payment form was intuitive - no issues entering card details"]
* [e.g., "User successfully completed purchase but wasn't sure if it worked (no confirmation page shown immediately)"]
* [e.g., "Total time: 5 minutes (expected: 3 minutes)"]

**Issues Identified:**
* [e.g., "ISSUE-1: Shipping options lack clear descriptions - users need better labels"]
* [e.g., "ISSUE-2: No immediate confirmation after payment - users uncertain if purchase worked"]
* [e.g., "ISSUE-3: Estimated delivery dates not shown for shipping options"]

**Outcome:** [e.g., "Partial success - user completed purchase but took 60% longer than expected. Identified 3 usability issues that need addressing."]

---

#### Session 2: [Session Summary, e.g., "Bob - Experienced User Testing Search"]

**User Profile:** [e.g., "Bob - 35 years old, power user of e-commerce sites, shops online daily. Very comfortable with technology and expects fast, efficient workflows."]

**Scenario Tested:** [e.g., "Scenario 2: Search and filter results"]

**Observations:**
* [e.g., "User immediately went to search bar (discoverable)"]
* [e.g., "Search results appeared quickly - under 1 second"]
* [e.g., "User applied multiple filters confidently"]
* [e.g., "User completed task in 30 seconds (expected: 1 minute)"]
* [e.g., "User commented: 'This is really fast compared to other sites'"]
* [e.g., "No confusion, no questions asked"]

**Issues Identified:**
* [e.g., "No issues identified - search workflow is smooth for experienced users"]

**Outcome:** [e.g., "Success - experienced users find search intuitive and efficient. No changes needed for core functionality."]

---

#### Session 3: [Session Summary]

**User Profile:** [Profile description...]

**Scenario Tested:** [Scenario tested...]

**Observations:**
* [Observation 1...]
* [Observation 2...]

**Issues Identified:**
* [Issue 1...]

**Outcome:** [Outcome summary...]

*(Copy and paste the 'Session N' block above for each testing session.)*

---

## Findings & Recommendations

| Task | Detail/Link |
| :--- | :--- |
| **Test Sessions Completed** | [e.g., "3 sessions completed (Alice, Bob, Carol)"] |
| **Scenarios Tested** | [e.g., "5 scenarios tested across all users"] |
| **Issues Identified** | [e.g., "7 usability issues, 2 bugs, 3 enhancement requests"] |
| **Video Recordings** | [e.g., "Link to session recordings: drive.google.com/..."] |
| **User Feedback Forms** | [e.g., "Link to feedback responses: forms.google.com/..."] |
| **Findings Report** | [e.g., "Link to detailed findings doc: docs/testing/findings.md"] |

### Final Synthesis & Recommendation

#### Summary of Findings

[Provide a narrative summary of all findings from testing sessions. Example: "User testing revealed that while experienced users find the workflow intuitive and efficient, new users struggle with feature discoverability and lack confirmation feedback. 3 of 3 users completed all tasks successfully, but new users took 60% longer than expected. The primary friction points are: (1) shipping options lack clear descriptions, (2) no confirmation messages after critical actions, (3) advanced features not discoverable for new users. Positive findings: experienced users praised speed and efficiency, search was fast and accurate, checkout flow was smooth once users understood options."]

#### Recommendation

[State clear, actionable recommendations. Example: "We recommend three immediate improvements: (1) Add clear descriptions and estimated delivery dates to shipping options, (2) Add confirmation messages after critical actions (payment, order placement), (3) Add onboarding tooltips for first-time users. These changes address 80% of friction identified in testing. Create feature cards FEATURE-890, FEATURE-891, FEATURE-892 to implement improvements. Schedule follow-up testing in 2 weeks after fixes deployed."]

#### Prioritized Issues

[List issues in priority order with severity. Example:
* **P0 (Critical):** None identified
* **P1 (High):**
  - ISSUE-1: Shipping options lack clear descriptions (affects all new users, causes hesitation)
  - ISSUE-2: No confirmation messages after payment (affects all users, creates uncertainty)
* **P2 (Medium):**
  - ISSUE-3: Estimated delivery dates not shown (workaround: contact support)
  - ISSUE-4: Advanced filters not documented (experienced users discover them)
* **P3 (Low):**
  - ISSUE-5: Enhancement request - save shipping preferences (nice-to-have)
]

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Issues Addressed?** | [e.g., "Created 3 feature cards to address P1 issues: FEATURE-890, FEATURE-891, FEATURE-892"] |
| **Follow-up Testing?** | [e.g., "Scheduled follow-up testing in 2 weeks after fixes deployed"] |
| **Positive Feedback?** | [e.g., "Users praised speed, efficiency, keyboard shortcuts - preserve these strengths"] |
| **Documentation Updates?** | [e.g., "Created new user guide based on testing insights: docs/new-user-guide.md"] |
| **Feature Requests?** | [e.g., "3 enhancement requests logged in backlog: FEATURE-893, FEATURE-894, FEATURE-895"] |
| **Testing Process?** | [e.g., "Lessons learned: recruit more diverse users next time, extend session time to 45 min"] |
| **Metrics Collected?** | [e.g., "Baseline metrics: new user time-to-first-card: 5 min, experienced: 1 min"] |

### Completion Checklist

* [ ] All planned testing sessions completed.
* [ ] All scenarios tested with target users.
* [ ] Observations documented for each session.
* [ ] Issues identified and prioritized by severity.
* [ ] Findings synthesized into narrative summary.
* [ ] Recommendations are clear and actionable.
* [ ] Follow-up feature cards created for issues.
* [ ] Video recordings archived [if applicable].
* [ ] User feedback forms collected and analyzed.
* [ ] Findings report published to team.
* [ ] Positive findings documented (preserve strengths).
* [ ] Follow-up testing scheduled [if needed].
* [ ] Documentation updated based on insights.
* [ ] Metrics collected for future comparison.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
