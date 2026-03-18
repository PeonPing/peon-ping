---
# Template Schema Overview
description: A template for planning and setting up a design sprint in gitban using batch card creation, design methodology, and research planning. Focuses on setup and preparation, not day-to-day execution. Note that this card is not for actually doing all the work, it's for setting up the sprint so that the work is done amazingly well.
use_case: Use this when starting a design sprint to create card stubs, plan research activities, identify design deliverables, and set up sprint infrastructure. Focus on planning the design work, not tracking daily progress.
patterns_used:
  - section: "Design Sprint Definition & Scope"
    pattern: "Pattern 1: Section Header"
  - section: "Design Problem & Questions"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Batch Card Creation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Design Sprint Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Sprint Closeout & Synthesis"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Design Sprint Setup Template

## Design Sprint Definition & Scope

* **Sprint Name/Tag**: [e.g., "UX", "ARCHDESIGN", "APIDESIGN" - used as filename prefix]
* **Design Goal**: [What design question or problem are we solving?]
* **Timeline**: [Start date - End date, e.g., "2025-11-18 - 2025-12-01"]
* **Stakeholders**: [Who needs to be involved? Product, engineering, users?]
* **Success Criteria**: [Sprint complete when X design artifacts ready, decision made, validation done]

**Required Checks:**
* [ ] Sprint name/tag is chosen and will be used as prefix for all cards
* [ ] Design goal clearly articulates the problem space
* [ ] Stakeholders identified and available
* [ ] Success criteria define what "done" looks like

---

## Design Problem & Questions

> Use this space to brainstorm the design problem, key questions, constraints, and areas of uncertainty. Think about what you need to understand before making design decisions.

### Core Design Problem

[e.g., "Users are confused by our authentication flow. We need to redesign it to be more intuitive while maintaining security."]

### Key Questions to Answer

* [e.g., "What are the most common user pain points in the current flow?"]
* [e.g., "What authentication patterns do users expect based on competitor products?"]
* [e.g., "What are our technical constraints (existing systems, security requirements)?"]
* [e.g., "How do we balance simplicity with security requirements?"]

### Known Constraints

* [e.g., "Must support existing OAuth providers"]
* [e.g., "Cannot require users to re-authenticate existing sessions"]
* [e.g., "Must meet SOC2 compliance requirements"]

### Design Approach Options

* [e.g., "Option 1: Iterative improvement of current design"]
* [e.g., "Option 2: Complete redesign from user research"]
* [e.g., "Option 3: Adopt industry-standard pattern (e.g., Auth0-style)"]

---

## Sequential Card Creation Workflow

Use this workflow to create all design sprint cards using sequential `create_card()` calls.
Sequential creation provides better error handling and is easier for AI agents to work with.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Create Research Spike Cards** | [Record card IDs created] | - [ ] Research spike cards created with sprint tag |
| **2. Create Design Task Cards** | [Record card IDs created] | - [ ] Design task cards created with sprint tag |
| **3. Create Validation/Testing Cards** | [Record card IDs created] | - [ ] Validation cards created with sprint tag |
| **4. Create Documentation Cards** | [Record card IDs created] | - [ ] Documentation cards created with sprint tag |
| **5. Verify Sprint Tags** | [Run list_cards with group_by_sprint] | - [ ] All cards show correct sprint tag |
| **6. Fill Detailed Cards** | [Update high-priority cards with full details] | - [ ] P0/P1 cards have full research questions/design goals |

### Workflow Instructions

**Step 1: Create Research Spike Cards**

Research activities that must happen before design work begins.

```python
# Create research spike cards sequentially
for title in [
    "User research: interview 5-10 users about current auth flow",
    "Competitive analysis: audit 3-5 competitor auth flows",
    "Technical constraints: document existing systems and limitations"
]:
    create_card(
        title,
        card_type="spike",
        priority="P0",
        status="backlog",
        owner="CAMERON",
        sprint="UX"  # Your sprint tag!
    )
```

**Step 2: Create Design Task Cards**

