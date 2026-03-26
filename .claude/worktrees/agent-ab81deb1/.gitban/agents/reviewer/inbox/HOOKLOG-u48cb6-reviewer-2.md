---
verdict: APPROVAL
card_id: u48cb6
review_number: 2
commit: c209636
date: 2026-03-25
has_backlog_items: true
---

## Scope

This review covers commit `c209636` ("fix: add [route]+[exit] logs to remaining early-exit paths"), which adds structured logging to 4 early-exit paths in the Python block of `peon.sh`. This is the second of two fix commits responding to review-1's rejection (3 blockers). The first commit (`8908a13`) addressed all 3 blockers directly; this commit extends the same fix pattern to additional paths that had the same gap.

Changed file: `peon.sh` (+8 lines).

## Review-1 Blocker Resolution

All three blockers from review-1 were resolved in commit `8908a13`:

- **B1 (missing [exit] on delegate_mode/agent_session)**: Fixed. Both paths now emit `[route]` + `[exit]` before `sys.exit(0)`. Verified by two new dedicated tests (`debug log emits [exit] on delegate_mode early exit`, `debug log emits [exit] on agent_session early exit`), the latter correlating `inv=` IDs between `[route]` and `[exit]` lines.
- **B2 (test coverage only 3 of 9 phases)**: Fixed. The all-phases test now asserts all 9: `[hook]`, `[config]`, `[state]`, `[route]`, `[sound]`, `[play]`, `[notify]`, `[trainer]`, `[exit]`. Three new targeted tests added.
- **B3 (silent replay suppression)**: Fixed. `reason=replay_suppression` is now logged before clearing category. Dedicated test verifies the reason appears in the log file.

## This Commit (c209636)

The commit extends `[route]` + `[exit]` logging to 4 additional early-exit paths that were not flagged in review-1 but had the same diagnostic gap:

| Path | `[route]` reason | Category |
|---|---|---|
| `PostToolUseFailure` (non-Bash tool) | `non_bash_tool_failure` | `none` |
| `SubagentStop` (suppressed) | `subagent_stop_suppressed` | `task.complete` |
| `SubagentStart` | `subagent_start` | `none` |
| `SessionEnd` | `session_end_cleanup` | `none` |

Each follows the identical two-line pattern used across all other early-exit paths:

```python
log('route', category=..., suppressed=True, reason='...')
log('exit', duration_ms=int((time.monotonic() - _peon_start) * 1000), exit=0)
```

**Correctness**: I verified that after this commit, every `sys.exit(0)` in the post-logging portion of the Python block (lines 3162-3849) is preceded by a `[exit]` log call. The pre-logging exits (lines 772, 894, 1390, 1759, 1770, 2800, 3041) are correctly excluded -- they occur before the `log()` function is defined or before config is loaded. This satisfies the ADR-002 contract: "the absence of [exit] is itself diagnostic" of abnormal termination.

**Pattern consistency**: The `[route]` reasons are descriptive and unique across all paths. The `SubagentStop` path correctly logs `category='task.complete'` (reflecting what would have been the CESP category if not suppressed), while the other three log `category='none'` (no sound was ever in scope). This distinction is useful for diagnostics.

**Placement**: Log calls are placed immediately before the `print()` statements that emit shell variables, which is correct -- logging captures the decision before the hook produces output.

**TDD assessment**: This commit adds observability instrumentation (log calls) to 4 existing code paths without changing any behavior. No sound, notification, state, or output changes occur. The pattern being applied is already contract-tested by the 9-phase assertion and the targeted tests from `8908a13`. Proportionality applies: these are mechanical extensions of an established, tested pattern to additional call sites.

## FOLLOW-UP

### L1: Per-path [exit] tests for the 4 new paths

The 4 paths added in this commit do not have dedicated tests verifying their `[exit]` emission (analogous to the `delegate_mode` and `agent_session` tests from `8908a13`). The all-9-phases test covers a normal Stop event, and the functional tests exercise SubagentStart/SubagentStop/SessionEnd, but none assert on log output for these specific paths. Adding targeted tests (e.g., "debug log emits [exit] on SubagentStop suppression") would close the coverage gap and catch any future regression that removes a log call from one of these paths. Non-blocking because the paths are exercised by existing functional tests and the pattern is mechanical, but worth adding when card 77eri8's remaining acceptance criteria are worked on.

### L2: Carry forward L1-L3 from review-1

The three follow-up items from review-1 remain open and should be tracked on their respective cards:
- L1 (timestamp precision in bash `_peon_log()`) -- cosmetic, needs a card or a documented known-limitation note.
- L2 (card 77eri8 acceptance criteria incomplete) -- the card still has substantial remaining work (shared test fixtures, concurrency test, performance benchmark, config backfill, PRD-002 failure scenarios).
- L3 (`_log_quote` does not handle newlines) -- latent correctness issue, should be fixed before format is documented in README.
