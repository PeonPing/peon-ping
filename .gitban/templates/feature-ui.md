---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the development of UI features with enforced best practices for design review, accessibility, responsive design, component testing, and user experience validation.
use_case: Use this for building new UI components, implementing user-facing features, or modifying existing UI functionality. Ensures proper design review, accessibility compliance, responsive design, visual regression testing, and UX validation.
patterns_used:
  - section: "UI Feature Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Design & UX Review"
    pattern: "Pattern 2: Structured Review"
  - section: "UI Development Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "Component Implementation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "UI Validation & Release"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# UI Feature Development Template

**When to use this template:** Use this for developing new UI components, implementing user-facing features, building interactive elements, or modifying existing UI functionality that requires design review, accessibility compliance, and user experience validation.

**When NOT to use this template:** Do not use this for backend API work (use `feature-api.md`), internal tools without UI (use `feature.md`), or simple styling fixes (use `style-formatting.md`). This template is specifically for user-facing UI development.

---

## UI Feature Overview

* **Feature Description:** [Brief description of the UI feature, e.g., "Add user dashboard with activity timeline", "Implement search results page with filters"]
* **UI Components:** [Main components to build, e.g., "Dashboard card component, Timeline component, Activity feed", "Search bar, Filter panel, Results grid"]
* **User Story:** [From user perspective, e.g., "As a user, I want to see my recent activity so I can track my progress"]
* **Design Reference:** [Link to design artifacts, e.g., "Figma: https://figma.com/file/xyz", "Design spec in docs/design/dashboard.md"]
* **Target Platforms:** [Where this UI will run, e.g., "Web (desktop + mobile)", "Mobile app (iOS + Android)", "Desktop app (Electron)"]
* **Related Work:** [Links to design spike, UX research, ADRs, e.g., "Design spike SPIKE-789", "UX research in DOC-456"]
* **Target Release:** [Release version or date, e.g., "Q1 2025 release", "Sprint 25"]

**Required Checks:**
* [ ] **UI components** to be built are clearly identified.
* [ ] **Design reference** (Figma, mockup, spec) is linked and accessible.
* [ ] **User story** explains the feature from user perspective.

---

## Design & UX Review

Before implementation, review design specifications, accessibility requirements, and ensure the UI follows design system standards.

* [ ] Design mockups/wireframes reviewed (Figma, Sketch, Adobe XD).
* [ ] Design system/component library reviewed for reusable components.
* [ ] Accessibility guidelines reviewed (WCAG 2.1 AA minimum).
* [ ] Responsive design breakpoints reviewed for target devices.
* [ ] Browser compatibility requirements reviewed (Chrome, Firefox, Safari, Edge).
* [ ] Animation/interaction specifications reviewed [if applicable].
* [ ] User flow diagrams reviewed to understand context.

Use the table below to document design decisions and requirements. Add rows as needed.

| Design Aspect | Decision / Requirement | Rationale / Notes |
| :--- | :--- | :--- |
| **Component Architecture** | [e.g., "Reuse Card component from design system, create new Timeline component"] | [e.g., "Card component fits design, Timeline needs custom implementation"] |
| **Layout Strategy** | [e.g., "CSS Grid for main layout, Flexbox for card internals"] | [e.g., "Grid provides responsive 2-column layout, Flexbox for alignment"] |
| **Responsive Breakpoints** | [e.g., "Mobile: <768px, Tablet: 768-1024px, Desktop: >1024px"] | [e.g., "Standard breakpoints from design system"] |
| **Color Palette** | [e.g., "Primary: #007bff, Secondary: #6c757d, uses design tokens"] | [e.g., "Design system colors, supports light/dark mode"] |
| **Typography** | [e.g., "Headings: 'Inter' 600, Body: 'Inter' 400, 16px base"] | [e.g., "Design system typography scale"] |
| **Spacing System** | [e.g., "8px grid system: 8, 16, 24, 32, 48px"] | [e.g., "Consistent spacing from design system"] |
| **Accessibility** | [e.g., "ARIA labels, keyboard navigation, 4.5:1 contrast ratio minimum"] | [e.g., "WCAG 2.1 AA compliance required"] |
| **Interactive States** | [e.g., "Hover, Focus, Active, Disabled states for all clickable elements"] | [e.g., "Visual feedback for all interactions per design spec"] |
| **Loading States** | [e.g., "Skeleton screens for initial load, spinners for actions"] | [e.g., "Reduces perceived latency, design system pattern"] |
| **Error States** | [e.g., "Inline validation errors, error summary at form top"] | [e.g., "User-friendly error messaging per UX guidelines"] |
| **Animations** | [e.g., "200ms ease-in-out transitions, respects prefers-reduced-motion"] | [e.g., "Subtle animations, accessible to motion-sensitive users"] |
| **Dark Mode** | [e.g., "Full dark mode support using design tokens"] | [e.g., "Product requirement, uses CSS custom properties"] |
| **Internationalization** | [e.g., "Uses i18n library, RTL layout support for Arabic/Hebrew"] | [e.g., "Product supports 10 languages, 3 RTL"] |
| **Browser Support** | [e.g., "Chrome 90+, Firefox 88+, Safari 14+, Edge 90+"] | [e.g., "Based on analytics, covers 98% of users"] |

