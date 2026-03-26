The reviewer flagged 3 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

### Card 1: Harden bash-side log helpers (timestamp precision + newline escaping)
Sprint: HOOKLOG
Files touched: peon.sh
Items:
- L1: Timestamp precision loss in bash `_peon_log()` -- hardcodes `.000` milliseconds instead of capturing real ms. Either fix with portable millisecond capture or document as known limitation.
- L3: `_log_quote` does not handle newline characters -- if a value contains a newline, the log line will be split across multiple lines, breaking the one-line-per-phase invariant. Add newline escaping before the format is documented in the README.
