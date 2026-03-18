The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Harden Windows atomic state I/O edge cases
Type: BACKLOG
Sprint: none
Files touched: install.ps1 (embedded peon.ps1 hook)
Items:
- L1: `Write-StateAtomic` has a non-atomic window between `[IO.File]::Delete` and `[IO.File]::Move`. On PS 7+ this could use `Move-Item -Force` which is truly atomic. Add a PS version check to use the safer path when available. Low risk given sub-millisecond window but worth hardening.
- L2: The safety timer fires `[Environment]::Exit(1)` which skips `finally` blocks and cleanup. If state has been partially written, it could leave a `.tmp` file behind. Consider whether `exit 1` (which runs trap handlers) would be safer, or add a `.tmp` cleanup check on next startup in `Read-StateWithRetry`.
