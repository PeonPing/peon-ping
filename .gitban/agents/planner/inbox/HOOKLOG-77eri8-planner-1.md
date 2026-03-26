The reviewer flagged 4 non-blocking items, grouped into 1 card below.
Create ONE card per group. Do not split groups into multiple cards.
The planner is responsible for deduplication against existing cards.
All cards go into the current sprint unless marked BLOCKED with a reason.

### Card 1: Harden hook-logging test fixtures and coverage gaps
Sprint: HOOKLOG
Files touched: tests/setup.bash, tests/peon.bats, tests/fixtures/hook-logging/
Items:
- L1: `validate_log_fixture` word-splitting parser breaks on quoted values with spaces. Switch to a proper field extractor (Python one-liner or awk) that respects quoted values so non-wildcard fixture matching works correctly for space-containing fields.
- L3: Config-enable boilerplate (`python3 -c "import json; cfg = json.load(...); cfg['debug'] = True; ..."`) is copy-pasted across 8 test functions. Extract an `enable_debug_logging` helper into `setup.bash` to DRY up the fixture tests.
- L4: "Missing audio backend" test exercises the happy path (mock afplay present) rather than the actual error path. Add a test that removes mock audio backends from PATH to trigger and validate the `[play] error=` logging branch, fulfilling the PRD-002 acceptance criterion.
