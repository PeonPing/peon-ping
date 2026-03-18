The reviewer flagged 2 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.

### Card 1: DRY up peon.sh state helpers and optimize first-run read path
Type: BACKLOG
Sprint: none
Files touched: peon.sh
Items:
- L1: The three copies of `_write_state`/`_read_state` in `peon.sh` (lines 2586, 2671, 2865) are identical. If the retry delays, temp file strategy, or error handling ever need to change, all three must be updated in sync. Consider extracting a shared Python snippet file that gets inlined during install, or refactoring the trainer commands to share the main Python block's helpers via a different execution model.
- L2: `read_state()` retries on `FileNotFoundError` (file does not exist), adding up to 350ms of unnecessary delay on a clean first run when no `.state.json` exists yet. Consider checking `os.path.exists(path)` before the retry loop, or catching only `json.JSONDecodeError` and `IOError`/`PermissionError` in the retry path while letting `FileNotFoundError` fall through to return `{}` immediately.
