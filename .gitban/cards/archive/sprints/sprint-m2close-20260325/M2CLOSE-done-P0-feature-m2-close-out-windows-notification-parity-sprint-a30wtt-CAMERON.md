# M2 Close-Out — Windows Notification Parity Sprint

## Sprint Definition & Scope

* **Sprint Name/Tag**: M2CLOSE
* **Sprint Goal**: Close out v2/m2 milestone by shipping Windows notification template CLI parity and completing documentation translation
* **Timeline**: 2026-03-25
* **Roadmap Link**: v2/m2 — "Notifications tell you what happened, not just that something happened"
* **Definition of Done**: All v2/m2 roadmap projects status = done, milestone marked done, version bump

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

### Work Areas & Card Ideas

**Area 1: Windows Notifications CLI (Phase 1 of design doc)**
* step 1: `--notifications template` CLI get/set/reset, `--notifications on/off`, `--popups` alias, `--status --verbose`, help text, Pester tests

**Area 2: Documentation Translation**
* step 1: README_zh.md — translate Common Use Cases, Independent Controls, notification templates sections

### Card Types Needed

* [x] **Features**: 1 feature card (Windows notifications CLI + tests)
- [x] **Bugs**: 0
* [x] **Chores**: 1 chore card (README_zh.md translation)
- [x] **Spikes**: 0
- [x] **Docs**: 0

### Architectural Approach

The template resolution engine is already shipped (card kr62ia, commit 4856b0f). What remains is the CLI surface and documentation.

The CLI card is a single card because all CLI additions share one insertion point in install.ps1's switch block (~line 503). The `--notifications` case with template/on/off sub-routing, the `--popups` alias, and `--status --verbose` are tightly coupled. The Pester tests are part of the same card (TDD).

The README_zh.md translation is independent and can run in parallel.

---

## Sequential Card Creation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Create Feature Cards** | Windows notifications CLI + Pester tests | - [x] Feature cards created with sprint tag |
| **2. Create Bug Cards** | N/A | - [x] Bug cards created with sprint tag |
| **3. Create Chore Cards** | README_zh.md translation | - [x] Chore cards created with sprint tag |
| **4. Create Spike Cards** | N/A | - [x] Spike cards created with sprint tag |
| **5. Verify Sprint Tags** | All cards tagged M2CLOSE | - [x] All cards show correct sprint tag |
| **6. Fill Detailed Cards** | Both cards have full acceptance criteria | - [x] P0/P1 cards have full acceptance criteria |

**Created Card IDs**: ot0edu (feature: Windows notifications CLI + Pester tests), zekqgl (chore: README_zh.md translation)

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2/m2, PRD-001 | - [x] Milestone updated with sprint tag |
| **Take Sprint** | 2026-03-25 | - [x] Used take_sprint() to claim work |
| **Mid-Sprint Check** | | - [x] Reviewed list_cards(group_by_sprint=True) |
| **Complete Cards** | | - [x] Cards moved to done status |
| **Sprint Archive** | | - [x] Used archive_cards() to bundle work |
| **Generate Summary** | | - [x] Used generate_archive_summary() |
| **Update Changelog** | | - [x] Used update_changelog() |
| **Update Roadmap** | Mark v2/m2 done | - [x] Marked milestone complete |

---

## Sprint Closeout & Retrospective

| Task | Detail/Link |
| :--- | :--- |
| **Cards Archived** | |
| **Sprint Summary** | |
| **Changelog Entry** | Patch version bump |
| **Roadmap Updated** | v2/m2 → done |
| **Retrospective** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Incomplete Cards** | |
| **Stub Cards** | N/A |
| **Technical Debt** | None anticipated |
| **Process Improvements** | Roadmap was stale — need to update roadmap when features ship, not after |
| **Dependencies/Blockers** | None |

### What Went Well

* Template engine already shipped (kr62ia) — sprint is just CLI + docs

### What Could Be Improved

* Roadmap should have been updated when click-to-focus and trainer shipped on Windows
* Windows parity should be tracked as a standing concern, not discovered ad hoc

### Completion Checklist

- [x] All done cards archived to sprint folder
- [x] Sprint summary generated with automatic metrics
- [x] Changelog updated with version number and changes
- [x] Roadmap milestone marked complete with actual date
- [x] Incomplete cards moved to backlog or next sprint
- [x] Retrospective notes captured above
- [x] Follow-up cards created for technical debt
- [x] Sprint closed and celebrated!
