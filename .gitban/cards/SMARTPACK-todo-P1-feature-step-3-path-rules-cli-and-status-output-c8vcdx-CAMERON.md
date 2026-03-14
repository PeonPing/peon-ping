# Feature Development Template

**When to use this template:** CLI subcommands for managing path_rules bindings and status display of active rules.

## Feature Overview & Context

* **Associated Ticket/Epic:** v2 > m1 > path-rules > path-rules-status
* **Feature Area/Component:** peon.sh CLI case statement, peon status output
* **Target Release/Milestone:** v2 > M1: Smart Pack Selection

**Required Checks:**
* [x] **Associated Ticket/Epic** link is included above.
* [x] **Feature Area/Component** is identified.
* [x] **Target Release/Milestone** is confirmed.

## Documentation & Prior Art Review

* [x] `README.md` or project documentation reviewed.
* [x] Existing architecture documentation or ADRs reviewed.
* [x] Related feature implementations or similar code reviewed.
* [x] API documentation or interface specs reviewed [if applicable].

| Document Type | Link / Location | Key Findings / Action Required |
| :--- | :--- | :--- |
| **Design Doc** | `docs/plans/2026-02-19-path-rules-design.md` | "CLI / UX" section — status shows active rule, no `peon config set path_rules` |
| **peon.sh** | `peon status` section | Existing status output to extend |
| **peon.sh** | CLI case statement | Pattern for adding subcommands |
| **CLAUDE.md** | "Change Enforcement Rules" | If you add a CLI command → update completions.bash, completions.fish, README |

## Design & Planning

### Initial Design Thoughts & Requirements

* `peon packs bind <pack>` — add a path_rule for cwd (or custom `--pattern`)
* `peon packs unbind` — remove path_rule matching cwd (or by `--pattern`)
* `peon packs bindings` — list all configured path_rules
* `peon status` shows active path rule when one matches cwd (e.g., `path rule: */work/* → glados`)
* Update `completions.bash` and `completions.fish` with new subcommands
* BATS tests for bind, unbind, bindings, and status display
* Depends on: step 2A (path rules matching engine must exist)

### Required Reading

| File | Lines/Section | What to look for |
| :--- | :--- | :--- |
| `docs/plans/2026-02-19-path-rules-design.md` | "CLI / UX" | Status output format, scope exclusions |
| `peon.sh` | `peon packs` case statement | Where to add bind/unbind/bindings |
| `peon.sh` | `peon status` section | Where to add path rule display |
| `completions.bash` | Full file | Completion patterns to extend |
| `completions.fish` | Full file | Fish completion patterns |

### Acceptance Criteria

* [ ] `peon packs bind <pack>` adds a path_rule entry for cwd to config.json
* [ ] `peon packs bind <pack> --pattern "*/custom/*"` uses custom pattern instead of cwd
* [ ] `peon packs unbind` removes the path_rule matching cwd
* [ ] `peon packs unbind --pattern "*/custom/*"` removes by specific pattern
* [ ] `peon packs bindings` lists all path_rules from config
* [ ] `peon status` shows active path rule when one matches (e.g., `path rule: */work/* → glados`)
* [ ] `completions.bash` updated with bind/unbind/bindings subcommands
* [ ] `completions.fish` updated with bind/unbind/bindings subcommands
* [ ] BATS tests cover bind, unbind, bindings list, and status output

## Feature Work Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Design & Architecture** | Design doc approved | - [x] Design Complete |
| **Test Plan Creation** | BATS tests for CLI operations | - [ ] Test Plan Approved |
| **TDD Implementation** | peon.sh CLI + completions | - [ ] Implementation Complete |
| **Integration Testing** | Full test suite | - [ ] Integration Tests Pass |
| **Documentation** | Handled by docs card (step 3) | - [ ] Documentation Complete |
| **Code Review** | PR review | - [ ] Code Review Approved |

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | BATS: bind adds rule, unbind removes, bindings lists, status shows match | - [ ] Failing tests are committed and documented |
| **2. Implement Feature Code** | CLI subcommands + completions | - [ ] Feature implementation is complete |
| **3. Run Passing Tests** | bats tests/peon.bats | - [ ] Originally failing tests now pass |
| **4. Refactor** | Consistent error handling | - [ ] Code is refactored for clarity and maintainability |
| **5. Full Regression Suite** | bats tests/ | - [ ] All tests pass (unit, integration, e2e) |

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | Pending |
| **Testing** | Pending |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Technical Debt Created?** | None expected |
| **Future Enhancements** | `peon config set path_rules` (out of scope — JSON arrays awkward via CLI) |

### Completion Checklist

* [ ] All acceptance criteria are met and verified.
* [ ] All tests are passing (unit, integration, e2e, performance).
* [ ] Code review is approved and PR is merged.
* [ ] Documentation is updated (README, API docs, user guides).
* [ ] Follow-up actions are documented and tickets created.
