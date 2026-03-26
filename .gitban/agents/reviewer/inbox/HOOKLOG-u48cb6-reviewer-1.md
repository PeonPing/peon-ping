---
verdict: REJECTION
card_id: u48cb6
review_number: 1
commit: eefe57a
date: 2026-03-25
has_backlog_items: true
---

## Scope

This review covers merge commit `eefe57a` which brings in commit `6082e05` ("feat: add structured debug logging infrastructure (ADR-002)"). The changes span:

- `config.json` -- two new keys (`debug`, `debug_retention_days`)
- `docs/adr/proposals/ADR-002-structured-hook-logging.md` -- new ADR (203 lines)
- `docs/designs/structured-hook-logging.md` -- new design doc (632 lines)
- `peon.sh` -- logging infrastructure in Python block + bash-side `_peon_log()` (117 net lines)
- `tests/peon.bats` -- 5 new test cases (99 lines)

The card under review is `u48cb6` (sprint tracking chore), but the substantive implementation work is on card `77eri8` (step 2: core logging infrastructure). This review evaluates the code on its technical merits.

## BLOCKERS

### B1: Missing `[exit]` log on two early-exit paths

The `delegate_mode` and `agent_session` suppression paths (peon.sh Python block, around lines 3160-3168 at commit) call `log('route', ...)` then `sys.exit(0)` without emitting a `[exit]` line with `duration_ms`. Compare with the `compact_source`, `subagent_session`, and `unknown_event` paths, which all emit both `[route]` and `[exit]` before exiting.

The ADR specifies: "If a hook is killed by timeout before emitting `[exit]`, the incomplete invocation is identifiable by its `inv=` prefix -- all preceding lines for that invocation are present and the absence of `[exit]` is itself diagnostic." This means a missing `[exit]` is supposed to signal an abnormal termination (timeout kill). Deliberately omitting `[exit]` on two normal suppression paths creates a false diagnostic signal -- a user reading the log would see an invocation that logged `[hook]`, `[state]`, `[route]` and then stopped, concluding it was killed by timeout when in fact it exited cleanly.

The acceptance criterion on card 77eri8 states: "Each hook invocation produces log entries for all 9 phases (8 decision phases + exit)." The `delegate_mode` and `agent_session` paths violate this by omitting `[exit]`.

**Fix**: Add `log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)` before `sys.exit(0)` on both paths, matching the pattern already used for `compact_source`, `subagent_session`, and `unknown_event`.

### B2: Test coverage asserts only 3 of 9 phases

The "debug=true creates daily log file with phase entries" test checks for `[hook]`, `[config]`, and `[exit]`. It does not assert the presence of `[state]`, `[route]`, `[sound]`, `[play]`, `[notify]`, or `[trainer]`. The acceptance criterion requires all 9 phases for a normal Stop event.

A test that only checks 3 phases would pass even if the other 6 phase emitters were deleted. This does not constitute meaningful TDD coverage of the phase emitter contract -- it is testing that *some* logging happens, not that the full decision chain is traced. The design doc explicitly defines the phase list as the core value proposition.

**Fix**: The "debug=true" test should assert all phases that a Stop event traverses. For a normal Stop event hitting sound playback and notification, the log should contain `[hook]`, `[config]`, `[state]`, `[route]`, `[sound]`, `[play]`, `[notify]`, `[exit]`. (`[trainer]` can be omitted if trainer is disabled in the test fixture, but should have its own test case verifying the phase appears when trainer is enabled.)

### B3: Silent gap in route logging for replay suppression

When a category is cleared by the 3-second replay suppression logic (peon.sh around line 3612-3616 in the original file), the code sets `category = ''` and `notify = ''` without emitting any `[route]` log. The subsequent "Log route decision" block at line 3622 has `elif not category: pass` -- explicitly doing nothing.

This means a user debugging "why didn't my sound play?" would see `[hook]`, `[config]`, `[state]` -- and then the next `[route]` entry would be absent entirely. There is no way to distinguish replay suppression from debounce suppression from category-disabled suppression without a `[route]` log line.

The acceptance criterion says: "Suppression decisions logged with reason." The replay suppression within 3 seconds of session start is a suppression decision with no logged reason.

**Fix**: Add `log('route', category=original_category, suppressed=True, reason='replay_suppression')` (or similar) before clearing the category. The `elif not category: pass` should at minimum log that category was cleared by a prior suppression that already emitted its own `[route]` line, or the earlier suppression sites (debounce at line 3581, replay at 3612) should each log their own `[route]` before clearing.

Note: The debounce case at line 3581 *does* correctly log before clearing (`reason='debounce_5s'`). The replay suppression at 3612 does not. This inconsistency confirms it was missed rather than intentionally omitted.

## FOLLOW-UP

### L1: Timestamp precision loss in bash `_peon_log()`

The bash-side `_peon_log()` function uses `date '+%Y-%m-%dT%H:%M:%S.000'` -- hardcoding `.000` as the millisecond component. This means all `[play]` phase entries will show zero milliseconds regardless of actual time. The Python-side `log()` correctly captures real milliseconds via `datetime.now().microsecond // 1000`.

While this is a cosmetic discrepancy (the `inv=` ID is the correlation mechanism, not the timestamp), it creates a visible inconsistency between Python-emitted and bash-emitted log lines. A user seeing `.000` on `[play]` but `.142` on `[exit]` may question log integrity.

On macOS, `gdate` (from coreutils) supports `%N` for nanoseconds. On Linux, `date +%N` works natively. A portable approach: `date '+%Y-%m-%dT%H:%M:%S.'$(python3 -c "import time; print(f'{int(time.time()*1000)%1000:03d}')")` -- but this adds a subprocess. Alternatively, accept the `.000` and document it as a known limitation. Non-blocking, but worth a follow-up card.

### L2: Card 77eri8 acceptance criteria are heavily incomplete

The card lists 15 acceptance criteria, of which zero are checked. The executor work log acknowledges "remaining work": shared test fixtures, concurrency test, performance benchmark, config backfill, and 5 PRD-002 failure scenario coverage. This commit delivers partial progress on the card.

This is not a code blocker (the code that *is* present should still be correct), but the card should not be moved to done until the remaining criteria are met. The sprint tracking card should reflect which criteria are satisfied and which are deferred.

### L3: `_log_quote` does not handle newline characters

The quoting function checks for spaces, quotes, and equals signs, but does not check for or escape newline characters in values. If a notification template or error message contains a newline, the log line will be split across multiple lines, breaking the one-line-per-phase invariant. The design doc does not address this edge case.

Non-blocking because current peon-ping values are unlikely to contain newlines, but it is a latent correctness issue that should be addressed before the format is documented in the README.
