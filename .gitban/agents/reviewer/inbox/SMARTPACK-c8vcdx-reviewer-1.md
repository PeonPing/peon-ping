---
verdict: APPROVAL
card_id: c8vcdx
review_number: 1
commit: 624e7e1
date: 2026-03-13
has_backlog_items: false
---

## Review: step-3-path-rules-cli-and-status-output

This commit adds active path rule display to `peon status` output. When `path_rules` are configured and one matches the current working directory, the status now prints `path rule: <pattern> -> <pack>` above the existing rules count line. The change is 10 lines of Python in the embedded status block and 18 lines of BATS tests.

### What was reviewed

**peon.sh (status Python block, ~line 947):** The implementation imports `fnmatch`, iterates `path_rules` from config, and prints the first matching rule. The logic mirrors the matching pattern from `docs/plans/2026-02-19-path-rules-design.md` (first-match-wins via `fnmatch.fnmatch`). The underscore-prefixed variable names (`_fnm`, `_cwd`, `_matched`, `_r`, `_pat`) are consistent with the convention in the embedded Python block for avoiding namespace collisions.

**tests/peon.bats:** Two new tests:
1. "status shows active path rule when cwd matches" -- binds with wildcard `*`, verifies both the active rule line and the count line appear.
2. "status shows path rules count but no active rule when cwd does not match" -- binds with a non-matching pattern, verifies the count line appears but the singular `path rule:` line does not.

Both tests are behavioral (verify user-visible output), not implementation-bound. The negative test correctly distinguishes `path rule:` (singular, active match) from `path rules:` (plural, count) since the "s" before the colon breaks substring matching.

### Standards assessment

- **TDD:** Tests cover both branches (match and no-match). The tests exercise the full `peon status` command end-to-end through the shell, not mocked internals.
- **Design doc compliance:** The output format (`path rule: <pattern> -> <pack>`) matches the design doc's specification. The ASCII `->` instead of unicode arrow is a reasonable portability choice.
- **DRY:** No duplication introduced. The matching logic is a local concern of the status block and does not duplicate the runtime matching in the event handler (which has different downstream behavior).
- **Security:** No concerns -- reads config values and prints them; no user input injection path.
- **DaC:** Documentation updates are explicitly deferred to a separate docs card, which is tracked and noted in the card's acceptance criteria.

### BLOCKERS

None.

### BACKLOG

None.
