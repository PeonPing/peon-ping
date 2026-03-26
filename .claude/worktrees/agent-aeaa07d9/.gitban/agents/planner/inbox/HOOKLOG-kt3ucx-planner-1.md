The reviewer flagged 2 non-blocking items, grouped into 2 cards below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

### Card 1: Implement debug_retention_days log rotation logic
Sprint: HOOKLOG
Files touched: peon.sh (or new script), tests/peon.bats
Items:
- L1: `debug_retention_days` config key is defined in config.json and backfilled in `peon update`, but nothing in the codebase reads it to prune old log files. The key's presence in the default config implies behavior that does not exist. Implement log rotation that respects this setting (e.g., delete log files older than N days on hook invocation or via `peon logs --prune`). Verify no existing card already covers this; if one does (e.g., step 4B), deduplicate.

### Card 2: Enhance peon logs --session to search across multiple days
Sprint: HOOKLOG
Files touched: peon.sh, tests/peon.bats
Items:
- L2: `peon logs --session ID` only searches today's log file (`peon-ping-YYYY-MM-DD.log`). If a session spans midnight, entries in older files are missed. Consider adding `--session ID --all` or similar flag that searches across all log files. This is a future enhancement to improve the debugging experience.
