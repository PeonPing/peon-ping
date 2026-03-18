The reviewer flagged 1 non-blocking item, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Fix BATS test Python fallback timing division bug
Type: FASTFOLLOW
Sprint: TECHDEBT2
Files touched: `tests/peon.bats`
Items:
- L1: The Python fallback path in the BATS timing computation (`python3 -c "import time; print(int(time.time()*1000))"`) produces milliseconds, but the outer arithmetic divides by 1,000,000 (correct for nanoseconds from `date +%s%N`, wrong for the Python fallback). On platforms where `date +%s%N` is unsupported and the Python fallback fires, both `start_ms` and `end_ms` would be near zero, making the timing assertion trivially true. Fix the division to handle both code paths correctly.
