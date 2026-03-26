Use `.venv/Scripts/python.exe` to run Python commands.

===BEGIN REFACTORING INSTRUCTIONS===

The reviewer rejected card kt3ucx with 3 blockers. All must be resolved before resubmission.

### B1: Tests were not executed -- no evidence of a passing test suite

The card's work summary states BATS tests were only syntax-checked with `bash -n`. The 13 new BATS tests have never been run. Zero evidence exists that the tests pass, that the implementation matches assertions, or that existing tests still pass after 130 lines of new `peon.sh` code.

**Refactor plan:** Run `bats tests/` in a macOS or Linux environment (the CI runner, a devcontainer, or WSL2) and provide the output demonstrating all tests pass -- both the 13 new tests and the full existing suite. If any tests fail, fix them before resubmitting.

### B2: No BATS test for `peon update` config backfill of debug keys

Acceptance criterion "peon update backfills debug and debug_retention_days config keys" is checked, but there is no test covering this behavior. No test starts with a config missing these keys, runs `peon update`, and verifies they were added. This is a TDD gap: a checked acceptance criterion with no corresponding test.

**Refactor plan:** Add a BATS test that:
1. Creates a config.json without `debug` or `debug_retention_days` keys.
2. Runs `peon update` (may need mocking the install.sh fetch -- follow existing update test patterns).
3. Asserts both keys are present with correct default values.

### B3: `peon update` migration message is incorrect when only debug keys are backfilled

The backfill logic sets `changed = True` when adding `debug` or `debug_retention_days`, then prints:
```
peon-ping: config migrated (active_pack -> default_pack, agentskill -> session_override)
```
This message fires even when no active_pack or agentskill migration occurred -- only the debug key backfill ran.

**Refactor plan:** Either make the print message generic (e.g., "peon-ping: config updated") or track which specific migrations fired and print accordingly. The simplest fix is changing the message to something accurate like "peon-ping: config keys updated" since the original rename migrations are legacy at this point.
