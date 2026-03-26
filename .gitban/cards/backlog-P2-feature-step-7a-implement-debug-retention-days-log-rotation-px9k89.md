# step 7A: Implement debug_retention_days log rotation

## Feature Overview & Context

* **Associated Ticket/Epic:** PRD-002 — Hook Observability (follow-up from kt3ucx review 1)
* **Feature Area/Component:** peon.sh log rotation, config.json `debug_retention_days` key
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
| **config.json** | config.json | `debug_retention_days: 7` is defined but nothing reads it to prune logs |
| **peon.sh** | peon.sh (debug/logs case blocks) | CLI commands exist for debug on/off/status and logs viewing, but no rotation logic |
| **Design Doc** | docs/designs/structured-hook-logging.md | Should be checked for any rotation design notes |
| **Step 4A card** | kt3ucx | Implemented debug CLI commands, noted `debug_retention_days` backfill exists but no consumer |

## Design & Planning

### Initial Design Thoughts & Requirements

* The `debug_retention_days` config key is already defined in config.json (default: 7) and backfilled by `peon update`, but nothing in the codebase reads it to actually prune old log files.
* Two possible implementation approaches:
  1. **On-hook-invocation pruning:** Each time peon.sh fires, check if log files older than N days exist and delete them. Lightweight, no daemon needed.
  2. **CLI-triggered pruning:** Add `peon logs --prune` that deletes log files older than `debug_retention_days`. Explicit, user-controlled.
* Recommendation: Implement both. On-invocation pruning is silent and automatic; `peon logs --prune` gives manual control.
* Log files follow naming convention `peon-ping-YYYY-MM-DD.log`, so age can be inferred from filename.

### Acceptance Criteria

* [ ] Log files older than `debug_retention_days` are automatically pruned on each hook invocation (when debug is enabled)
* [ ] `peon logs --prune` manually deletes log files older than `debug_retention_days`
* [ ] Pruning respects the configured `debug_retention_days` value (not hardcoded)
* [ ] Pruning uses filename-based date parsing (not filesystem mtime) for consistency
* [ ] BATS tests cover: auto-pruning on invocation, manual --prune, custom retention value, edge case of 0 old files
* [ ] completions.bash and completions.fish updated with `--prune` flag
* [ ] Works on macOS, Linux, and WSL2

## Feature Work Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Design & Architecture** | See design thoughts above | - [ ] Design Complete |
| **Test Plan Creation** | BATS tests for auto-prune and manual --prune | - [ ] Test Plan Approved |
| **TDD Implementation** | Add pruning logic to peon.sh hook path + logs --prune CLI | - [ ] Implementation Complete |
| **Integration Testing** | End-to-end: create old log files, trigger hook, verify pruned | - [ ] Integration Tests Pass |
| **Documentation** | Update README (step 5 card scope) | - [ ] Documentation Complete |
| **Code Review** | Sprint reviewer | - [ ] Code Review Approved |
| **Deployment Plan** | Available on next peon update | - [ ] Deployment Plan Ready |

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | BATS: auto-prune removes old files on hook invocation; --prune removes old files manually; retention value is respected; no files pruned when all are recent | - [ ] Failing tests are committed and documented |
| **2. Implement Feature Code** | (a) Add prune function in peon.sh that reads debug_retention_days and deletes old log files. (b) Call from hook invocation path. (c) Add --prune flag to logs CLI command. (d) Update completions. | - [ ] Feature implementation is complete |
| **3. Run Passing Tests** | All new + existing BATS tests pass | - [ ] Originally failing tests now pass |
| **4. Refactor** | Ensure prune logic is a shared function used by both paths | - [ ] Code is refactored for clarity and maintainability |
| **5. Full Regression Suite** | `bats tests/` green | - [ ] All tests pass (unit, integration, e2e) |
| **6. Performance Testing** | N/A | - [ ] Performance requirements are met |

### Implementation Notes

**Required Reading:**

| File | Lines | Purpose |
| :--- | :--- | :--- |
| `peon.sh` | logs case block | Add --prune flag handling |
| `peon.sh` | hook invocation path (after sound selection) | Add auto-prune call |
| `config.json` | `debug_retention_days` key | Default value (7) |
| `completions.bash` | logs subcommands | Add --prune |
| `completions.fish` | logs subcommands | Add --prune |
| `tests/peon.bats` | debug/logs tests section | Add pruning tests |

**Key Constraint:** Pruning should be fast and non-blocking. Use filename date parsing rather than `find -mtime` for cross-platform consistency. Log filenames are `peon-ping-YYYY-MM-DD.log`.

**Change Enforcement:** Adding a CLI flag (--prune) requires updating completions.bash, completions.fish, and BATS tests.

**Origin:** Review 1 of card kt3ucx flagged that `debug_retention_days` is defined but never consumed.

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
| **Technical Debt Created?** | No — this card resolves existing tech debt |
| **Future Enhancements** | Size-based rotation (max log dir size) |

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
