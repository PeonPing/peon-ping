# Feature Card

**When to use this template:** Port the `path_rules` pack selection feature from peon.sh (Unix) to peon.ps1 (Windows native hook engine).

---

## Problem Statement

The peon.sh (Unix) pack selection hierarchy includes `path_rules` as layer 3:
`session_override > path_rules > pack_rotation > default_pack`

The peon.ps1 (Windows, embedded in install.ps1) does NOT implement `path_rules`. Its hierarchy is:
`session_override > pack_rotation > active_pack`

This means Windows users cannot use glob-based CWD-to-pack assignment, which is documented in config.json and README.md as a supported feature.

## Proposed Solution

Port the path_rules matching logic from peon.sh lines 2992-3002 to the pack selection block in install.ps1 lines 719-774. The implementation should:

1. Read `path_rules` from config (array of `{pattern, pack}` objects)
2. Match event `cwd` against patterns using PowerShell `-like` operator (equivalent to Python `fnmatch`)
3. First match wins
4. Validate the matched pack directory exists before using it
5. Insert path_rules check between session_override and pack_rotation in the hierarchy

## Acceptance Criteria

- [ ] path_rules matching implemented in peon.ps1 (install.ps1 here-string)
- [ ] First-match-wins semantics
- [ ] Missing pack directory in path_rules falls through gracefully
- [ ] Missing cwd in event JSON skips path_rules
- [ ] path_rules beats pack_rotation but loses to session_override
- [ ] Pester tests added for all 4 deferred scenarios from frjune card (scenarios 4-7)
- [ ] Existing peon-packs.Tests.ps1 tests still pass

## References

- Original card: frjune (step 2D pack selection tests)
- peon.sh path_rules logic: lines 2992-3002
- peon.ps1 pack selection: install.ps1 lines 719-774
- Config key: `path_rules` in config.json (already defined, just unused on Windows)

## Test Plan

- [ ] Scenario 4: path_rules glob match selects pack
- [ ] Scenario 5: path_rules first-match-wins when multiple rules match
- [ ] Scenario 6: path_rules skipped when cwd missing from event
- [ ] Scenario 7: path_rules pack directory missing falls through
- [ ] Scenario: path_rules beats pack_rotation
- [ ] Scenario: session_override beats path_rules
