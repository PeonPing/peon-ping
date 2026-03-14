---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the process of diagnosing and fixing UI bugs, covering visual design, interaction patterns, accessibility, and information architecture concerns.
use_case: Use this for UI-related bugs that require investigation across design systems, user flows, accessibility compliance, and frontend code implementation.
patterns_used:
  - section: "Overview & Bug Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "UI Investigation Areas"
    pattern: "Pattern 2: Structured Review (e.g., Doc Review)"
  - section: "Implementation Workflow"
    pattern: "Pattern 4: Process Workflow (e.g., TDD Fix)"
  - section: "Visual & Interaction Verification"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# UI Bug Fix Template

**When to use this template:** Use this when fixing bugs related to visual design, user interactions, layout issues, accessibility problems, or information architecture concerns in the user interface. This template is designed for bugs that require cross-functional review (design + code + UX).

**When NOT to use this template:** Do not use this for backend bugs, API issues, or performance problems that don't affect the UI directly. For non-UI bugs, use the standard bug template. For new UI features, use the feature-ui template.

---

## Overview & Bug Context

* **Issue Ticket:** [Link to bug report, e.g., JIRA-123 or GitHub Issue #456]
* **Affected Component/Page:** [e.g., "Login form", "Dashboard navigation", "Product card grid"]
* **Reported Environment:** [e.g., "Chrome 120 on Windows 11", "Safari iOS 17", "All browsers"]
* **User Impact:** [e.g., "Critical - users cannot complete checkout", "Medium - confusing navigation"]

**Required Checks:**
* [ ] **Issue Ticket** link is included above.
* [ ] **Affected Component/Page** is identified.
* [ ] **User Impact** severity is assessed.

---

## UI Investigation Areas

Review all relevant UI aspects before implementing a fix. This ensures the solution addresses root causes, not just symptoms.

### Visual Design Review
* [ ] **Design System/Style Guide** reviewed for correct usage.
* [ ] **Figma/Sketch Designs** reviewed (if available).
* [ ] **Brand Guidelines** reviewed for colors, typography, spacing.

### Code & Implementation Review
* [ ] **Component Source Code** reviewed (identify file paths below).
* [ ] **CSS/Styling Layer** reviewed (global styles, component styles, utility classes).
* [ ] **Responsive Breakpoints** reviewed (mobile, tablet, desktop).

### Accessibility Review
* [ ] **WCAG Guidelines** reviewed for relevant criteria (AA minimum).
* [ ] **Screen Reader Testing** planned or completed.
* [ ] **Keyboard Navigation** tested for affected component.
* [ ] **Color Contrast** verified (use contrast checker tool).

### Information Architecture Review
* [ ] **User Flow Diagram** reviewed (if available).
* [ ] **Navigation Hierarchy** reviewed for logical placement.
* [ ] **Labeling & Microcopy** reviewed for clarity.

### Investigation Findings Table

Use this table to document findings from each review area. Add rows as needed.

| Review Area | File/Doc Location | Finding / Issue Identified | Action Required |
| :--- | :--- | :--- | :--- |
| **Design System** | [Link to docs] | [e.g., "Button component should use 'primary' variant, not custom styles"] | [e.g., "Replace inline styles with design token"] |
| **Component Code** | [e.g., `src/components/LoginForm.tsx`] | [e.g., "Missing error state handling"] | [e.g., "Add error boundary and error UI"] |
| **CSS/Styling** | [e.g., `styles/global.css`] | [e.g., "Z-index conflict with modal overlay"] | [e.g., "Update z-index scale in design tokens"] |
| **Responsive** | [e.g., Breakpoint: 768px] | [e.g., "Grid breaks on tablet view"] | [e.g., "Add tablet-specific grid template"] |
| **Accessibility** | [WCAG 2.1 AA] | [e.g., "Insufficient color contrast (3:1, needs 4.5:1)"] | [e.g., "Update button color to meet AA standard"] |
| **Keyboard Nav** | [Component: Modal] | [e.g., "Focus trap not working, can tab outside modal"] | [e.g., "Implement focus-trap-react library"] |
| **Screen Reader** | [NVDA testing] | [e.g., "Form field missing aria-label"] | [e.g., "Add descriptive aria-label to input"] |
| **User Flow** | [Link to flow diagram] | [e.g., "Back button leads to wrong page in checkout flow"] | [e.g., "Fix routing logic in navigation hook"] |
| **Microcopy** | [e.g., Error message text] | [e.g., "Error message too technical for users"] | [e.g., "Rewrite error message in plain language"] |
| **New Finding** | [Location] | [Issue...] | [Action...] |

---

## Implementation Workflow

Follow this workflow to ensure the fix is properly tested and doesn't introduce regressions.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Visual Regression Test** | [e.g., Link to Percy/Chromatic baseline or Manual screenshots] | - [ ] Baseline screenshots captured for affected component. |
| **2. Write Failing Test** | [e.g., Link to test file: `LoginForm.test.tsx`] | - [ ] Test reproduces the bug (fails before fix). |
| **3. Implement Code Fix** | [e.g., Files changed: `LoginForm.tsx`, `button.module.css`] | - [ ] Code changes committed. |
| **4. Verify Test Passes** | [e.g., Test run: All tests green] | - [ ] The failing test now passes. |
| **5. Cross-Browser Testing** | [e.g., Tested: Chrome, Firefox, Safari, Edge] | - [ ] Bug is fixed in all target browsers. |
| **6. Accessibility Testing** | [e.g., Tested with: NVDA, VoiceOver, keyboard only] | - [ ] Accessibility compliance verified. |
| **7. Responsive Testing** | [e.g., Tested: Mobile (375px), Tablet (768px), Desktop (1440px)] | - [ ] Fix works across all breakpoints. |
| **8. Visual Regression Check** | [e.g., Percy diff reviewed, no unintended changes] | - [ ] No visual regressions introduced. |

### Implementation Notes

> **Code Changes Summary:**
> [Briefly describe what was changed and why. Include component names, file paths, and reasoning.]

> **Design Decisions:**
> [Document any design decisions made during implementation, especially if deviating from original mockups.]

---

## Visual & Interaction Verification

### Testing Evidence

| Test Type | Evidence/Link | Status |
| :--- | :--- | :--- |
| **Visual Regression** | [Link to Percy/Chromatic report] | [e.g., Approved] |
| **Manual Testing** | [Screenshots in: `docs/testing/bug-ui-fix-screenshots/`] | [e.g., Complete] |
| **Accessibility Audit** | [axe DevTools report or manual checklist] | [e.g., 0 violations] |
| **Cross-Browser Test** | [BrowserStack session or manual test log] | [e.g., All browsers pass] |
| **Code Review** | [Link to PR] | [e.g., Approved by @designer, @frontend-lead] |

### Before/After Comparison

> **Before Fix:**
> [Screenshot or GIF showing the bug]

> **After Fix:**
> [Screenshot or GIF showing the corrected behavior]

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Design System Update Needed?** | [e.g., Yes - document new error state pattern] |
| **Accessibility Gaps Identified?** | [e.g., Yes - audit entire form component library] |
| **Documentation Update?** | [e.g., Update component README with new props] |
| **Further Investigation?** | [e.g., No / Yes - check similar components for same issue] |
| **Prevent Recurrence** | [e.g., Add linting rule / Create design QA checklist] |

### Completion Checklist

* [ ] Root cause of UI bug is documented above.
* [ ] Code fix is implemented and tested.
* [ ] All tests pass (unit, integration, visual regression).
* [ ] Accessibility compliance verified (WCAG AA minimum).
* [ ] Cross-browser testing complete (Chrome, Firefox, Safari, Edge).
* [ ] Responsive design verified (mobile, tablet, desktop).
* [ ] Visual regression check passed (no unintended changes).
* [ ] Code review approved by frontend lead and designer.
* [ ] PR merged to main branch.
* [ ] Issue ticket is closed with link to this card.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