Design activities and deliverables (wireframes, prototypes, mockups, architecture diagrams).

```python
# Create design task cards sequentially
for title in [
    "Create low-fidelity wireframes for new auth flow",
    "Design high-fidelity mockups in Figma",
    "Create interactive prototype for user testing",
    "Document design system components needed"
]:
    create_card(
        title,
        card_type="docs",  # or "feature" if implementing design
        priority="P1",
        status="backlog",
        sprint="UX"
    )
```

**Step 3: Create Validation/Testing Cards**

Activities to validate design decisions with users or stakeholders.

```python
# Create validation cards sequentially
for title in [
    "User testing: run 5 usability tests with prototype",
    "Stakeholder review: present designs to product team",
    "Technical feasibility: validate design with engineering"
]:
    create_card(
        title,
        card_type="spike",
        priority="P1",
        status="backlog",
        sprint="UX"
    )
```

**Step 4: Create Documentation Cards**

Documentation artifacts that capture design decisions and rationale.

```python
# Create documentation cards sequentially
for title in [
    "Write design ADR documenting chosen approach",
    "Create design spec with component breakdown",
    "Update design system documentation"
]:
    create_card(
        title,
        card_type="docs",
        priority="P2",
        status="backlog",
        sprint="UX"
    )
```

**Step 5: Verify Sprint Setup**

```python
# View all cards in this sprint
list_cards(group_by_sprint=True)

# Should show your sprint tag with all created cards
```

**Step 6: Add Details to Ready Cards**

Use `edit_card()` or `append_card()` to flesh out high-priority cards with:
- Specific research questions
- Design deliverable descriptions
- Validation criteria
- Links to related work

**Created Card IDs**: [List all card IDs here for reference: abc123, def456, ...]

---

## Design Sprint Phases

Track the major phases of design sprint execution. This is lightweight - just checkpoint the key gitban operations.

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Research Phase** | [Links to completed research spikes] | - [ ] All research spikes completed |
| **Synthesis & Framing** | [Link to synthesis doc or meeting notes] | - [ ] Research findings synthesized |
| **Ideation & Sketching** | [Link to sketch artifacts] | - [ ] Initial design concepts created |
| **Design Execution** | [Links to Figma/wireframes/prototypes] | - [ ] Design deliverables created |
| **Validation & Testing** | [Links to test results/feedback] | - [ ] Design validated with users/stakeholders |
| **Documentation** | [Links to ADRs/design specs] | - [ ] Design decisions documented |
| **Handoff Planning** | [Link to implementation cards/plan] | - [ ] Implementation plan created |

### Phase Details

#### Take Sprint

**Claim all backlog cards in sprint and assign to yourself:**

```python
take_sprint(sprint_name="UX", owner="CAMERON")
# Moves all backlog cards → todo and assigns owner
```

#### Monitor Progress

**Check sprint progress:**

```python
# View all cards grouped by sprint tag
list_cards(group_by_sprint=True)

# View only active work
list_cards(active_only=True, group_by_sprint=True)

# Get board statistics
get_gitban_stats()
```

**Learn more**: `get_help(topic="tools")` for complete tool reference and filtering options

#### Research Phase

**Focus**: Understand the problem space before designing solutions.

**Activities**:
- User interviews and observation
- Competitive analysis
- Technical constraint documentation
- Stakeholder interviews
- Analytics review

**Deliverables**:
- Research findings summary
- User pain points
- Competitor patterns
- Technical constraints doc

#### Synthesis & Framing

**Focus**: Make sense of research and frame the design problem clearly.

**Activities**:
- Synthesize research findings
- Define design principles
- Create user journey maps
- Identify key design challenges
- Frame "How Might We" questions

**Deliverables**:
- Synthesis doc
- Design principles
- Problem statement
- Key insights

#### Ideation & Sketching

**Focus**: Generate multiple design options before committing.

**Activities**:
- Sketching sessions
- Crazy 8s or similar ideation
- Concept exploration
- Pattern research
- Early prototyping

