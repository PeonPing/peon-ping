The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Improve lint-python-quoting hazard reporting and test scope
Type: FASTFOLLOW
Sprint: TECHDEBT
Files touched: `scripts/lint-python-quoting.sh`, `tests/lint-python-quoting.bats`
Items:
- L1: Lint only reports the first hazard per python3 -c block. Walk the rest of the line after the first unescaped `"` to report all hazard sites for better developer experience.
- L2: The `grep -rl --include='*.sh'` in the "all shell scripts" BATS test does not exclude the `tests/` directory. Currently safe because `.bats` files don't match `*.sh`, but future `.sh` test helpers with intentional bad patterns would false-positive. Add `--exclude-dir=tests` or document why this is safe.
