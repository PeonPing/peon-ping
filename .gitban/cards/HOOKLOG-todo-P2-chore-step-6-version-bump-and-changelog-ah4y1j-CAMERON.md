# step 6: Version bump and changelog

## Task Overview

* **Task Description:** Bump VERSION to next minor (this is a new feature: debug logging + 2 new CLI commands), update CHANGELOG.md with categorized changes from the HOOKLOG sprint, and tag the release.
* **Motivation:** Change enforcement rule: new CLI commands and config keys require a version bump. This is a minor bump — new user-facing feature (structured logging), new CLI commands (peon debug, peon logs), new config keys (debug, debug_retention_days).
* **Scope:** VERSION file, CHANGELOG.md, git tag.
* **Related Work:** All other HOOKLOG cards must be complete before this card executes.
* **Estimated Effort:** 15 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Read current VERSION file to determine next minor version. Read CHANGELOG.md for format. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Determine version (current + minor bump). Draft changelog entry with Added/Fixed sections. | - [ ] Change plan is documented. |
| **3. Make Changes** | (1) Bump VERSION. (2) Add CHANGELOG.md entry at top. (3) Commit. (4) Tag vX.Y.Z. | - [ ] Changes are implemented. |
| **4. Test/Verify** | `bats tests/` and Pester pass. Version file matches tag. | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — changelog IS the documentation. | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Self-review. Do NOT push tags until PR is merged. | - [ ] Changes are reviewed and merged. |

#### Work Notes

**Changelog Entry Template:**
```markdown
## [X.Y.Z] - 2026-03-XX

### Added
- Structured debug logging for hook execution (`peon debug on/off`, `peon logs`)
- 9-phase decision tracing: event routing, config, state, pack selection, sound pick, playback, notification, trainer, exit timing
- Daily log rotation with configurable retention (`debug_retention_days`, default 7)
- `PEON_DEBUG=1` env var override for one-off debugging
- Cross-platform parity: identical log format on Unix and Windows
- Shared test fixtures enforcing format parity between BATS and Pester

### Fixed
- (any bugs found and fixed during sprint)
```

**Dependencies:** ALL other HOOKLOG cards (j6lzi1, 77eri8, w56sog, kt3ucx, unkjkl, r783op) must be done first.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | TBD |
| **Files Modified** | VERSION, CHANGELOG.md |
| **Pull Request** | Part of HOOKLOG sprint branch |
| **Testing Performed** | Full test suites |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | Update homebrew-tap formula URL and SHA256 after release |
| **Documentation Updates Needed?** | No — covered by step 5 |
| **Follow-up Work Required?** | Homebrew tap update (separate, triggered by tag push CI) |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | Tag push CI already handles GitHub Release + Homebrew |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
