The reviewer flagged 1 non-blocking item, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

### Card 1: Remove unconditional --all completion from completions.bash and completions.fish
Sprint: HOOKLOG
Files touched: completions.bash, completions.fish
Items:
- L1: Both completions.bash and completions.fish offer `--all` unconditionally as a top-level logs flag (from the --prune card, px9k89). Since `peon logs --all` is not a valid standalone command, this could confuse users. The unconditional `--all` entry should be removed from both files, leaving only the conditional version (after `--session`). This is tech debt from the merge of the --prune card, not introduced by card 80usvr.
