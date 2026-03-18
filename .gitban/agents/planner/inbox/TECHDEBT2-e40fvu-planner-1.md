The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Extend PEON_DEBUG diagnostics to embedded peon.ps1 early-exit catch blocks and add behavioral test coverage
Type: FASTFOLLOW
Sprint: TECHDEBT2
Files touched: install.ps1, tests/peon-debug.Tests.ps1
Items:
- L1: The `catch { exit 0 }` blocks in embedded peon.ps1 (config read failure, stdin read failure, JSON parse failure, manifest parse failure at lines ~760, 774, 782, 1087) exit silently. Adding `if ($peonDebug) { Write-Warning ... }` before the exit would help users debugging with PEON_DEBUG=1 understand why the hook exited early. Low priority since these are "can't run at all" scenarios.
- L2: The embedded peon.ps1 diagnostic warnings (state write, category check, sound lookup, missing win-play.ps1) are only validated structurally via regex in the current test suite. Behavioral tests that actually trigger these paths would provide stronger guarantees. Requires a more sophisticated test harness that can invoke the embedded script with mock config, state, and manifests.
