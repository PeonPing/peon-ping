# Feature Sprint Setup Template

## Sprint Definition & Scope

* **Sprint Name/Tag**: SMARTPACK
* **Sprint Goal**: Users get the right sound pack for the right project automatically via path_rules glob matching, with cleaned-up config key names
* **Timeline**: 2026-03-13 — 2026-03-15
* **Roadmap Link**: v2 > m1 > Smart Pack Selection
* **Definition of Done**: path_rules matching works, config renames shipped with migration, CLI bind/unbind commands work, docs updated

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

> Two features from the roadmap, decomposed into implementation cards.

### Work Areas & Card Ideas

**Area 1: Config Renames (foundational)**
* Rename active_pack → default_pack with runtime fallback
* Rename agentskill rotation mode → session_override
* Migration logic in peon update
* Tests for migration idempotency

**Area 2: Path Rules Engine**
* fnmatch-based path_rules evaluation in Python block
* First-match-wins with installed-pack validation
* Override hierarchy: session_override > local config > path_rules > pack_rotation > default_pack

**Area 3: CLI + Status + Tests**
* peon packs bind/unbind/bindings subcommands
* peon status shows active path rule
* BATS tests for matching, fallthrough, override ordering

**Area 4: Documentation**
* README path_rules section
* README_zh mirror
* llms.txt updates

### Card Types Needed

* [x] **Features**: 3 feature cards
* [x] **Docs**: 1 documentation card

---

## Sequential Card Creation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Create Sprint Tracker** | This card | - [x] Sprint tracker created |
| **2. Create Feature Cards** | Config renames, path rules engine, CLI+tests | - [ ] Feature cards created with sprint tag |
| **3. Create Doc Card** | README + README_zh + llms.txt | - [ ] Doc card created with sprint tag |
| **4. Verify Sprint Tags** | list_cards with sprint filter | - [ ] All cards show SMARTPACK tag |
| **5. Fill Detailed Cards** | All cards have full acceptance criteria | - [ ] P0/P1 cards have full acceptance criteria |
| **6. Move to Todo** | All cards promoted | - [ ] All cards in todo status |

**Created Card IDs**: 0xybwm (sprint tracker), aodz7v (config renames), 0vvvnb (path rules engine), c8vcdx (CLI + status), janrlf (documentation)

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2 > m1 > Smart Pack Selection | - [ ] Milestone updated with sprint tag |
| **Take Sprint** | Pending | - [ ] Used take_sprint() to claim work |
| **Mid-Sprint Check** | Pending | - [ ] Reviewed list_cards(sprint="SMARTPACK") |
| **Complete Cards** | Pending | - [ ] Cards moved to done status |
| **Sprint Archive** | Pending | - [ ] Used archive_cards() to bundle work |
| **Generate Summary** | Pending | - [ ] Used generate_archive_summary() |
| **Update Changelog** | Pending | - [ ] Used update_changelog() |
| **Update Roadmap** | Pending | - [ ] Marked milestone complete |

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
| **Incomplete Cards** | Pending |
| **Technical Debt** | Pending |
| **Process Improvements** | Pending |

### Completion Checklist

* [ ] All done cards archived to sprint folder
* [ ] Sprint summary generated with automatic metrics
* [ ] Changelog updated with version number and changes
* [ ] Roadmap milestone marked complete with actual date
* [ ] Incomplete cards moved to backlog or next sprint
* [ ] Retrospective notes captured above
* [ ] Follow-up cards created for technical debt
* [ ] Sprint closed and celebrated!
