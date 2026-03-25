# Windows Native Trainer Sprint

## Sprint Definition & Scope

* **Sprint Name/Tag**: WINTRAIN
* **Sprint Goal**: Port the Peon Trainer to native Windows — CLI subcommands, hook reminder logic, sound sequencing, and Pester tests in `peon.ps1`, achieving feature parity with the Unix trainer in `peon.sh`.
* **Timeline**: 2026-03-22 — 2026-03-25
* **Roadmap Link**: v2 > m3 > trainer-windows ("Windows Native Trainer — peon.ps1 parity")
* **Definition of Done**: All 3 implementation cards done. `peon trainer on/off/status/log/goal/help` works on Windows. Hook reminder sounds fire after main sound. Pester tests pass. No regressions in existing Pester or BATS tests.

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

### Work Areas & Card Ideas

**Area 1: CLI Subcommands (step 1)**
* Trainer CLI: on, off, status, log, goal, help — all pure PowerShell in `switch -Regex` block
* Help text: add Trainer section to `--help` output
* peon.cmd routing: accept both `trainer` and `--trainer` as command prefix

**Area 2: Hook Reminder Logic (step 2)**
* After main sound dispatch (line 1342), check trainer config/state
* Date reset, interval check, slacking detection
* Play trainer sound via win-play.ps1 with 500ms delay
* Fire desktop notification with progress summary via win-notify.ps1
* State written atomically in same Write-StateAtomic call

**Area 3: Pester Tests (step 3)**
* CLI tests: trainer on/off/status/log/goal/help output validation
* Hook tests: trainer reminder fires when interval elapsed
* Performance: hook execution stays under 500ms with trainer enabled

### Card Types Needed

* [x] **Features**: 2 feature cards (CLI + hook logic)
* [x] **Tests**: 1 test card (Pester coverage)
- [x] **Bugs**: 0
- [x] **Chores**: 0
- [x] **Spikes**: 0

---

## Sequential Card Creation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Create Feature Cards** | step 1 (CLI), step 2 (hook logic) | - [x] Feature cards created with sprint tag |
| **2. Create Test Card** | step 3 (Pester tests) | - [x] Test card created with sprint tag |
| **3. Verify Sprint Tags** | list_cards with sprint=WINTRAIN | - [x] All cards show correct sprint tag |
| **4. Fill Detailed Cards** | All cards have full acceptance criteria | - [x] P0/P1 cards have full acceptance criteria |

**Created Card IDs**: yq8iba (step 1: CLI), 2twy3o (step 2: hook logic), hchc5z (step 3: Pester tests)

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2 > m3 > trainer-windows | - [x] Milestone updated with sprint tag |
| **Take Sprint** | Pending | - [x] Used take_sprint() to claim work |
| **Mid-Sprint Check** | Pending | - [x] Reviewed list_cards(group_by_sprint=True) |
| **Complete Cards** | Pending | - [x] Cards moved to done status |
| **Sprint Archive** | Pending | - [x] Used archive_cards() to bundle work |
| **Generate Summary** | Pending | - [x] Used generate_archive_summary() |
| **Update Changelog** | Pending | - [x] Used update_changelog() |
| **Update Roadmap** | Pending | - [x] Marked milestone complete |

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
| **Technical Debt** | Pending |
| **Process Improvements** | Pending |
| **Dependencies/Blockers** | None identified |

### Completion Checklist

- [x] All done cards archived to sprint folder
- [x] Sprint summary generated with automatic metrics
- [x] Changelog updated with version number and changes
- [x] Roadmap milestone marked complete with actual date
- [x] Incomplete cards moved to backlog or next sprint
- [x] Retrospective notes captured above
- [x] Follow-up cards created for technical debt
- [x] Sprint closed and celebrated!
