---
verdict: REJECTION
card_id: f4w9gu
review_number: 2
commit: e599be7
date: 2026-03-18
has_backlog_items: true
---

## BLOCKERS

### B1: Dead `$pathRulePack` code not removed -- scoped item left undone

The card's fifth scoped item is: "Remove unreachable `$pathRulePack` check in `install.ps1` pack_rotation branch." The dead code is present in the merged result at lines 1049-1060 of `install.ps1`:

- Line 1046: `elseif ($pathRulePack)` catches the truthy case.
- Line 1049: `elseif ($config.pack_rotation ...)` only enters when `$pathRulePack` is falsy.
- Line 1050: `if ($pathRulePack)` inside that branch is therefore dead -- it will never be true.
- Line 1057: `elseif ($pathRulePack)` is also unreachable because line 1046 already handled it.

The executor's disposition is: "Dead code exists on sprint/WINTEST but not in this worktree's base. Will be resolved at sprint merge time." This is not acceptable. The card was created specifically to fix this dead code. Deferring it to an unspecified "sprint merge time" with no card, no assignee, and no timeline is exactly the kind of promise-without-tracking that the review process exists to prevent. The dead code is in the codebase right now, on the branch this card targets.

**Refactor plan:** Remove the dead branches. The `elseif ($config.pack_rotation ...)` block at line 1049 should drop the inner `if ($pathRulePack)` guard and execute the rotation logic directly (since `$pathRulePack` is guaranteed falsy at that point). The `elseif ($pathRulePack)` at line 1057 should be removed entirely (unreachable). This is a ~6-line deletion with no behavioral change.

### B2: Merge dropped an existing test -- "missing .state.json does not prevent trainer status"

The merge commit (`e599be7`) resolved a conflict in `tests/peon.bats` by dropping the `"missing .state.json does not prevent trainer status"` test that existed on the sprint branch (introduced by commit `0957def`). This test validated that the trainer CLI subcommand handles absent state files gracefully. It is not related to any of the five scoped items on this card and should not have been removed.

Merge conflict resolution that silently deletes unrelated tests is a test regression. The test existed, it passed, and it covered real behavior. Losing it in a merge is not a deliberate design decision -- it is a conflict resolution error.

**Refactor plan:** Restore the deleted test. It can be found at the end of `tests/peon.bats` on `e599be7^1` (the first parent). Append it after the new timing test added by this card.

---

## BACKLOG

### L1: Volume regex replacement still inserts trailing comma unconditionally (carry-forward from review 1)

The replacement string at `install.ps1` line 696 always appends a comma:

```powershell
$updated = $raw -replace '"volume"\s*:\s*[\d.]+,?', "`"volume`": $volStr,"
```

If `volume` is the last JSON key, this produces `"volume": 0.5,}` -- technically malformed JSON. PowerShell tolerates trailing commas so it won't break at runtime, but other JSON parsers would reject it. The fix would be to capture the optional comma in a group and replay it: `'"volume"\s*:\s*[\d.]+(,?)'` with replacement `"volume": $volStr$1`. Low priority since the default config has volume as a non-terminal key.

### L2: BATS timing test is not a true behavioral test

The new "first run with no .state.json succeeds without retry delay" test validates timing (elapsed < 3000ms) and state file creation, which is useful. However, the 3-second threshold is generous enough to be trivially true on any machine. The original bug (Python fallback producing milliseconds divided by 1,000,000 yielding zero) would have made `end_ms - start_ms` equal to zero, which also passes `< 3000`. The test fixes the timing measurement code but does not actually catch the bug it was written to address -- it would pass with both the old and new timing code. Non-blocking since the measurement fix is still correct in isolation; just noting the assertion has no discriminating power.
