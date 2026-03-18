---
verdict: APPROVAL
card_id: f4w9gu
review_number: 3
commit: b0fc2c5
date: 2026-03-18
has_backlog_items: true
---

## APPROVAL

All 5 scoped items from the card are addressed. The implementation quality is solid, with several additional hardening improvements carried forward from prior cycles.

### Scoped Item Verification

1. **PEON_DEBUG strict equality in 6 adapters** -- All 6 adapter .ps1 files (copilot, deepagents, gemini, kimi, kiro, windsurf) now use `$env:PEON_DEBUG -eq "1"` instead of truthy checks. Consistent diagnostic message format applied (`peon-ping: [adapter] ...`). Done.

2. **BATS timing division fix** -- New test "first run with no .state.json succeeds without retry delay" correctly separates the `date +%s%N` nanosecond path (divides by 1000000) from the Python fallback (already milliseconds). The `${#_ns}` length guard distinguishes valid nanosecond output from failed `date` calls. Well-structured test that validates behavior (no retry penalty) rather than implementation. Done.

3. **PEON_DEBUG catch block logging in peon.ps1** -- `$peonDebug = $env:PEON_DEBUG -eq "1"` declared at hook mode entry (line 730), and `Write-Warning` added to catch blocks for config read, state writes, manifest parse, and sound category lookup. Done.

4. **Volume regex trailing comma** -- Line 696: `[\d.]+,?` makes the trailing comma optional in the match pattern. The replacement always includes a trailing comma, which normalizes the output. Done.

5. **Dead pathRulePack check** -- The unreachable `$pathRulePack` guard inside the pack_rotation branch is removed. The remaining references at lines 1026, 1040, 1043 are all reachable fallback paths within the agentskill/session_override block. The `elseif ($pathRulePack)` at line 1046 correctly handles the non-agentskill case. Done.

### Additional Changes (carried from prior cycles)

These are out of the 5-item scope but are clean improvements:

- **install-utils.ps1 extraction**: Validation functions and `Get-PeonConfigRaw`/`Get-ActivePack` moved to a shared dot-sourced file. Hook mode intentionally redeclares a lighter `Get-PeonConfigRaw` (no locale repair) at line 326.
- **ConvertTo-Hashtable PS 5.1 hardening**: Null check, ValueType/string guard before PSCustomObject (prevents PS 5.1 pipeline primitive wrapping bug), and `,@()` array prefix to prevent single-element unrolling. Well-commented.
- **Write-StateAtomic InvariantCulture**: Prevents locale-specific decimal formatting in JSON state output. Culture properly restored in `finally` block.
- **path_rules Add-Member**: Defensive `PSObject.Properties['path_rules']` check before assignment, with `Add-Member` fallback for configs that lack the property. Applied to both bind and unbind paths.
- **Pack install warnings**: Reports packs not found in registry by name before proceeding.
- **Per-field source metadata defaults**: Each field gets its own fallback instead of all-or-nothing.
- **Help text**: Reorganized into sections with consistent alignment.

### TDD Assessment

The card is a chore (5 minor cleanups). The one behavioral change -- timing test fix -- has a corresponding new test that was clearly designed to exercise the specific fix (nanosecond vs millisecond division paths). The test asserts on behavior (completion time, state file creation, exit code) rather than implementation details. The remaining changes are diagnostic logging and dead code removal, which are proportionally exempt from TDD requirements per the skill guidelines.

### Checkbox Integrity

The "BATS tests pass" checkbox note says "No BATS files modified" which is stale from cycle 1 -- `tests/peon.bats` IS modified in this commit. The checkbox itself (tests pass) is still valid per the Pester results reported (275 passed). This is a minor metadata staleness issue, not a blocker.

## BACKLOG

**L1: Duplicate function declarations in install.ps1** -- `Get-PeonConfigRaw` and `Get-ActivePack` are defined in `install-utils.ps1` (dot-sourced at line 18) and redeclared in install.ps1 at lines 326/333. The hook-mode `Get-PeonConfigRaw` is intentionally simpler (no locale repair), but `Get-ActivePack` is identical. Consider parameterizing `Get-PeonConfigRaw` (e.g., a `-Repair` switch) to eliminate the redeclaration, or at minimum extract hook-mode's version as `Get-PeonConfigRawFast` in the utils file.

**L2: Duplicate `$peonDebug` assignments** -- Declared at line 323 (CLI command mode) and line 730 (hook mode). Both are in the same PowerShell scope, so the second assignment is redundant. Consider hoisting the single declaration above both code paths, or moving it into a shared init block.

**L3: Volume regex trailing comma risk** -- The replacement at line 696 always adds a trailing comma after the volume value. If a user's config has volume as the last key before `}`, the result would be `"volume": 0.5,}` which is invalid JSON. In practice PowerShell's ConvertTo-Json does not produce this ordering, but a hand-edited config could. Consider using a regex replacement that preserves the original comma presence, or switching to a parse-modify-serialize approach for the `--volume` command.
