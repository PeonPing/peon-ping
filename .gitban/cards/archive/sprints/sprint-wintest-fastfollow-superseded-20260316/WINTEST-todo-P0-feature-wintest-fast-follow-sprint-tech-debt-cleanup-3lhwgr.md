# WINTEST fast-follow sprint — tech debt cleanup

## Sprint Definition & Scope

* **Sprint Name/Tag**: WINTEST (continuation — fast-follow phase)
* **Sprint Goal**: Close out 5 remaining tech debt cards from the original WINTEST sprint (reviewer-flagged issues from steps 2A-2D)
* **Timeline**: 2026-03-16 (single session)
* **Roadmap Link**: v2/m1/windows-cli (rd6fu4 path_rules port), v2/m0 (8ny6qr array corruption fix)
* **Definition of Done**: All 5 cards completed, all Pester tests pass, no regressions

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

> All 5 cards already exist in todo status from the original WINTEST planner. No new cards needed.

### Work Areas & Card Ideas

**Area 1: Production Bug Fix**
* 8ny6qr — Fix ConvertTo-Hashtable array corruption in peon.ps1 (spam detection broken on Windows)

**Area 2: Test Quality Hardening**
* d3c6b0 — Remove duplicate deepagents structural tests from peon-adapters.Tests.ps1
* jzn4sz — Replace regex function extraction with AST parser in peon-adapters.Tests.ps1
* n5uqeo — Tighten security test assertion precision (exit code + VLC gain regex)

**Area 3: Feature Port**
* rd6fu4 — Port path_rules to peon.ps1 and add pack selection test scenarios 4-7

### Card Types Needed

* [x] **Features**: 0
* [x] **Bugs**: 1 (8ny6qr)
* [x] **Chores**: 4 (d3c6b0, jzn4sz, n5uqeo, rd6fu4)
* [x] **Spikes**: 0
* [x] **Docs**: 0

---

## Sequential Card Creation Workflow

All cards pre-exist. Step numbers assigned to existing cards:

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Cards already exist** | 8ny6qr, d3c6b0, jzn4sz, n5uqeo, rd6fu4 — all in todo | - [x] Feature cards created with sprint tag |
| **2. N/A** | No new cards needed | - [x] Bug cards created with sprint tag |
| **3. N/A** | | - [x] Chore cards created with sprint tag |
| **4. N/A** | | - [x] Spike cards created with sprint tag |
| **5. Verified** | All 5 cards have WINTEST sprint tag | - [x] All cards show correct sprint tag |
| **6. Step numbers assigned** | Step 1A/1B/1C/1D/2 added to each card | - [x] P0/P1 cards have full acceptance criteria |

**Created Card IDs**: 8ny6qr, d3c6b0, jzn4sz, n5uqeo, rd6fu4

### Dispatch Plan

**Step 1 — Parallel batch (4 cards, no shared files):**

| Card | Step | Files | Effort |
|------|------|-------|--------|
| 8ny6qr | 1A | install.ps1, peon-engine.Tests.ps1 | 1-2h |
| n5uqeo | 1B | peon-security.Tests.ps1, hook-handle-use.ps1 | 1h |
| d3c6b0 | 1C | peon-adapters.Tests.ps1 | 15min |
| rd6fu4 | 1D | peon.ps1 (in install.ps1), peon-packs.Tests.ps1 | 2-4h |

**Step 2 — Sequential (1 card, gated on 1C):**

| Card | Step | Files | Depends On |
|------|------|-------|------------|
| jzn4sz | 2 | peon-adapters.Tests.ps1 | d3c6b0 (same file) |

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2/m1/windows-cli, v2/m0 | - [x] Milestone updated with sprint tag |
| **Take Sprint** | Cards already in todo | - [ ] Used take_sprint() to claim work |
| **Mid-Sprint Check** | | - [ ] Reviewed list_cards(group_by_sprint=True) |
| **Complete Cards** | | - [ ] Cards moved to done status |
| **Sprint Archive** | | - [ ] Used archive_cards() to bundle work |
| **Generate Summary** | | - [ ] Used generate_archive_summary() |
| **Update Changelog** | | - [ ] Used update_changelog() |
| **Update Roadmap** | | - [ ] Marked milestone complete |

---

## Sprint Closeout & Retrospective

| Task | Detail/Link |
| :--- | :--- |
| **Cards Archived** | |
| **Sprint Summary** | |
| **Changelog Entry** | |
| **Roadmap Updated** | |
| **Retrospective** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Incomplete Cards** | N/A |
| **Stub Cards** | N/A |
| **Technical Debt** | These ARE the tech debt cards |
| **Process Improvements** | N/A |
| **Dependencies/Blockers** | jzn4sz gated on d3c6b0 (same file) |

### Completion Checklist

* [ ] All done cards archived to sprint folder
* [ ] Sprint summary generated with automatic metrics
* [ ] Changelog updated with version number and changes
* [ ] Roadmap milestone marked complete with actual date
* [ ] Incomplete cards moved to backlog or next sprint
* [ ] Retrospective notes captured above
* [ ] Follow-up cards created for technical debt
* [ ] Sprint closed and celebrated!
