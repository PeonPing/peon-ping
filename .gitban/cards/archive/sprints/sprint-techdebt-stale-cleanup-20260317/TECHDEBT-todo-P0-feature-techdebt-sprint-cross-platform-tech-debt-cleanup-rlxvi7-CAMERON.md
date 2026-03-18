# TECHDEBT sprint — cross-platform tech debt cleanup

## Sprint Definition & Scope

* **Sprint Name/Tag**: TECHDEBT
* **Sprint Goal**: Clear accumulated tech debt from WINTEST, SMARTPACK, and HOOKBUG sprints — fix Windows bugs, harden test suites, optimize state/config helpers, and add CI safety nets
* **Timeline**: 2026-03-16
* **Roadmap Link**: v2/m0 (Windows reliability), v2/m1 (Smart Pack Selection — close out)
* **Definition of Done**: All 11 cards completed, Pester + BATS tests pass, M0 and M1 roadmap milestones marked done

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

> All 11 cards pre-exist from prior sprints. Consolidated from WINTEST (5), HOOKBUG (2), and untagged backlog (4).

### Work Areas & Card Ideas

**Area 1: Windows Bug Fix (P1)**
* 8ny6qr — Fix ConvertTo-Hashtable array corruption (spam detection broken on Windows)

**Area 2: Test Quality Hardening (P1)**
* d3c6b0 — Remove duplicate deepagents structural tests
* jzn4sz — Replace regex function extraction with AST parser (depends on d3c6b0)
* n5uqeo — Tighten security test assertion precision (exit code + VLC gain regex)
* rd6fu4 — Add path_rules test scenarios 4-7 (runtime done, tests missing)

**Area 3: Code Quality & Optimization (P2)**
* 5efwxz — Update-PeonConfig skip-write optimization
* lyq5ta — DRY up peon.sh state helpers and optimize first-run read path
* z5xm5k — Add diagnostic logging for silent audio failures

**Area 4: CI & Hardening (P2)**
* csedqi — Add CI lint check for python3 bash quoting hazards
* laimst — Harden install flag E2E test, registry fallbacks, and help text

**Area 5: Deferred (P2)**
* 26yooi — Upgrade Write-StateAtomic to true atomic overwrite (blocked until PS 5.1 is dropped)

### Card Types Needed

* [x] **Features**: 0
* [x] **Bugs**: 1 (8ny6qr)
* [x] **Chores**: 8 (d3c6b0, jzn4sz, n5uqeo, 5efwxz, z5xm5k, csedqi, laimst, 26yooi)
* [x] **Spikes**: 0
* [x] **Docs**: 0
* [x] **Refactors**: 1 (lyq5ta)
* [x] **Tests**: 1 (rd6fu4 — test scenarios only, runtime already done)

---

## Sequential Card Creation Workflow

All cards pre-exist. Re-tagged from prior sprints to TECHDEBT.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Cards already exist** | 11 cards re-tagged from WINTEST, HOOKBUG, and backlog | - [x] Feature cards created with sprint tag |
| **2. N/A** | No new cards needed | - [x] Bug cards created with sprint tag |
| **3. N/A** | | - [x] Chore cards created with sprint tag |
| **4. N/A** | | - [x] Spike cards created with sprint tag |
| **5. Verified** | All 11 cards have TECHDEBT sprint tag | - [x] All cards show correct sprint tag |
| **6. Step numbers assigned** | See dispatch plan below | - [x] P0/P1 cards have full acceptance criteria |

**Created Card IDs**: 8ny6qr, d3c6b0, jzn4sz, n5uqeo, rd6fu4, lyq5ta, z5xm5k, 26yooi, 5efwxz, csedqi, laimst

### Dispatch Plan (Revised 2026-03-16)

**Batch 1 — Parallel (4 cards, zero file overlap):**

| Card | Step | Type | Priority | Key Files | Effort |
|------|------|------|----------|-----------|--------|
| d3c6b0 | 1A | chore | P1 | peon-adapters.Tests.ps1 | 15min |
| n5uqeo | 1B | chore | P1 | peon-security.Tests.ps1, hook-handle-use.ps1 | 1h |
| csedqi | 1C | chore | P2 | .github/workflows/, peon.sh | 1-2h |
| lyq5ta | 1D | refactor | P2 | peon.sh (state helpers) | 2-3h |

**Batch 2 — Parallel (3 cards, install.ps1 but different sections):**

| Card | Step | Type | Priority | Key Files | Gate |
|------|------|------|----------|-----------|------|
| 8ny6qr | 2A | bug | P1 | install.ps1 (ConvertTo-Hashtable), peon-engine.Tests.ps1 | Phase 2 barrier |
| jzn4sz | 2B | chore | P1 | peon-adapters.Tests.ps1 | Gated on 1A (d3c6b0) |
| rd6fu4 | 2C | chore | P1 | install.ps1 (peon.ps1 path_rules), peon-packs.Tests.ps1 | Phase 2 barrier |

**Batch 3 — Parallel (3 cards, install.ps1 different sections, P2 cleanup):**

| Card | Step | Type | Priority | Key Files | Effort |
|------|------|------|----------|-----------|--------|
| 5efwxz | 3A | chore | P2 | install.ps1 (Update-PeonConfig) | 1h |
| laimst | 3B | chore | P2 | install.ps1 (install flags/help), adapters-windows.Tests.ps1 | 2-4h |
| z5xm5k | 3C | chore | P2 | scripts/win-play.ps1, install.ps1 (logging/catch blocks) | 1-2h |

**Deferred (Step 4):**

| Card | Step | Type | Priority | Blocked By |
|------|------|------|----------|------------|
| 26yooi | 4 | chore | P2 | External: PS 5.1 EOL — not actionable now |

**Note on install.ps1:** Batches 2 and 3 both touch install.ps1 but in different function sections. Within each batch, parallel worktrees should be safe. The phase barrier between batch 2 and 3 ensures batch 2 merges land first, reducing conflict surface for batch 3.

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2/m0, v2/m1 — both should be marked done after sprint | - [x] Milestone updated with sprint tag |
| **Take Sprint** | | - [ ] Used take_sprint() to claim work |
| **Mid-Sprint Check** | | - [ ] Reviewed list_cards(group_by_sprint=True) |
| **Complete Cards** | | - [ ] Cards moved to done status |
| **Sprint Archive** | | - [ ] Used archive_cards() to bundle work |
| **Generate Summary** | | - [ ] Used generate_archive_summary() |
| **Update Changelog** | | - [ ] Used update_changelog() |
| **Update Roadmap** | | - [ ] Marked M0 and M1 milestones done |

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
| **Incomplete Cards** | 26yooi deferred (PS 5.1 not yet dropped) |
| **Stub Cards** | N/A |
| **Technical Debt** | This sprint IS the tech debt cleanup |
| **Process Improvements** | Roadmap updates should happen immediately after sprint close, not deferred |
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
