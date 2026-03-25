The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Harden Pester test helper argument handling
Type: FASTFOLLOW
Sprint: WINTRAIN
Files touched: tests/trainer-windows.Tests.ps1
Items:
- L2: `Invoke-PeonCli` constructs arguments via string concatenation (`"'" + $_ + "'"`) which would break if any argument contained a single quote. Refactor to use proper PowerShell array splatting with `& powershell.exe -File $script -args` or equivalent safe quoting. Not a problem today (exercise names and numbers are simple strings) but a fragility worth fixing.
