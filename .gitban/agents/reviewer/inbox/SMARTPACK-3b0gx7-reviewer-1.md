---
verdict: APPROVAL
card_id: 3b0gx7
review_number: 1
commit: 4fe6e8c
date: 2026-03-15
has_backlog_items: false
---

## Review: sweep stale active_pack references in test fixtures

Commit `4fe6e8c` replaces 90 inline config JSON occurrences of `"active_pack"` with `"default_pack"` across 10 test fixture files. The change is mechanical, correctly scoped, and preserves the migration compatibility tests at line 3058+ in `peon.bats`.

### Verification

- All 90 removed lines contain `"active_pack"` in fixture JSON; all 90 replacement lines contain `"default_pack"`. The direction is consistent throughout.
- The 4 remaining `"active_pack"` references in `peon.bats` (lines 3078, 3093, 3182, 3223) are in the migration compatibility section testing the `default_pack -> active_pack -> "peon"` fallback chain. These are intentionally preserved.
- `tests/setup.bash` already uses `"default_pack"` as the default fixture config key -- no change needed.
- The test name `"empty pack_rotation falls back to active_pack"` was updated to `"empty pack_rotation falls back to default_pack"`, and two inline comments referencing `active_pack` in non-migration context were also updated. Both are correct.

### Checkbox audit

- [x] "All planned changes are implemented" -- confirmed, 90/90 occurrences replaced.
- [ ] "Changes are tested/verified" -- unchecked. Card notes tests cannot be run locally on Windows. Acceptable given this is a pure fixture rename with no logic changes; CI will validate.
- [ ] "Documentation is updated" -- unchecked, marked N/A. Correct: test-only changes need no doc updates.

### Standards assessment

- **DRY**: No duplication introduced. The fixture pattern is inherently repetitive (each test creates its own config), which is correct for test isolation.
- **TDD**: This is a test-only change. No production code is modified in this commit, so no corresponding test changes are needed beyond the changes themselves.
- **Security**: No secrets, no injection vectors. Pure string replacement in test fixtures.

### Close-out actions

None. Clean approval.
