The reviewer flagged 3 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

Note: L3 below is the same issue as the volume regex trailing comma item from review 1 (already captured in WINTEST-f4w9gu-planner-1.md). The planner should deduplicate and fold L3 into the existing card if one was created, or merge it into this new card.

### Card 1: Deduplicate install.ps1 shared functions and harden volume regex replacement
Type: FASTFOLLOW
Sprint: WINTEST
Files touched: install.ps1, install-utils.ps1
Items:
- L1: `Get-PeonConfigRaw` is defined in `install-utils.ps1` (dot-sourced at line 18) and redeclared in install.ps1 at line 326. The hook-mode version is intentionally simpler (no locale repair), but `Get-ActivePack` at line 333 is identical to the utils version. Consider parameterizing `Get-PeonConfigRaw` with a `-Repair` switch to eliminate redeclaration, or extract hook-mode's version as `Get-PeonConfigRawFast` in the utils file.
- L2: `$peonDebug` is assigned at line 323 (CLI command mode) and again at line 730 (hook mode). Both are in the same PowerShell scope, so the second assignment is redundant. Hoist the single declaration above both code paths, or move it into a shared init block.
- L3: The volume regex replacement at line 696 always adds a trailing comma after the volume value. If volume is the last key before `}`, this produces `"volume": 0.5,}` which is invalid JSON. Consider preserving the original comma presence via a capture group in the regex, or switching to a parse-modify-serialize approach for the `--volume` command. (Duplicate of review 1 L1 -- deduplicate against existing card.)
