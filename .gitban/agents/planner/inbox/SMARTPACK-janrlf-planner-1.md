The reviewer flagged 2 non-blocking items, grouped into 2 cards below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Upgrade Write-StateAtomic to true atomic overwrite when PS 5.1 is dropped
Type: BACKLOG
Sprint: none
Files touched: peon.ps1
Items:
- L1: Write-StateAtomic uses delete-then-move which has a tiny window where the file does not exist. On PowerShell 7+ `[System.IO.File]::Move($src, $dst, $true)` provides a true atomic overwrite. Revisit when PS 5.1 support is dropped. The current retry-on-read mitigation makes data loss extremely unlikely.

### Card 2: Improve ffmpeg/ffplay install guidance on Windows
Type: BACKLOG
Sprint: none
Files touched: install.ps1, possibly README.md
Items:
- L2: The `winget install ffmpeg` recommendation installs the Gyan build which may not add `ffplay` to PATH automatically. Consider adding a note or linking to project docs if users report confusion about ffplay not being found after installing ffmpeg via winget.
