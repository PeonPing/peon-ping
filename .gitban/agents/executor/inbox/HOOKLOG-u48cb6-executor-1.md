Use `.venv/Scripts/python.exe` to run Python commands.

===BEGIN REFACTORING INSTRUCTIONS===

The reviewer rejected card u48cb6 at commit eefe57a with 3 mandatory blockers. All three must be fixed before re-review.

### B1: Missing `[exit]` log on two early-exit paths

The `delegate_mode` and `agent_session` suppression paths in `peon.sh` (Python block, around lines 3160-3168) call `log('route', ...)` then `sys.exit(0)` without emitting a `[exit]` line with `duration_ms`. All other early-exit paths (`compact_source`, `subagent_session`, `unknown_event`) correctly emit both `[route]` and `[exit]` before exiting.

A missing `[exit]` is supposed to signal abnormal termination (timeout kill) per the ADR. Deliberately omitting it on normal suppression paths creates a false diagnostic signal.

**Fix**: Add `log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)` before `sys.exit(0)` on both the `delegate_mode` and `agent_session` paths, matching the pattern already used for `compact_source`, `subagent_session`, and `unknown_event`.

### B2: Test coverage asserts only 3 of 9 phases

The "debug=true creates daily log file with phase entries" test checks for `[hook]`, `[config]`, and `[exit]` only. It does not assert the presence of `[state]`, `[route]`, `[sound]`, `[play]`, `[notify]`, or `[trainer]`. The acceptance criterion requires all 9 phases for a normal Stop event.

**Fix**: The "debug=true" test should assert all phases that a Stop event traverses. For a normal Stop event hitting sound playback and notification, the log should contain `[hook]`, `[config]`, `[state]`, `[route]`, `[sound]`, `[play]`, `[notify]`, `[exit]`. (`[trainer]` can be omitted if trainer is disabled in the test fixture, but should have its own test case verifying the phase appears when trainer is enabled.)

### B3: Silent gap in route logging for replay suppression

When a category is cleared by the 3-second replay suppression logic (peon.sh around line 3612-3616), the code sets `category = ''` and `notify = ''` without emitting any `[route]` log. The subsequent "Log route decision" block has `elif not category: pass` -- explicitly doing nothing.

The debounce case at line 3581 *does* correctly log before clearing (`reason='debounce_5s'`). The replay suppression at 3612 does not. This inconsistency confirms it was missed rather than intentionally omitted.

**Fix**: Add `log('route', category=original_category, suppressed=True, reason='replay_suppression')` (or similar) before clearing the category at the replay suppression site. Ensure that the `elif not category: pass` branch is either removed or replaced with a log noting the category was already cleared by a prior suppression that emitted its own `[route]`.
