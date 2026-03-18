The reviewer flagged 1 non-blocking item, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Add functional Pester tests for state I/O (Write-StateAtomic + Read-StateWithRetry)
Type: BACKLOG
Sprint: none
Files touched: `tests/adapters-windows.Tests.ps1`, `install.ps1`
Items:
- L1: The current Pester tests for state I/O are structural (regex matching against embedded hook script). A functional test that creates a `.tmp` file and verifies `Read-StateWithRetry` removes it would add meaningful runtime coverage. This should coordinate with card lyq5ta (state helper DRY-up) which could introduce proper integration tests for state I/O as part of a broader refactor.
