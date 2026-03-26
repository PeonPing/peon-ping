The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

### Card 1: Optimize _peon_log python3 fallback and harden ms precision test
Sprint: HOOKLOG
Files touched: peon.sh, tests/peon.bats
Items:
- L1: python3 fallback in `_peon_log` has per-call process spawn overhead (~30-50ms per call). On stock macOS without GNU coreutils, every `_peon_log()` call launches a `python3 -c` process. Consider caching the ms offset at definition time or using `date +%s` with arithmetic to stay within ADR-002's 5ms logging budget.
- L2: ms precision test is technically non-deterministic. The test asserts at least one of 3 invocations has non-zero milliseconds. If CI flakiness is ever observed, consider asserting the timestamp format matches `\.[0-9]{3}` (proving real digits are emitted) without requiring non-zero values.
