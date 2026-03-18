The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: Add CI lint check for python3 -c bash quoting hazards
Type: BACKLOG
Sprint: none
Files touched: CI config (new), potentially tests/
Items:
- L1: Add a CI lint check (shellcheck custom rule or BATS test) that detects `python3 -c "` blocks containing `["` or `.get("` patterns, to prevent regression of the quoting bug class fixed in card dsmh31. The card's own "Process Improvements" section already identified this opportunity.
