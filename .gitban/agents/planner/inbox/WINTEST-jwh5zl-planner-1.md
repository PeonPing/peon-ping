The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Tighten peon-security.Tests.ps1 assertion precision
Type: FASTFOLLOW
Sprint: WINTEST
Files touched: tests/peon-security.Tests.ps1
Items:
- L1: Scenario 5 does not assert exit code for CLI-mode "pack not found". The test verifies output text but does not check the exit code. Add an exit code assertion (`$r.ExitCode | Should -Be 0` to document current behavior, or `Should -Be 1` if the source is fixed). This also surfaces a potential source bug in hook-handle-use.ps1 where missing packs in CLI mode return exit 0 instead of exit 1 (lines 110-123), inconsistent with other CLI-mode errors (lines 76, 99).
- L2: VLC gain assertion in Scenario 15 uses `Should -Match "--gain 1"` which would also match `--gain 10`, `--gain 100`, etc. Tighten to a pattern like `"--gain 1(\.\d+)?(\s|$)"` or `"--gain 1\.0"`.
