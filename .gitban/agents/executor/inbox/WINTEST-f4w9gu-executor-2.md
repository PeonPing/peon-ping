Activate your venv first: `.\.venv\Scripts\Activate.ps1`

===BEGIN REFACTORING INSTRUCTIONS===

### B1: Dead `$pathRulePack` code not removed -- scoped item left undone

The card's fifth scoped item is: "Remove unreachable `$pathRulePack` check in `install.ps1` pack_rotation branch." The dead code is present in the merged result at lines 1049-1060 of `install.ps1`:

- Line 1046: `elseif ($pathRulePack)` catches the truthy case.
- Line 1049: `elseif ($config.pack_rotation ...)` only enters when `$pathRulePack` is falsy.
- Line 1050: `if ($pathRulePack)` inside that branch is therefore dead -- it will never be true.
- Line 1057: `elseif ($pathRulePack)` is also unreachable because line 1046 already handled it.

**Refactor plan:** Remove the dead branches. The `elseif ($config.pack_rotation ...)` block at line 1049 should drop the inner `if ($pathRulePack)` guard and execute the rotation logic directly (since `$pathRulePack` is guaranteed falsy at that point). The `elseif ($pathRulePack)` at line 1057 should be removed entirely (unreachable). This is a ~6-line deletion with no behavioral change.

### B2: Merge dropped an existing test -- "missing .state.json does not prevent trainer status"

The merge commit (`e599be7`) resolved a conflict in `tests/peon.bats` by dropping the `"missing .state.json does not prevent trainer status"` test that existed on the sprint branch (introduced by commit `0957def`). This test validated that the trainer CLI subcommand handles absent state files gracefully. It is not related to any of the five scoped items on this card and should not have been removed.

**Refactor plan:** Restore the deleted test. It can be found at the end of `tests/peon.bats` on `e599be7^1` (the first parent). Append it after the new timing test added by this card.
