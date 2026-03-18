# TECHDEBT2 sprint — reviewer fastfollow tech debt cleanup

## Sprint Definition & Scope

* **Sprint Name/Tag**: TECHDEBT2
* **Sprint Goal**: Clear all reviewer-flagged fastfollow items from the first TECHDEBT sprint — harden test helpers, close config parity gaps between peon.sh and peon.ps1, add diagnostic logging to adapter catch blocks, and improve CI lint tooling
* **Timeline**: 2026-03-17
* **Roadmap Link**: v2/m0 (Windows reliability — hardening), v2/m1 (Smart Pack Selection — config parity for windows-cli feature)
* **Definition of Done**: All 10 cards completed, Pester + BATS tests pass, no silent error suppression in adapter .ps1 files

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

> 8 pre-existing backlog cards from TECHDEBT sprint reviewer feedback, plus 1 new card for adapter diagnostic logging. Sprint tracker = 10 total.

### Work Areas & Card Ideas

**Area 1: Test Helper Hardening (P2)**
* 65ghip — Harden Get-FunctionAst parse error + DRY up param extraction
* e40fvu — Add Pester test coverage for PEON_DEBUG warning stream
* 9gi8ut — Add behavioral test coverage for CLI config-write commands

**Area 2: Config Parity & Code Quality (P2)**
* tnd98r — Align default_pack parity + deduplicate Get-ActivePack + fix line 1018 fallback + path_rules test
* yu082h — Harden PS 5.1 locale handling in Write-StateAtomic + improve test harness
* qufq3f — Clean up state helper test timing + narrow retry exception scope

**Area 3: Diagnostic Logging (P2)**
* NEW — Add PEON_DEBUG diagnostic logging to 6 adapter .ps1 empty catch blocks

**Area 4: CI & Tooling (P2)**
* zwho9i — Improve lint-python-quoting hazard reporting + test scope
* augpn7 — Refactor install.ps1 validation into dot-sourceable module

### Card Types Needed

* [x] **Features**: 0
* [x] **Bugs**: 0
* [x] **Chores**: 7 (65ghip, qufq3f, tnd98r, yu082h, zwho9i, NEW adapter logging)
* [x] **Spikes**: 0
* [x] **Docs**: 0
* [x] **Refactors**: 1 (augpn7)
* [x] **Tests**: 2 (9gi8ut, e40fvu)

---

## Sequential Card Creation Workflow

8 cards pre-exist (re-tagged from TECHDEBT backlog to TECHDEBT2). 1 new card created.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Re-tag existing cards** | 8 backlog cards moved from TECHDEBT to TECHDEBT2 | - [x] Feature cards created with sprint tag |
| **2. Create new card** | Adapter diagnostic logging card created | - [x] Bug cards created with sprint tag |
| **3. Update card titles** | Step numbers added to all card titles | - [x] Chore cards created with sprint tag |
| **4. Expand tnd98r scope** | Added Get-ActivePack dedup + line 1018 fix | - [x] Spike cards created with sprint tag |
| **5. Verified** | All 10 cards have TECHDEBT2 sprint tag | - [x] All cards show correct sprint tag |
| **6. Step numbers assigned** | See dispatch plan below | - [x] P0/P1 cards have full acceptance criteria |

**Created Card IDs**: 65ghip, 9gi8ut, augpn7, e40fvu, qufq3f, tnd98r, yu082h, zwho9i, [NEW]

### Dispatch Plan

**Batch 1 — Parallel (4 cards, zero file overlap):**

| Card | Step | Type | Priority | Key Files | Effort |
|------|------|------|----------|-----------|--------|
| qufq3f | 1A | chore | P2 | peon.sh, tests/peon.bats | 15min |
| zwho9i | 1B | chore | P2 | scripts/lint-python-quoting.sh, tests/lint-python-quoting.bats | 1-2h |
| 65ghip | 1C | chore | P2 | tests/adapters-windows.Tests.ps1 | 1h |
| NEW | 1D | chore | P2 | adapters/*.ps1 (6 files) | 1h |

**Batch 2 — Parallel (3 cards, install.ps1 different sections):**

| Card | Step | Type | Priority | Key Files | Gate |
|------|------|------|----------|-----------|------|
| tnd98r | 2A | chore | P2 | install.ps1 (peon.ps1 engine + Get-ActivePack), peon-packs.Tests.ps1 | Phase 2 barrier |
| yu082h | 2B | chore | P2 | install.ps1 (Write-StateAtomic), tests/windows-setup.ps1 | Phase 2 barrier |
| e40fvu | 2C | test | P2 | tests/peon-engine.Tests.ps1 | Phase 2 barrier |

**Batch 3 — Parallel (2 cards, gated on step 2 for install.ps1 stability):**

| Card | Step | Type | Priority | Key Files | Gate |
|------|------|------|----------|-----------|------|
| 9gi8ut | 3A | test | P2 | install.ps1 (CLI commands), new Pester tests | Gated on 2A/2B |
| augpn7 | 3B | refactor | P2 | install.ps1 (validation), adapters-windows.Tests.ps1 | Gated on 1C + 2A/2B |

**Pre-dispatch cleanup required:** Archive stale TECHDEBT cards before dispatch: rlxvi7 (sprint tracker), 5efwxz (todo duplicate), laimst (todo duplicate), z5xm5k (todo duplicate). All have done archived copies.

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2/m0, v2/m1 — hardening and config parity | - [x] Milestone updated with sprint tag |
| **Take Sprint** | | - [x] Used take_sprint() to claim work |
| **Mid-Sprint Check** | | - [x] Reviewed list_cards(group_by_sprint=True) |
| **Complete Cards** | | - [x] Cards moved to done status |
| **Sprint Archive** | | - [x] Used archive_cards() to bundle work |
| **Generate Summary** | | - [x] Used generate_archive_summary() |
| **Update Changelog** | | - [x] Used update_changelog() |
| **Update Roadmap** | | - [x] Marked milestones updated |

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
| **Incomplete Cards** | None expected — all cards are small, well-scoped |
| **Stub Cards** | N/A |
| **Technical Debt** | This sprint IS the tech debt cleanup (phase 2) |
| **Process Improvements** | Reviewer fastfollow items should be triaged into next sprint immediately |
| **Dependencies/Blockers** | augpn7 (3B) gated on 65ghip (1C) — same test file |

### Completion Checklist

- [x] All done cards archived to sprint folder
- [x] Sprint summary generated with automatic metrics
- [x] Changelog updated with version number and changes
- [x] Roadmap milestone marked complete with actual date
- [x] Incomplete cards moved to backlog or next sprint
- [x] Retrospective notes captured above
- [x] Follow-up cards created for technical debt
- [x] Sprint closed and celebrated!