**Deliverables**:
- Sketch artifacts
- Concept options (3-5 directions)
- Initial wireframes

#### Design Execution

**Focus**: Create detailed design artifacts ready for validation.

**Activities**:
- Wireframe creation
- High-fidelity mockups
- Interactive prototypes
- Design system updates
- Accessibility review

**Deliverables**:
- Figma files
- Interactive prototype
- Design specifications
- Component documentation

#### Validation & Testing

**Focus**: Validate design decisions with users and stakeholders.

**Activities**:
- Usability testing
- Stakeholder reviews
- Technical feasibility validation
- Accessibility testing
- Performance impact assessment

**Deliverables**:
- Test results
- Stakeholder feedback
- Technical validation
- Iteration plan

#### Documentation

**Focus**: Capture design decisions and rationale for future reference.

**Activities**:
- Write design ADRs
- Create design specs
- Document component behavior
- Update design system
- Create handoff docs

**Deliverables**:
- ADRs (Architecture Decision Records)
- Design specifications
- Component documentation
- Implementation guidelines

---

## Sprint Closeout & Synthesis

| Task | Detail/Link |
| :--- | :--- |
| **Cards Archived** | [Link to sprint archive folder] |
| **Sprint Summary** | [Link to SUMMARY.md] |
| **Design Artifacts** | [Links to Figma, prototypes, specs] |
| **Retrospective** | [Date retrospective held] |

### Final Synthesis & Recommendation

#### Summary of Findings

[Provide a narrative summary of the design sprint outcomes. What did you learn? What design direction emerged? What problems did you solve?]

#### Recommendation

[State the clear, actionable recommendation. e.g., "We recommend proceeding with Design Option 2 (simplified 2-step auth flow) based on positive user testing results and technical feasibility validation."]

### Closeout Tools

**Archive completed work:**

```python
# Archive all done cards to sprint folder
archive_cards(
    archive_name="2025-11-UX-Auth-Redesign",
    all_done=True  # or specify card_ids for specific cards
)

# Generate sprint summary with metrics
generate_archive_summary(
    archive_folder_name="sprint-2025-11-ux-auth-redesign-20251118",
    mode="enhanced",
    executive_summary="Completed UX redesign of authentication flow with positive user testing results",
    lessons_learned={
        "what_went_well": [
            "Early user research prevented costly wrong direction",
            "Prototype testing identified critical usability issues before development"
        ],
        "what_could_improve": [
            "Should have involved engineering earlier for technical constraints",
            "Need more time for accessibility review"
        ]
    },
    next_steps=[
        "Create implementation cards for chosen design",
        "Schedule design review with full engineering team",
        "Update design system with new auth components"
    ]
)
```

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Implementation Cards** | [Create feature cards for implementing design] |
| **Incomplete Research** | [Carry over to next sprint or move to backlog] |
| **Design Debt** | [Created follow-up cards for design improvements] |
| **Process Improvements** | [What to improve in next design sprint?] |
| **Dependencies/Blockers** | [What blocked progress? How to prevent?] |

### What Went Well

* [e.g., "User research early in sprint prevented wrong direction"]
* [e.g., "Prototype testing identified critical issues before development"]
* [e.g., "Cross-functional collaboration improved design quality"]

### What Could Be Improved

* [e.g., "Should have involved engineering earlier for technical constraints"]
* [e.g., "Need more time for accessibility review"]
* [e.g., "Stakeholder alignment should happen before design execution"]

### Completion Checklist

* [ ] All research findings documented and synthesized
* [ ] Design artifacts created and reviewed (Figma, prototypes, specs)
* [ ] User validation completed with test results documented
* [ ] Stakeholder sign-off obtained
* [ ] Design decisions documented in ADRs
* [ ] Implementation cards created for next phase
* [ ] All done cards archived to sprint folder
* [ ] Sprint summary generated with lessons learned
* [ ] Retrospective notes captured above
* [ ] Sprint closed and celebrated!

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
