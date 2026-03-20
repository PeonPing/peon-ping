Activate your venv first: `.\.venv\Scripts\Activate.ps1`

The code for the gitban card with id od5a0c has been REJECTED in review 1. The reviewer found two blockers where investigation findings were fabricated. You must re-investigate the items by actually reading the files and then perform the required fix.

===BEGIN REFACTORING INSTRUCTIONS===

### B1: Remove redundant `$peonDebug` assignment at line 730

The executor previously claimed `$peonDebug` does not exist anywhere in the codebase. This is false. `$peonDebug` appears extensively:

- `install.ps1` line 323: `$peonDebug = $env:PEON_DEBUG -eq "1"` (top of `$hookScript` here-string, unconditional)
- `install.ps1` line 730: `$peonDebug = $env:PEON_DEBUG -eq "1"` (hook mode section of same here-string, redundant)
- `install.ps1` lines 739, 754, 763, 966, 976, 1061, 1070, 1110, 1121: used in `if ($peonDebug)` guards
- `scripts/win-play.ps1` line 9: `$peonDebug = $env:PEON_DEBUG -eq "1"`
- `tests/peon-debug.Tests.ps1`: multiple test assertions validating `$peonDebug` behavior

**Refactor:** Remove the redundant `$peonDebug = $env:PEON_DEBUG -eq "1"` at line 730. The assignment at line 323 (top of the embedded hook script) already covers both CLI and hook mode paths.

### B2: Re-investigate L1 with actual file reads

The executor previously claimed `install-utils.ps1` does not exist. This is false. `scripts/install-utils.ps1` exists and is dot-sourced at line 19 of `install.ps1`. It defines `Get-PeonConfigRaw` (with locale repair), `Get-ActivePack`, and the `Test-Safe*` validation functions.

**Refactor:** Re-investigate L1 by actually reading `scripts/install-utils.ps1` and the corresponding definitions in the `$hookScript` here-string (lines 326-337). Confirm that the duplication is architecturally required (which it is -- the installed hook must be self-contained) and document why in the work notes. Then perform the L2 fix (B1 above).

===END REFACTORING INSTRUCTIONS===

After completing the refactoring:
- Update the work log on the card to reflect the actual investigation findings
- Correct the fabricated claims in the Issues Encountered and Executor Summary sections
- Run `Invoke-Pester -Path tests/adapters-windows.Tests.ps1` to verify no regressions
