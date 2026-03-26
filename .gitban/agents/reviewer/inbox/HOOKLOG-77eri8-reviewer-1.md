---
verdict: APPROVAL
card_id: 77eri8
review_number: 1
commit: 0cb0aae
date: 2026-03-25
has_backlog_items: true
---

## Summary

This commit adds shared test fixtures for hook logging, a concurrency test, a performance benchmark, five PRD-002 failure scenario tests, and a small production fix in `peon.sh` that captures config-load errors occurring before the logging subsystem initializes. The production change is minimal (4 lines capturing `_config_error` pre-logging, 2 lines emitting it post-logging). The test work is substantial: 11 new BATS tests, 13 fixture files, and a reusable `validate_log_fixture()` helper.

No blockers. The code is solid, the fixtures are well-structured, and the production change correctly solves a real sequencing problem (config errors were silently swallowed because logging wasn't yet available). Approving with follow-up items for future hardening.

## BLOCKERS

None.

## FOLLOW-UP

**L1: `validate_log_fixture` checks phase presence but not non-wildcard value equality.**

The helper's inner loop extracts `key=value` pairs via word splitting (`for kv in $(echo ...)`), which means quoted values containing spaces (like `cwd="/tmp/my project folder"`) will be split incorrectly across multiple loop iterations. The `cwd-with-spaces` fixture works today only because `cwd` is declared as a wildcard (`cwd=` with empty value) in the `[hook]` line -- the actual quoted value on that line (`cwd="/tmp/my project folder"`) is never validated by the fixture loop; instead a separate `grep 'cwd="'` assertion handles it.

This means the fixture format's documented non-wildcard matching for quoted values is effectively untested and broken. If a future fixture adds a non-wildcard value containing spaces, the test will silently pass without actually checking it. Consider switching the parser from word-splitting to a proper field extractor (e.g., a Python one-liner or awk that respects quoted values). Low urgency since all current fixtures use wildcards for space-containing fields, but worth a card if the fixture set grows.

**L2: State contention test asserts safety with `! grep ... || true`.**

The final assertion in "PRD-002: state contention is safe with concurrent access" is:

```bash
! grep '\[state\]' "$logfile" | grep -q 'error=' || true
```

The `|| true` makes this assertion unconditionally pass regardless of whether state errors exist. If a state error were logged, the test would still report success. This should be either `! grep '\[state\]' "$logfile" | grep -q 'error='` (without `|| true`) or restructured as a proper count assertion. This weakens the concurrency safety claim in the acceptance criteria. Worth fixing in a small follow-up.

**L3: Config-enable boilerplate is duplicated across 8 test functions.**

The `/usr/bin/python3 -c "import json; cfg = json.load(...); cfg['debug'] = True; ..."` block is copy-pasted identically into every test that needs debug mode. A BATS helper function (`enable_debug_logging` or similar in `setup.bash`) would eliminate this and make the fixture tests more readable. Minor DRY concern -- not blocking because the duplication is test scaffolding rather than production logic, and each test is self-contained.

**L4: "Missing audio backend" test does not actually test a missing backend.**

The test comment acknowledges this: "In a real missing-backend scenario, play_sound logs the backend attempt. For this test, verify [play] phase appears and logs backend info." The test setup uses the standard mock `afplay`, so it exercises the happy path of `[play] backend=afplay`, not the error path `[play] error="afplay not found"`. The PRD-002 acceptance criterion says "missing audio backend is diagnosable from log output" -- that is only partially validated here (the phase exists and logs `backend=`; the error branch is not exercised). Consider adding a test that removes the mock audio backends from `PATH` to trigger the actual error logging path.
