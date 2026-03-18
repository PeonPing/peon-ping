The reviewer flagged 3 non-blocking items, grouped into 2 cards below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Sweep stale active_pack references in test fixture configs
Type: FASTFOLLOW
Sprint: SMARTPACK
Files touched: tests/peon.bats, tests/wsl-toast.bats, tests/mac-overlay.bats, tests/relay.bats, tests/windsurf.bats, tests/kiro.bats, tests/install.bats, tests/install-windows.bats, tests/deepagents.bats, tests/copilot.bats
Items:
- L1: Dozens of test files still use `"active_pack": "peon"` in their inline config JSON. These tests pass today because `peon.sh` has a `c.get('default_pack', c.get('active_pack', 'peon'))` fallback chain, but they represent stale test fixtures that will mask future regressions if the fallback is ever removed. Sweep all fixture configs from `active_pack` to `default_pack`.

### Card 2: Audit embedded Python blocks in peon.sh for bash double-quoting hazards
Type: BACKLOG
Sprint: none
Files touched: peon.sh
Items:
- L3: The root cause of test 567 -- double quotes inside `python3 -c "..."` -- is a recurring hazard throughout `peon.sh`. The status block is now fixed, but the same pattern (dict access with `["key"]` inside bash double-quoted Python) could exist elsewhere. Audit all `python3 -c` blocks for this class of quoting issue and fix any remaining instances.
