The reviewer flagged 2 non-blocking items, grouped into 2 cards below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Remove dead EnumWindows callback code in Get-WindowsByProcessTree
Type: FASTFOLLOW
Sprint: WINFOCUS
Files touched: scripts/win-focus.ps1 (or wherever Get-WindowsByProcessTree is defined)
Items:
- L1: Lines 88-97 of Get-WindowsByProcessTree allocate $foundHwnds, $callback delegate, and $results array that are never used. The EnumWindows/IsWindowVisible/EnumWindowsProc P/Invoke imports in the Add-Type block are declared but never invoked at runtime. Either remove the dead code and unused P/Invoke declarations, or wire up the actual EnumWindows callback as a fallback for complex process trees. If the simpler Get-Process approach proves sufficient, prefer removal.

### Card 2: Add behavioral Pester tests with mocked process trees for focus functions
Type: FASTFOLLOW
Sprint: WINFOCUS
Files touched: tests/adapters-windows.Tests.ps1, focus-related PowerShell scripts
Items:
- L2: The current 20 Phase 2 tests are all AST/string-matching structural tests. The card's test strategy describes mock process trees (linear, branching, orphaned, stale PID) that verify function return values but these were not implemented. Consider extracting the focus functions into a separate module that can be dot-sourced without side effects (no Add-Type or WinRT loading at import time), enabling proper behavioral testing with mocked Get-Process calls.
