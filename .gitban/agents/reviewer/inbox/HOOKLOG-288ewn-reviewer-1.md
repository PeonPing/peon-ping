---
verdict: APPROVAL
card_id: 288ewn
review_number: 1
commit: caae8e2
date: 2026-03-25
has_backlog_items: true
---

## Summary

This commit hardens two internal logging helpers in `peon.sh`: `_peon_log()` gets real millisecond timestamps via a three-tier detection strategy (GNU date `%3N`, python3 fallback, `.000` last resort), and `_log_quote()` gains newline/CR escaping to preserve the one-line-per-entry log invariant defined in ADR-002. Two new BATS tests cover both edge cases.

The changes are well-scoped, ADR-002-compliant, and correctly implemented. The escaping order in `_log_quote` (backslashes first, then quotes, then CR/LF) is correct -- reversing the order would corrupt values containing literal `\n` strings. The detection-at-definition-time pattern in `_peon_log` avoids per-call overhead on the hot path.

## ADR-002 Compliance

ADR-002 specifies:
- One-line-per-phase log invariant -- the `_log_quote` newline escaping directly enforces this.
- Key=value format with double-quoting for values containing spaces/specials -- the quoting condition now correctly includes `\n` and `\r`.
- Timestamps with millisecond precision (visible in the example format `2026-03-25T14:22:01.003`) -- the `_peon_log` fix delivers this on GNU date platforms and degrades gracefully elsewhere.

No ADR violations found.

## TDD Assessment

The tests were written to specification before the fix, consistent with TDD:
- The ms precision test runs 3 invocations and asserts at least one timestamp has non-zero milliseconds. This is a behavioral contract test (not an implementation mirror).
- The newline escaping test injects a `\n` in a cwd path and asserts every log line matches the timestamp-prefixed format. This is a negative-case test (detecting format corruption) rather than a happy-path-only test.

Both tests assert on observable behavior (log file content) rather than internal implementation details.

## BLOCKERS

None.

## FOLLOW-UP

**L1: python3 fallback in `_peon_log` has per-call process spawn overhead.**
The python3 timestamp fallback (macOS without GNU coreutils) launches a new `python3 -c` process on every `_peon_log()` call. At ~30-50ms per spawn, 2-3 bash-side log calls would add 60-150ms -- exceeding ADR-002's 5ms logging budget. This path only activates on stock macOS without Homebrew coreutils, and the bash-side logger only covers `[play]`/`[notify]` phases (not the full 6-10), so the real-world impact is limited. A future optimization could cache the ms offset at definition time or use a single `date +%s` with arithmetic. Non-blocking because: (1) it is a fallback path, (2) the primary GNU date path has zero overhead, and (3) the `.000` last-resort is always available.

**L2: ms precision test is technically non-deterministic.**
The test asserts that across 3 invocations, at least one timestamp has non-zero milliseconds. While the probability of all ~20 timestamps landing on exact .000 boundaries is astronomically low, the test is not mathematically guaranteed to pass. If CI flakiness is ever observed on this test, consider asserting the timestamp format matches `\.[0-9]{3}` (proving real digits are emitted) without requiring non-zero values. Non-blocking because the false-failure probability is negligible in practice.
