# Task Overview

Port the `path_rules` pack selection feature from peon.sh (Unix) to peon.ps1 (Windows native hook engine, embedded in install.ps1). Currently the Windows engine does not implement path_rules, leaving a feature gap vs Unix.

**Origin:** Deferred from frjune (step 2D pack selection tests). Scenarios 4-7 (path_rules glob match, first-match-wins, missing cwd, missing pack directory) could not be tested because the feature does not exist in peon.ps1.

**Scope:**
- Implement path_rules matching in install.ps1 pack selection block (lines 719-774)
- Read `path_rules` from config, match event `cwd` with `-like` operator
- Insert between session_override and pack_rotation in hierarchy
- Add Pester tests for scenarios 4-7 from frjune card

**References:**
- peon.sh path_rules logic: lines 2992-3002
- peon.ps1 pack selection: install.ps1 lines 719-774
- Config key: `path_rules` in config.json (defined but unused on Windows)
- Existing pack tests: tests/peon-packs.Tests.ps1

## Work Log

- [ ] Implement path_rules matching in peon.ps1 (install.ps1 here-string)
- [ ] Add cwd extraction from event JSON in peon.ps1
- [ ] Add Pester test: path_rules glob match selects pack
- [ ] Add Pester test: first-match-wins when multiple rules match
- [ ] Add Pester test: path_rules skipped when cwd missing from event
- [ ] Add Pester test: missing pack directory falls through
- [ ] Add Pester test: path_rules beats pack_rotation
- [ ] Add Pester test: session_override beats path_rules
- [ ] All existing peon-packs.Tests.ps1 and peon-engine.Tests.ps1 tests pass

## Completion & Follow-up

- [ ] All tests pass locally
- [ ] Commit with conventional commit message
