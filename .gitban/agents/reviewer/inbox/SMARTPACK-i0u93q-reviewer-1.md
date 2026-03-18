---
verdict: APPROVAL
card_id: i0u93q
review_number: 1
commit: 3878c19
date: 2026-03-15
has_backlog_items: true
---

## Summary

Two-line fix for CI test failures caused by the SMARTPACK sprint's `active_pack` to `default_pack` rename. Both changes are correct and well-scoped.

**Test 261** (`tests/opencode.bats:126`): Changed `c['active_pack']` to `c['default_pack']`. The OpenCode adapter template at `adapters/opencode.sh:106` emits `"default_pack": "peon"`, so the test assertion now matches the code under test. Correct fix.

**Test 567** (`peon.sh:953-958`): The f-string `{_matched["pattern"]}` contained double quotes inside a bash double-quoted `python3 -c "..."` string. Bash consumed the inner double quotes, causing Python to receive `_matched[pattern]` -- an undefined name reference. The fix extracts values into local variables using `.get()` with single-quoted keys, which are safe inside bash double-quoted strings. This is the correct pattern and matches how the surrounding code (lines 951-952) already accesses `_r.get('pattern', '')`.

## BLOCKERS

None.

## BACKLOG

**L1: Remaining `active_pack` references in test fixture data.** Dozens of test files (`peon.bats`, `wsl-toast.bats`, `mac-overlay.bats`, `relay.bats`, `windsurf.bats`, `kiro.bats`, `install.bats`, `install-windows.bats`, `deepagents.bats`, `copilot.bats`) still use `"active_pack": "peon"` in their inline config JSON. These tests pass today because `peon.sh` has a `c.get('default_pack', c.get('active_pack', 'peon'))` fallback chain, but they represent stale test fixtures that will mask future regressions if the fallback is ever removed. A sweep to update fixture configs from `active_pack` to `default_pack` would align tests with the canonical config shape.

**L2: Executor did not verify tests pass.** TDD steps 4 and 5 on the card are unchecked ("Verify Test Passes" and "Run Full Test Suite"). The fix is straightforward enough that correctness is clear from static analysis, but the workflow gap should be noted. CI on the PR will serve as the verification gate.

**L3: Bash double-quoting fragility in embedded Python.** The root cause of test 567 -- double quotes inside `python3 -c "..."` -- is a recurring hazard throughout `peon.sh`. The status block is now fixed, but the same pattern (dict access with `["key"]` inside bash double-quoted Python) could exist elsewhere. A future hardening pass could audit all `python3 -c` blocks for this class of quoting issue.

## Close-out actions

- None required. Fix is complete and scoped correctly to the two failing tests.
