# Feature Development Template

**When to use this template:** Core path_rules matching logic in the Python event parser — the heart of M1.

## Feature Overview & Context

* **Associated Ticket/Epic:** v2 > m1 > path-rules > path-rules-matching
* **Feature Area/Component:** peon.sh Python block, pack selection logic
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
| **Design Doc** | `docs/plans/2026-02-19-path-rules-design.md` | "Matching Logic" section has exact Python snippet |
| **Design Doc** | `docs/plans/2026-02-19-path-rules-design.md` | "Override Hierarchy" — path_rules is layer 3 |
| **peon.sh** | Python block, pack selection | Current rotation/default logic to extend |
| **config.json** | `config.json` | Add `"path_rules": []` to template |

## Design & Planning

### Initial Design Thoughts & Requirements

* New `path_rules` array in config.json: `[{"pattern": "*/work/*", "pack": "glados"}]`
* fnmatch-based glob matching against `cwd` in Python block
* Insert after config load + cwd extraction, before rotation/default block
* Only runs if session_override has not already assigned a pack
* First matching rule wins; remaining rules skipped
* If matched pack is not installed, fall through to next layer
* Override hierarchy: session_override > local config > path_rules > pack_rotation > default_pack
* peon.ps1 needs equivalent matching logic (without fnmatch — use .NET glob or manual matching)

### Required Reading

| File | Lines/Section | What to look for |
| :--- | :--- | :--- |
| `docs/plans/2026-02-19-path-rules-design.md` | "Matching Logic" | Exact Python implementation snippet |
| `docs/plans/2026-02-19-path-rules-design.md` | "Override Hierarchy" | Layer ordering and philosophy |
| `peon.sh` | Python block, after config load | Where to insert path_rules evaluation |
| `peon.sh` | Pack rotation logic | Code that path_rules should precede |
| `peon.ps1` | Pack selection section | Windows counterpart |

### Acceptance Criteria

* [ ] `config.json` template includes `"path_rules": []`
* [ ] Python block evaluates path_rules using fnmatch against cwd
* [ ] First matching rule with an installed pack wins
* [ ] Unmatched or missing-pack rules fall through to rotation/default
* [ ] session_override beats path_rules (override hierarchy respected)
* [ ] Empty path_rules array has no effect (backward compatible)
* [ ] peon.ps1 has equivalent path_rules matching
* [ ] BATS tests cover: basic match, no match, first-wins, missing pack fallthrough, glob patterns, empty array, session_override override

## Feature Work Phases

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Design & Architecture** | Design doc approved, Python snippet provided | - [x] Design Complete |
| **Test Plan Creation** | BATS tests for all matching scenarios | - [ ] Test Plan Approved |
| **TDD Implementation** | peon.sh Python block + config.json + peon.ps1 | - [ ] Implementation Complete |
| **Integration Testing** | Full test suite | - [ ] Integration Tests Pass |
| **Documentation** | Handled by docs card (step 3) | - [ ] Documentation Complete |
| **Code Review** | PR review | - [ ] Code Review Approved |

## TDD Implementation Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Tests** | BATS: match, no-match, first-wins, missing-pack, glob, empty, override | - [ ] Failing tests are committed and documented |
| **2. Implement Feature Code** | fnmatch logic in Python block, config.json update, peon.ps1 | - [ ] Feature implementation is complete |
| **3. Run Passing Tests** | bats tests/peon.bats | - [ ] Originally failing tests now pass |
| **4. Refactor** | Ensure clean integration with existing pack selection | - [ ] Code is refactored for clarity and maintainability |
| **5. Full Regression Suite** | bats tests/ | - [ ] All tests pass (unit, integration, e2e) |

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | Pending |
| **Testing** | Pending |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Technical Debt Created?** | None expected — clean insertion point |
| **Future Enhancements** | Per-path rotation (explicitly out of scope per design) |

### Completion Checklist

* [ ] All acceptance criteria are met and verified.
* [ ] All tests are passing (unit, integration, e2e, performance).
* [ ] Code review is approved and PR is merged.
* [ ] Documentation is updated (README, API docs, user guides).
* [ ] Follow-up actions are documented and tickets created.
