# Feature Sprint Setup Template

## Sprint Definition & Scope

* **Sprint Name/Tag**: HOOKBUG
* **Sprint Goal**: Eliminate P0 hook reliability bugs on native Windows — async audio playback, state file concurrency safety, and deadlock prevention
* **Timeline**: 2026-03-14 — 2026-03-21
* **Roadmap Link**: v2 > m0: Windows Reliability
* **Definition of Done**: Sprint complete when both feature cards are done, all Pester + BATS tests pass, and manual Windows validation confirms <200ms hook return time and zero deadlocks

**Required Checks:**
* [x] Sprint name/tag is chosen and will be used as prefix for all cards
* [x] Sprint goal clearly articulates the value/outcome
* [x] Roadmap milestone is identified and linked

---

## Card Planning & Brainstorming

> Two-phase implementation from the design doc. Phase 1 removes the deadlock source and makes audio async. Phase 2 hardens state persistence on both platforms.

### Work Areas & Card Ideas

**Area 1: Async Audio (Phase 1)**
* Remove MediaPlayer/PresentationCore from peon.ps1 — eliminates WPF dispatcher deadlock
* Delegate audio to detached win-play.ps1 via Start-Process -WindowStyle Hidden
* Replace MediaPlayer in win-play.ps1 with CLI player priority chain (ffplay → mpv → vlc)
* Add 8-second self-timeout via System.Timers.Timer
* Print ffmpeg recommendation in installer post-install

**Area 2: Atomic State Writes (Phase 2)**
* PowerShell: Write-StateAtomic function (temp file + [IO.File]::Move)
* PowerShell: Read-StateWithRetry function (3 attempts, backoff)
* Python: write_state() helper replacing 8 json.dump(open('w')) call sites
* Python: read_state() helper with retry logic
* BATS tests for corrupted state recovery and concurrent writes

### Card Types Needed

* [x] **Features**: 2 feature cards (step 1: async audio, step 2: atomic state)
- [x] **Bugs**: 0
- [x] **Chores**: 0
- [x] **Spikes**: 0
- [x] **Docs**: 0 (documentation integrated into feature cards)

---

## Sequential Card Creation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Create Feature Cards** | Step 1: async audio, Step 2: atomic state | - [x] Feature cards created with sprint tag |
| **2. Create Bug Cards** | N/A | - [x] No bug cards needed |
| **3. Create Chore Cards** | N/A | - [x] No chore cards needed |
| **4. Create Spike Cards** | N/A | - [x] No spike cards needed |
| **5. Verify Sprint Tags** | All cards tagged HOOKBUG | - [x] All cards show correct sprint tag |
| **6. Fill Detailed Cards** | Both cards have full acceptance criteria from design doc | - [x] P0/P1 cards have full acceptance criteria |

**Created Card IDs**: d5wz2f (step 1: async audio), kydihy (step 2: atomic state)

---

## Sprint Execution Phases

| Phase / Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Roadmap Integration** | v2 > m0: Windows Reliability | - [x] Milestone updated with sprint tag |
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
| **Stub Cards** | N/A |
| **Technical Debt** | PowerShell cold-start optimization deferred (separate initiative) |
| **Process Improvements** | Consider CI timing check for hook scripts |
| **Dependencies/Blockers** | None identified |

### What Went Well

* [Pending sprint completion]

### What Could Be Improved

* [Pending sprint completion]

### Completion Checklist

- [x] All done cards archived to sprint folder
- [x] Sprint summary generated with automatic metrics
- [x] Changelog updated with version number and changes
- [x] Roadmap milestone marked complete with actual date
- [x] Incomplete cards moved to backlog or next sprint
- [x] Retrospective notes captured above
- [x] Follow-up cards created for technical debt
- [x] Sprint closed and celebrated!