---

## UI Development Phases

Track the major phases of UI development from design through deployment. This acts as a table of contents for the work.

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Design Review** | [e.g., "Design approved in review meeting 2025-01-15" or "Feedback collected"] | - [ ] Design is reviewed and approved by designer/stakeholder. |
| **Component Planning** | [e.g., "Component breakdown documented in tech spec" or "Link to spec"] | - [ ] Component structure and reusable elements identified. |
| **Accessibility Plan** | [e.g., "WCAG checklist created, ARIA requirements documented" or "Link to plan"] | - [ ] Accessibility requirements documented and understood. |
| **Component Development** | [e.g., "Feature branch: feature/user-dashboard" or "Link to PR #890"] | - [ ] UI components implemented following design spec. |
| **Component Testing** | [e.g., "Added unit tests, integration tests, visual regression tests" or "Link to tests"] | - [ ] Component tests cover functionality and visual regressions. |
| **Accessibility Testing** | [e.g., "Tested with screen reader, keyboard navigation, color contrast" or "Report"] | - [ ] Accessibility validated (automated + manual testing). |
| **Responsive Testing** | [e.g., "Tested on mobile, tablet, desktop breakpoints" or "Device list"] | - [ ] Responsive design verified across target devices/breakpoints. |
| **Browser Testing** | [e.g., "Tested Chrome, Firefox, Safari, Edge" or "Test matrix"] | - [ ] Cross-browser compatibility verified. |
| **UX Review** | [e.g., "Design sign-off received 2025-01-20" or "Designer approval"] | - [ ] Designer/UX team reviewed and approved implementation. |
| **Deployment** | [e.g., "Deployed to staging 2025-01-22, production 2025-01-25" or "Link to release"] | - [ ] UI is deployed and verified in production. |

---

## Component Implementation Workflow

Follow test-driven component development to ensure UI correctness, accessibility, and visual consistency.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Setup Component Structure** | [e.g., "Created component files: Dashboard.tsx, Dashboard.test.tsx, Dashboard.css" or "Link to commit"] | - [ ] Component files created following project structure. |
| **2. Write Component Tests** | [e.g., "Wrote tests for props, interactions, accessibility" or "Link to commit"] | - [ ] Component tests written (unit + integration). |
| **3. Implement Component** | [e.g., "Implemented Dashboard component with Timeline and ActivityFeed" or "Link to PR"] | - [ ] Component implemented matching design spec. |
| **4. Style Component** | [e.g., "Applied styles from design system, responsive breakpoints" or "Link to commit"] | - [ ] Component styled per design spec (responsive + dark mode). |
| **5. Add Accessibility** | [e.g., "Added ARIA labels, keyboard navigation, focus management" or "Link to commit"] | - [ ] Accessibility features implemented (ARIA, keyboard, contrast). |
| **6. Visual Regression Tests** | [e.g., "Added Storybook stories, Percy snapshots" or "Link to stories"] | - [ ] Visual regression tests created and passing. |
| **7. Manual Testing** | [e.g., "Tested on devices, browsers, screen sizes, screen reader" or "Test report"] | - [ ] Manual testing completed (devices, browsers, accessibility tools). |
| **8. Design QA** | [e.g., "Designer reviewed, approved implementation" or "Feedback addressed"] | - [ ] Designer reviewed and approved implementation. |

