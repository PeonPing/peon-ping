# Feature Sprint Setup Template

## Sprint Definition & Scope

* **Sprint Name/Tag**: WINTEST
* **Sprint Goal**: Build a comprehensive functional Pester test suite for all Windows PowerShell production code, replacing structural (regex-matching) tests with behavioral tests that execute code and verify outcomes
* **Timeline**: 2026-03-15 - 2026-03-22
* **Roadmap Link**: v2 > m0: Windows hooks never deadlock or lose state (extends the reliability promise with test confidence)
* **Definition of Done**: All 7 execution cards are done; every Windows .ps1 production file has functional test coverage; CI passes on windows-latest; existing structural lint tests preserved

**Required Checks:**
- [x] Sprint name/tag is chosen and will be used as prefix for all cards
- [x] Sprint goal clearly articulates the value/outcome
- [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

> The code review identified 7 critical gaps in the current test suite (~243 tests, ~95% structural). The sprint decomposes along production code boundaries to maximize parallelism while respecting the shared test infrastructure dependency.

### Work Areas & Card Ideas

**Area 1: Test Infrastructure (foundation -- all other cards depend on this)**
* Shared test harness: extract peon.ps1 from install.ps1, create temp dirs, mock packs/config/state, provide helper functions for piping CESP JSON
* Must work on both PS 5.1 and PS 7+
* Reusable across all subsequent test cards

**Area 2: Core Hook Engine (peon.ps1 behavioral tests)**
* Event routing: pipe real CESP JSON, verify correct category selection and sound file output
* Config behavior: enabled:false early exit, category toggles, volume passthrough
* State management: no-repeat logic, stop debounce, session TTL expiry, prompt timestamp tracking
* Pack selection: default_pack fallback, path_rules matching, session_override, pack_rotation

**Area 3: Adapter Translation (12 adapters)**
* Simple translators (codex, gemini, copilot, windsurf, kiro, openclaw, deepagents): verify JSON output shape for each event mapping
* Filesystem watchers (amp, antigravity, kimi): test state tracking functions and event emission in isolation (not the infinite loop)
* Installers (opencode, kilo): structural tests sufficient, add syntax check for deepagents

**Area 4: Security & Edge Cases**
* hook-handle-use.ps1: path traversal rejection, session ID sanitization, pack validation, CLI vs hook mode
* win-play.ps1: volume clamping math, WAV vs MP3 branching, player priority chain

**Area 5: CI Integration**
* Update .github/workflows/test.yml to discover multiple test files if split
* Ensure test execution time stays under 60s

### Card Types Needed

- [x] **Tests**: ~6 test cards (infrastructure + 5 test implementation cards)
- [x] **Chores**: ~1 chore card (CI workflow update)

---

## Sequential Card Creation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Create Infrastructure Card** | Step 1: shared test harness | - [x] Infrastructure card created |
| **2. Create Core Engine Tests** | Step 2A: peon.ps1 event routing + config + state | - [x] Core engine card created |
| **3. Create Adapter Tests** | Step 2B: all 12 adapters functional tests | - [x] Adapter tests card created |
| **4. Create Security Tests** | Step 2C: hook-handle-use.ps1 + win-play.ps1 | - [x] Security tests card created |
| **5. Create Pack Selection Tests** | Step 2D: pack rotation, path_rules, session_override | - [x] Pack selection card created |
| **6. Create CI Card** | Step 3: CI workflow + final integration | - [x] CI card created |
| **7. Verify Sprint Tags** | list_cards with sprint filter | - [x] All cards show WINTEST tag |

**Created Card IDs**: [to be filled during creation]

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2 > m0 (extends Windows reliability) | - [x] Milestone updated with sprint tag |
| **Take Sprint** | [Date sprint was claimed] | - [x] Used take_sprint() to claim work |
| **Mid-Sprint Check** | [Sprint progress notes] | - [x] Reviewed list_cards(group_by_sprint=True) |
| **Complete Cards** | [Completed card IDs] | - [x] Cards moved to done status |
| **Sprint Archive** | [Archive folder name] | - [ ] Used archive_cards() to bundle work |
| **Generate Summary** | [Summary.md location] | - [ ] Used generate_archive_summary() |
| **Update Changelog** | [Changelog entry] | - [ ] Used update_changelog() |
| **Update Roadmap** | [Milestone status] | - [ ] Marked milestone complete |

---

## Sprint Closeout & Retrospective

| Task | Detail/Link |
| :--- | :--- |
| **Cards Archived** | |
| **Sprint Summary** | |
| **Changelog Entry** | |
| **Roadmap Updated** | |
| **Retrospective** | |

### Completion Checklist

* [ ] All done cards archived to sprint folder
* [ ] Sprint summary generated with automatic metrics
* [ ] Changelog updated with version number and changes
* [ ] Roadmap milestone marked complete with actual date
* [ ] Incomplete cards moved to backlog or next sprint
* [ ] Retrospective notes captured above
* [ ] Follow-up cards created for technical debt
* [ ] Sprint closed and celebrated!


## Follow-up & Lessons Learned


| Topic | Status / Action Required |
| :--- | :--- |
| **Incomplete Cards** | Carry over to next sprint or move to backlog |
| **Stub Cards** | N/A -- all cards fully specified |
| **Technical Debt** | Existing card gtb6dm (state I/O tests) is superseded by this sprint |
| **Process Improvements** | N/A |
| **Dependencies/Blockers** | None identified |
