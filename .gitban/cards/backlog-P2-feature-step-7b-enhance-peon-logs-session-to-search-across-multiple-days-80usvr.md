# step 7B: Enhance peon logs --session to search across multiple days

## Feature Overview & Context

* **Associated Ticket/Epic:** PRD-002 — Hook Observability (follow-up from kt3ucx review 1)
* **Feature Area/Component:** peon.sh `logs --session` CLI command
* **Target Release/Milestone:** v2/m4 "When something breaks, you can see why"

**Required Checks:**
* [x] **Associated Ticket/Epic** link is included above.
* [x] **Feature Area/Component** is identified.
* [x] **Target Release/Milestone** is confirmed.

## Documentation & Prior Art Review

* [x] `README.md` or project documentation reviewed.
* [x] Existing architecture documentation or ADRs reviewed.
* [x] Related feature implementations or similar code reviewed.
* [ ] API documentation or interface specs reviewed [if applicable].

| Document Type | Link / Location | Key Findings / Action Required |
| :--- | :--- | :--- |
| **peon.sh** | peon.sh (logs --session case) | Currently greps only today's log file (`peon-ping-YYYY-MM-DD.log`) |
| **Step 4A card** | kt3ucx | Implemented --session ID that filters by `session=ID` in today's log only |
| **Design Doc** | docs/designs/structured-hook-logging.md | Check for multi-day session design notes |

## Design & Planning

### Initial Design Thoughts & Requirements

* `peon logs --session ID` currently only searches today's log file (`peon-ping-$(date +%Y-%m-%d).log`). If a session spans midnight, entries in older log files are missed.
* Proposed enhancement: Add `--all` flag so `peon logs --session ID --all` searches across all log files in the logs directory.
* Default behavior (no --all) stays unchanged for performance — searching a single file is fast.
* With --all, concatenate all log files in chronological order and grep for the session ID.
* Also consider: `peon logs --session ID --days N` to limit search to last N days (performance optimization for large log directories).

### Acceptance Criteria

* [ ] `peon logs --session ID --all` searches across all log files for the given session ID
* [ ] `peon logs --session ID` (without --all) continues to search only today's log (backward compatible)
* [ ] Results are displayed in chronological order when searching multiple files
* [ ] BATS tests cover: --session with --all finds entries across multiple day files, --session without --all only finds today's entries
* [ ] completions.bash and completions.fish updated with `--all` flag for logs command
* [ ] Works on macOS, Linux, and WSL2
* [ ] PowerShell parity: equivalent `--all` flag added to peon.ps1 logs command

## Feature Work Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Design & Architecture** | See design thoughts above | - [ ] Design Complete |
| **Test Plan Creation** | BATS tests for multi-day session search | - [ ] Test Plan Approved |
| **TDD Implementation** | Modify logs --session in peon.sh to support --all flag | - [ ] Implementation Complete |
| **Integration Testing** | Create log files across multiple days, search with --all | - [ ] Integration Tests Pass |
| **Documentation** | Update README (step 5 card scope) | - [ ] Documentation Complete |
| **Code Review** | Sprint reviewer | - [ ] Code Review Approved |
| **Deployment Plan** | Available on next peon update | - [ ] Deployment Plan Ready |

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | BATS: --session ID --all finds entries in yesterday's log; --session ID without --all misses yesterday's entries; chronological ordering | - [ ] Failing tests are committed and documented |
| **2. Implement Feature Code** | (a) Parse --all flag in logs --session handler. (b) When --all, glob all log files, sort chronologically, grep across all. (c) Update completions. | - [ ] Feature implementation is complete |
| **3. Run Passing Tests** | All new + existing BATS tests pass | - [ ] Originally failing tests now pass |
| **4. Refactor** | N/A — straightforward flag addition | - [ ] Code is refactored for clarity and maintainability |
| **5. Full Regression Suite** | `bats tests/` green | - [ ] All tests pass (unit, integration, e2e) |
| **6. Performance Testing** | N/A | - [ ] Performance requirements are met |

### Implementation Notes

**Required Reading:**

| File | Lines | Purpose |
| :--- | :--- | :--- |
| `peon.sh` | logs --session case block | Add --all flag parsing and multi-file search |
| `peon.ps1` | logs --session equivalent | Add --all flag for PowerShell parity |
| `completions.bash` | logs subcommands | Add --all flag |
| `completions.fish` | logs subcommands | Add --all flag |
| `tests/peon.bats` | logs --session tests | Add multi-day search tests |

**Key Constraint:** Default behavior must remain unchanged (single-file search) for backward compatibility and performance. The --all flag is opt-in.

**Change Enforcement:** Adding a CLI flag (--all) requires updating completions.bash, completions.fish, and BATS tests.

**Origin:** Review 1 of card kt3ucx noted that midnight-spanning sessions lose entries with current single-file search.

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | TBD |
| **QA Verification** | TBD |
| **Staging Deployment** | N/A |
| **Production Deployment** | N/A |
| **Monitoring Setup** | N/A |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Postmortem Required?** | No |
| **Further Investigation?** | No |
| **Technical Debt Created?** | No |
| **Future Enhancements** | `peon logs --session ID --days N` for bounded multi-day search |

### Completion Checklist

* [ ] All acceptance criteria are met and verified.
* [ ] All tests are passing (unit, integration, e2e, performance).
* [ ] Code review is approved and PR is merged.
* [ ] Documentation is updated (README, API docs, user guides).
* [ ] Feature is deployed to production.
* [ ] Monitoring and alerting are configured.
* [ ] Stakeholders are notified of completion.
* [ ] Follow-up actions are documented and tickets created.
* [ ] Associated ticket/epic is closed.
