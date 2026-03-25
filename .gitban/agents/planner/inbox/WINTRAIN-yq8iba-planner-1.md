The reviewer flagged 3 non-blocking items, grouped into 2 cards below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Extract Format-TrainerBar helper to deduplicate progress bar rendering
Type: FASTFOLLOW
Sprint: WINTRAIN
Files touched: install.ps1 (embedded peon.ps1 trainer block)
Items:
- L2: The `status` and `log` subcommands each independently define `$barWidth`, `$fullBlock`, `$lightShade`, compute `$filled`/`$empty`, and build the bar string. Extract a `Format-TrainerBar` helper function (or scriptblock) above the trainer switch block that takes `$done` and `$goal` and returns the formatted bar string.

### Card 2: Add Pester tests for trainer CLI subcommands
Type: FASTFOLLOW
Sprint: WINTRAIN
Files touched: tests/adapters-windows.Tests.ps1 (or new tests/trainer-windows.Tests.ps1)
Items:
- L3: The trainer subcommands (on, off, status, log, goal, help) were ported without Pester tests. The card explicitly deferred tests to "step 3." Write Pester tests covering the trainer CLI behavior to match the existing BATS coverage in tests/trainer.bats.
