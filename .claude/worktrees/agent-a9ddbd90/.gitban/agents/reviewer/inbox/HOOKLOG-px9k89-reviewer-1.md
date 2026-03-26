---
verdict: REJECTION
card_id: px9k89
review_number: 1
commit: a768c0c
date: 2026-03-26
has_backlog_items: false
---

## BLOCKERS

### B1: Merge conflict resolution created duplicate, unreachable case blocks

The merge commit (`a768c0c`) combined the feature branch (`f82d6c9`) with the sprint branch (`4152877`), but both branches contained `debug)` and `logs)` case arms inside the same `case "${1:-}" in` block. Shell `case` matches the first pattern it encounters and skips all subsequent duplicates, so:

- **First `debug)` at line 2685** (from earlier sprint work) -- always matched.
- **Second `debug)` at line 3181** (from this card) -- dead code. Never reached.
- **First `logs)` at line 2745** (from earlier sprint work) -- always matched. Has `--last`, `--session`, `--clear` but **no `--prune`**.
- **Second `logs)` at line 3232** (from this card) -- dead code. Never reached. This is where `--prune` lives.

The entire purpose of this card -- `peon logs --prune` -- is unreachable. Running `peon logs --prune` will hit the first `logs)` block which has no `--prune` handler, falling through to its `*)` wildcard which prints a usage error.

**Refactor plan:** The two `logs)` blocks must be merged into one. The first `logs)` block (lines 2745-2817) should absorb the `--prune` handler from the second block (lines 3235-3260). Same for the two `debug)` blocks -- reconcile into one. Delete the dead duplicates entirely.

Additionally, the implementations have behavioral divergences that need reconciling:
- The first `logs --session` greps for `session=` (correct, matches log format at line 3486: `log('hook', event=event, session=session_id, ...)`). The second greps for `session_id=` (wrong, will never match any log entry).
- The first `logs --last` reads across all log files (`sort | xargs cat | tail -n`). The second reads only the single most recent file (`ls -t | head -1`).
- The first `logs --clear` has a confirmation prompt (`[y/N]`). The second silently deletes everything without confirmation.
- The first `logs` (bare) shows today's log. The second defaults to `--last` behavior.

When merging, keep the richer implementations from the first block and add `--prune` from the second.

### B2: Auto-prune spawns an extra Python process on every non-suppressed hook invocation

Lines 4289-4296 run a Python interpreter solely to check `cfg.get('debug', False)` on every hook event that passes the `PEON_EXIT` guard. The main Python block (which already runs earlier in the same invocation) loads the config and could trivially emit `PEON_DEBUG_ENABLED=true` as a shell variable, the same way it emits `PEON_EXIT`, `SOUND_FILE`, etc. Spawning a second Python process adds ~50-100ms of latency to every hook invocation for a feature that most users have disabled.

Lines 4298-4305 spawn a *third* Python process (inside the backgrounded subshell) just to read `debug_retention_days`. This is the same config that was already loaded by both prior Python invocations.

**Refactor plan:** Have the main Python block emit `PEON_DEBUG_ENABLED` and `PEON_DEBUG_RETENTION_DAYS` as shell variables. The auto-prune block then becomes:

```bash
if [ "${PEON_DEBUG_ENABLED:-false}" = "true" ]; then
  ( _prune_old_logs "${PEON_DEBUG_RETENTION_DAYS:-7}" ) &>/dev/null &
fi
```

Zero extra Python processes. The same pattern is used for every other config value in this codebase.

### B3: No evidence of test execution on the merged result

The card's TDD workflow shows "Full Regression Suite" as unchecked (`[ ]`). The feature commit (`f82d6c9`) was authored on the feature branch where tests presumably passed, but the merge commit (`a768c0c`) introduced structural conflicts (duplicate case blocks) that would cause the new `--prune` tests to fail. Given that B1 makes `--prune` unreachable, the tests for `--prune` cannot be passing on the merged branch.

**Refactor plan:** After fixing B1, run `bats tests/` on the merged branch and confirm all tests pass. Include the output.

## FOLLOW-UP

None. The core implementation (`_prune_old_logs`, auto-prune on invocation, test coverage) is solid. The problems are entirely in how the merge was resolved.
