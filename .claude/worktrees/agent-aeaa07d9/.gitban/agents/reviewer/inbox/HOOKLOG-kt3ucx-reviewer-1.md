---
verdict: REJECTION
card_id: kt3ucx
review_number: 1
commit: a5f3471
date: 2026-03-26
has_backlog_items: true
---

## BLOCKERS

### B1: Tests were not executed -- no evidence of a passing test suite

The card's work summary explicitly states: "BATS tests could not be run locally (Windows worktree, no bats available). Syntax validation passed (bash -n peon.sh)."

`bash -n` checks parse syntax only. It does not execute a single line of code. The 13 new BATS tests have never been run. We have zero evidence that these tests pass, that the implementation matches what the tests assert, or that existing tests still pass after 130 lines of new `peon.sh` code.

This violates the non-negotiable "Test plan fully executed" principle. "Trust me, it works" is not verification, and syntax-checking is not test execution.

**Refactor plan:** Run `bats tests/` in a macOS or Linux environment (the CI runner, a devcontainer, or WSL2) and provide the output demonstrating all tests pass -- both the 13 new tests and the full existing suite. If any tests fail, fix them before resubmitting.

### B2: No BATS test for `peon update` config backfill of debug keys

Acceptance criterion "[x] peon update backfills debug and debug_retention_days config keys" is checked, but there is no test covering this behavior. The existing test suite has no test that starts with a config missing these keys, runs `peon update`, and verifies they were added. This is a TDD gap: a checked acceptance criterion with no corresponding test.

This matters beyond ceremony because the backfill has a real bug (see B3) that a test would have caught.

**Refactor plan:** Add a BATS test that:
1. Creates a config.json without `debug` or `debug_retention_days` keys.
2. Runs `peon update` (may need mocking the install.sh fetch -- follow existing update test patterns).
3. Asserts both keys are present with correct default values.

### B3: `peon update` migration message is incorrect when only debug keys are backfilled

The backfill logic sets `changed = True` when adding `debug` or `debug_retention_days`, then prints:

```
peon-ping: config migrated (active_pack -> default_pack, agentskill -> session_override)
```

This message fires even when no active_pack or agentskill migration occurred -- only the debug key backfill ran. A user running `peon update` on a config that already went through the rename migrations will see a message about migrations that did not happen.

**Refactor plan:** Either make the print message generic (e.g., "peon-ping: config updated") or track which specific migrations fired and print accordingly. The simplest fix is changing the message to something accurate like "peon-ping: config keys updated" since the original rename migrations are legacy at this point.

## FOLLOW-UP

### L1: `debug_retention_days` config key is defined but has no implementation

The key is added to `config.json` and backfilled in `peon update`, but nothing in this diff or the existing codebase reads it to prune old log files. This is fine if a subsequent card (step 4B or similar) implements log rotation, but the key's presence in the default config implies behavior that does not exist. Verify a card exists for the retention/cleanup logic; if not, create one.

### L2: `peon logs --session` only searches today's log file

The current implementation greps only today's `peon-ping-YYYY-MM-DD.log`. If a user wants to find a session that started yesterday but continued today, they would need to manually inspect older files. This is by design per the card spec, but consider adding `--session ID --all` or similar in a future enhancement.
