---
verdict: APPROVAL
card_id: zxp2my
review_number: 1
commit: fe25812
date: 2026-03-28
has_backlog_items: true
---

## Summary

Three independent polish items from the s81ofk review, all well-scoped and correctly implemented. The diff is small (+34 -6), the changes are low-risk, and the card's claims hold up under inspection.

## Analysis

### L1 -- Test ordering assertions (tests/tts.bats, tests/setup.bash)

The core improvement. Previously the "sound-then-speak" and "speak-then-sound" tests asserted that both afplay and TTS were called, but never verified the relative ordering -- meaning the tests would pass even if the modes were swapped. The fix uses a shared `call_order.log` side-channel where both mock afplay and mock tts-native.sh append their identity on invocation. The tests then compare line numbers via `grep -n` to verify ordering.

This is sound. `PEON_TEST=1` runs `_run_sound_and_notify` synchronously, so ordering is deterministic and the assertions are not flaky. The `call_order()` helper reads from `$TEST_DIR/call_order.log`, which is the same directory as `$CLAUDE_PEON_DIR` (set on line 7 of setup.bash), matching where the mocks write. No path mismatch.

The `grep -n | head -1 | cut -d: -f1` pattern for extracting line numbers is idiomatic BATS. The ordering assertions (`[ "$afplay_line" -lt "$tts_line" ]` and vice versa) directly prove what the test names claim.

### L2 -- Speak-only silence diagnostic (peon.sh)

When `speak-only` mode is active but TTS is unavailable (disabled or empty text), the previous code silently did nothing. The fix adds a debug log to stderr gated on `PEON_DEBUG=1`. This follows the existing `[phase] key=value` structured logging convention documented in ADR-001 (which references `[tts]` as the expected log phase). The log includes both `enabled` and `text` values, giving enough context to diagnose why TTS was skipped.

No behavior change outside debug mode. The `if/else` restructuring of the `speak-only` case is clean and reads better than the previous single-line conditional.

### L3 -- Flatten _resolve_tts_backend auto-detection (peon.sh)

The previous code used recursive self-dispatch (`_resolve_tts_backend "$b"` for each candidate), which was functional but unnecessarily indirect. The refactored version iterates over literal script filenames directly. The priority order is preserved (elevenlabs > piper > native), matching both the named case branches above and ADR-001's stated preference ordering.

The tradeoff is that the script filenames are now duplicated -- once in the named cases (`native` -> `tts-native.sh`) and once in the auto loop (`tts-native.sh`). The previous recursive approach derived the auto list from the named cases, avoiding this duplication. However, with only three backends planned (and ADR-001 explicitly noting the registry alternative was rejected for this scale), the duplication is minor and the readability gain is real. This is a reasonable engineering judgment.

## TDD Assessment

This is a refactor card, not a behavior card. The test changes strengthen existing assertions (ordering) rather than adding new behavior coverage. The production code changes are: (1) a debug log on a no-op path, and (2) an internal refactor that preserves external behavior. Proportionality is appropriate -- no new runtime behavior means no new test-driven behavior is required.

The one gap: the speak-only debug log (L2) has no test asserting it emits when `PEON_DEBUG=1`. This is a minor observability feature, not a behavior change, so it does not rise to blocker level. Noted as follow-up below.

## Checkbox Integrity

All checked boxes on the card are truthful. The card claims "existing BATS tests pass without modification" -- this is accurate for tests that existed before the card; the card modifies test files but only to add new assertions to existing tests, not to weaken or remove any. The "testing note" acknowledges BATS cannot run on the Windows worktree and defers to CI, which is the established practice.

## ADR Compliance

ADR-001 specifies independent scripts, the `[tts]` log phase convention, and the backend priority order. All three changes align: the flattened auto-detection preserves priority order, the debug log uses `[tts]` prefix, and no architectural boundaries are crossed.

## FOLLOW-UP

**L1: Test for speak-only debug log emission.** The `PEON_DEBUG=1` + speak-only + TTS-unavailable path now emits a diagnostic to stderr, but no BATS test verifies this. A test that sets `PEON_DEBUG=1`, triggers speak-only mode without a TTS backend, and asserts the `[tts]` line appears on stderr would close the observability loop. Non-blocking because the log is a diagnostic aid, not a behavioral contract.

**L2: Auto-detection script name duplication.** The literal filenames in the `auto` loop (`tts-elevenlabs.sh`, `tts-piper.sh`, `tts-native.sh`) duplicate the named case branches above. If a fourth backend is added, both locations must be updated. A comment noting "keep in sync with named cases above" would reduce the risk of drift. Non-blocking at current scale.