#### Implementation Notes

> Document component architecture, state management, performance optimizations, accessibility features.

**Component Architecture:**
```tsx
// Example: React component structure
<Dashboard>
  <DashboardHeader />
  <Timeline>
    <ActivityFeed items={activities} />
  </Timeline>
  <DashboardFooter />
</Dashboard>
```

**State Management:**
* [e.g., "Uses React Context for dashboard state, Redux for global user state"]
* [e.g., "Local state for UI interactions (expand/collapse), server state via React Query"]

**Performance Optimizations:**
* [e.g., "Virtualized timeline list (react-window) for 1000+ items"]
* [e.g., "Lazy-loaded images with placeholder, debounced search input"]
* [e.g., "Memoized expensive calculations with useMemo"]

**Accessibility Features:**
* [e.g., "Screen reader announcements for dynamic content updates (aria-live)"]
* [e.g., "Keyboard shortcuts: Ctrl+K for search, Arrow keys for navigation"]
* [e.g., "Skip links for main content, focus trap in modals"]

---

## UI Validation & Release

| Task | Detail/Link |
| :--- | :--- |
| **Component Location** | [Path to components, e.g., "src/components/Dashboard/"] |
| **Storybook Stories** | [Link to Storybook, e.g., "http://storybook.example.com/?path=/story/dashboard"] |
| **Visual Regression Coverage** | [Tool and status, e.g., "Percy: 15 snapshots, all passing"] |
| **Accessibility Report** | [Tool results, e.g., "axe DevTools: 0 violations, Lighthouse: 100 accessibility score"] |
| **Browser Test Matrix** | [Tested browsers, e.g., "Chrome 120, Firefox 121, Safari 17, Edge 120 - all passing"] |
| **Responsive Testing** | [Devices tested, e.g., "iPhone 14, iPad Pro, Desktop 1920x1080 - all layouts correct"] |
| **Performance Metrics** | [If measured, e.g., "LCP: 1.2s, FID: 50ms, CLS: 0.05 (all green)"] |
| **Design Sign-off** | [Designer approval, e.g., "Approved by Alice (UX Designer) on 2025-01-20"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Component Documentation?** | [e.g., "Yes - added to component library docs" or "Link to Storybook"] |
| **Design System Updates?** | [e.g., "Yes - Timeline component added to design system" or "No updates needed"] |
| **Accessibility Improvements?** | [e.g., "Added focus indicators pattern to design system" or "No new patterns"] |
| **Performance Issues?** | [e.g., "None detected" or "Created PERF-567 to optimize large lists"] |
| **Browser Compatibility Issues?** | [e.g., "Safari flexbox bug fixed" or "No issues"] |
| **User Feedback?** | [e.g., "Collected via feature flag, 95% positive" or "Not yet released"] |
| **Analytics Tracking?** | [e.g., "Added GA events for dashboard interactions" or "Link to analytics spec"] |

### Completion Checklist

* [ ] Design is reviewed and approved by designer/UX team.
* [ ] Component structure follows project architecture and design system.
* [ ] All components implemented matching design specifications.
* [ ] Component tests pass (unit, integration, visual regression).
* [ ] Accessibility validated (WCAG 2.1 AA minimum, automated + manual testing).
* [ ] Responsive design verified across all target breakpoints and devices.
* [ ] Cross-browser compatibility verified (all supported browsers tested).
* [ ] Performance metrics meet requirements [if applicable].
* [ ] Designer/UX team reviewed and approved final implementation.
* [ ] Component documentation updated (Storybook, component library).
* [ ] Analytics tracking implemented [if applicable].
* [ ] UI is deployed to production and verified working.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
