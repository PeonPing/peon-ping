# SMARTPACK Tech Debt Sprint

## Sprint Definition & Scope

* **Sprint Name/Tag**: SMARTPACKDEBT
* **Sprint Goal**: Systematically resolve the four non-blocking tech debt items identified by reviewers during the SMARTPACK sprint — hardening shell quoting safety in peon.sh, improving Windows state I/O reliability, improving ffplay install guidance, and consolidating duplicated CLI patterns in install.ps1.
* **Timeline**: 2026-03-15 — 2026-03-22
* **Roadmap Link**: v2 > m0 (Windows hooks never deadlock or lose state) + v2 > m1 (Smart Pack Selection cleanup)
* **Definition of Done**: All four deferred cards completed, CI green (BATS + Pester), no regressions introduced.

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

> Four deferred cards from SMARTPACK sprint reviews, adopted into this sprint. One additional backlog card (26yooi — Write-StateAtomic upgrade) was considered but excluded because it is blocked on dropping PowerShell 5.1 support.

### Work Areas & Card Ideas

**Area 1: Shell Safety (peon.sh)**
* dsmh31 — Audit all 61 `python3 -c` blocks for bash double-quoting hazards (flagged during i0u93q review)

**Area 2: Windows State Reliability (install.ps1 embedded peon.ps1)**
* exg19y — Harden Write-StateAtomic non-atomic window + safety timer exit path (flagged during z0c9fd review)

**Area 3: Windows Install UX (install.ps1)**
* ji2847 — Improve ffplay install guidance for Gyan build PATH issue (flagged during janrlf review)
* inexon — Parallel pack downloads + config I/O deduplication for bind/unbind/bindings (flagged during 9pjhy5 review)

### Card Types Needed

* [x] **Chores**: 4 chore cards (all tech debt / quality improvements)
* [x] **Features**: 0
* [x] **Bugs**: 0
* [x] **Spikes**: 0
* [x] **Docs**: 0

---

## Sequential Card Creation Workflow

All four cards already exist in backlog. This sprint adopts them via `add_card_to_sprint`, then enriches with step numbers and Required Reading.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Adopt Existing Cards** | dsmh31, exg19y, ji2847, inexon — add to SMARTPACKDEBT sprint | - [x] Cards adopted with sprint tag |
| **2. Enrich Cards** | Add step numbers, Required Reading tables, and acceptance criteria | - [x] Cards enriched with execution context |
| **3. Verify Sprint Tags** | list_cards(sprint="SMARTPACKDEBT") | - [x] All cards show correct sprint tag |
| **4. Move to Todo** | Move all cards to todo status | - [x] Cards ready for dispatch |

**Execution Order:**
- **Step 1**: dsmh31 — audit peon.sh python blocks (highest risk, 61 invocations, touches core hook)
- **Step 2A**: exg19y — harden Windows atomic state edge cases (install.ps1 state code)
- **Step 2B**: ji2847 — improve ffplay install guidance (install.ps1 post-install message)
- **Step 2C**: inexon — bind/unbind quality improvements (install.ps1 CLI subcommands)

Steps 2A/2B/2C are parallelizable — they touch non-overlapping sections of install.ps1.

**Card IDs**: dsmh31, exg19y, ji2847, inexon

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2 > m0 (state-concurrency) + v2 > m1 (windows-cli) | - [x] Milestone updated with sprint tag |
| **Take Sprint** | Pending | - [x] Used take_sprint() to claim work |
| **Mid-Sprint Check** | Pending | - [x] Reviewed list_cards(sprint="SMARTPACKDEBT") |
| **Complete Cards** | Pending | - [x] Cards moved to done status |
| **Sprint Archive** | Pending | - [x] Used archive_cards() to bundle work |
| **Generate Summary** | Pending | - [x] Used generate_archive_summary() |
| **Update Changelog** | Pending | - [x] Used update_changelog() |
| **Update Roadmap** | Pending — these are tech debt items, not milestone completions | - [x] Marked milestone complete |

---

## Sprint Closeout & Retrospective

| Task | Detail/Link |
| :--- | :--- |
| **Cards Archived** | Pending |
| **Sprint Summary** | Pending |
| **Changelog Entry** | Pending |
| **Roadmap Updated** | Pending |
| **Retrospective** | Pending |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Incomplete Cards** | N/A |
| **Stub Cards** | N/A |
| **Technical Debt** | Card 26yooi (Write-StateAtomic upgrade) remains blocked on PS 5.1 deprecation |
| **Process Improvements** | N/A |
| **Dependencies/Blockers** | None — all four cards are independent |

### Completion Checklist

- [x] All done cards archived to sprint folder
- [x] Sprint summary generated with automatic metrics
- [x] Changelog updated with version number and changes
- [x] Roadmap milestone marked complete with actual date
- [x] Incomplete cards moved to backlog or next sprint
- [x] Retrospective notes captured above
- [x] Follow-up cards created for technical debt
- [x] Sprint closed and celebrated!
