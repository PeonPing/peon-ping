The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

Note: L1 (repeated inline `if (-not $activePack)` pattern) is explicitly moot if blocker B3 is resolved (restoring `Get-ActivePack`), so it is not included here.

### Card 1: Update-PeonConfig skip-write optimization
Type: BACKLOG
Sprint: none
Files touched: install.ps1 (embedded peon.ps1 hook script)
Items:
- L2: `Update-PeonConfig` unconditionally writes config back to disk even when the mutator makes no changes. Consider having the mutator return a changed flag or comparing before/after JSON to skip unnecessary disk I/O.
