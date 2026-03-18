---
verdict: APPROVAL
card_id: 9pjhy5
review_number: 1
commit: a18a0ec
date: 2026-03-14
has_backlog_items: true
---

## Summary

This merge commit integrates the Windows path_rules CLI parity work (bind/unbind/bindings subcommands in `install.ps1`) with the sprint branch's existing `Get-ActivePack` refactor. The conflict resolution correctly threads `$pathRulePack` fallback through every branch that previously called `Get-ActivePack` directly.

The commit also includes an unrelated but clean change to `peon.sh`: suppressing sounds for non-interactive Claude sessions (`sdk-cli` entrypoint), with 4 BATS tests covering the behavior.

## Code Assessment

**Runtime matching engine (install.ps1 lines 953-969):** Correct. The `foreach` over `$config.path_rules` with `-like` pattern matching, directory existence check, and `break` on first hit faithfully implements the design doc's first-match-wins semantics. The `-like` operator limitation (no `[seq]` support vs Python `fnmatch`) is documented in the card and is an acceptable starting point given that `*` wildcards are the common case.

**Override hierarchy integration (install.ps1 lines 971-1018):** The merge resolution is correct. Three fallback sites within the `agentskill`/`session_override` block now use `if ($pathRulePack) { $pathRulePack } else { Get-ActivePack $config }` instead of bare `Get-ActivePack $config`. The `elseif ($pathRulePack)` at line 1012 correctly slots path_rules between session_override and pack_rotation, matching the design doc's 5-layer hierarchy.

**CLI commands (bind/unbind/bindings):** Functionally sound port from the Unix implementation. The arg parsing via `[Parameter(ValueFromRemainingArguments)]$ExtraArgs` is a reasonable PowerShell idiom for handling `--pattern` and `--install` flags beyond the 3 positional params. The upsert logic (update existing rule for same pattern, append otherwise) matches Unix behavior.

**Status display:** Correctly shows active path rule when matched or rule count when not, consistent with Unix `peon status`.

**sdk-cli suppression (peon.sh):** Clean gate with an escape hatch (`PEON_ALLOW_HEADLESS=1`). Positioned correctly before stdin reading. The 4 BATS tests cover the matrix: suppressed, interactive, unset, and override.

**Tests:** 32 new Pester tests (9 structural matching, 13 structural CLI, 10 functional CLI) plus 4 new BATS tests. The functional Pester tests create isolated environments with mock packs and actually invoke the hook script via `powershell.exe -NoProfile`, which is the right level of integration testing. The merge correctly updated the structural test from checking inline `default_pack`/`active_pack` fallback to checking `Get-ActivePack $config`.

## BLOCKERS

None.

## BACKLOG

**L1: `--install` flag downloads sounds one-at-a-time without parallelism or progress feedback.** The `bind --install` code (lines 484-518) fetches the registry, manifest, and then each sound file sequentially via `Invoke-WebRequest`. For packs with 40+ sounds this could take 30+ seconds with no output. The Unix side delegates to `pack-download.sh` which handles this better. Consider extracting a shared `Install-Pack` function or calling pack-download logic. No functional test covers `--install` end-to-end (only structural test confirms the flag is parsed).

**L2: `$i++` inside PowerShell `switch` within a `for` loop.** At line 472, `$i++` is used inside a `switch` block to skip the next argument after `--pattern`. In PowerShell, modifying the loop variable inside a `switch` body within a `for` loop works correctly (unlike some other languages), but this pattern is subtle. A comment noting the intentional skip would help future maintainers.

**L3: Duplicated config I/O pattern across bind/unbind/bindings.** Each subcommand independently does `Get-Content $ConfigPath -Raw | ConvertFrom-Json`, manipulates `path_rules`, then `ConvertTo-Json | Set-Content`. This is the same pattern 3 times. Consider a helper like `Update-PeonConfig { param($Mutator) ... }` to reduce duplication. Not a DRY blocker since the logic inside each is distinct, but worth tracking.
