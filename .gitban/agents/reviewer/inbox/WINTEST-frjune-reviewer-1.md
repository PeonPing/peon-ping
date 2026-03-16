---
verdict: APPROVAL
card_id: frjune
review_number: 1
commit: 1126ba9
date: 2026-03-15
has_backlog_items: true
---

## Summary

New file `tests/peon-packs.Tests.ps1` adds 15 Pester integration tests covering the pack selection override hierarchy in peon.ps1: default/active_pack fallback, session_override (including agentskill alias, default key for Cursor, missing pack cleanup, legacy string migration), pack_rotation (random selection, single-pack array), and edge cases (empty rotation, missing rotation_mode). Tests use the shared harness from step 1 (q52ygy) and the two-pack identification technique (peon vs sc_kerrigan sound filenames in the audio log). No production code was changed.

The merge conflict resolution correctly preserved the full 781-line `peon-engine.Tests.ps1` and the BATS harness parity comment in `windows-setup.ps1`.

## Assessment

The tests are well-structured and test real behavior through the public interface (pipe JSON, inspect audio log). Each Describe block creates its own isolated environment and tears it down, preventing cross-test contamination. The rotation test (Scenario 11) handles stop-debounce by resetting `last_stop_time` and using unique session IDs per iteration -- a thoughtful approach to avoid false negatives.

The override hierarchy is tested from both directions: session_override winning over rotation (Scenario 9), and rotation falling through to active_pack when the rotation array is empty. The edge cases (ghost pack cleanup, legacy string format migration, missing rotation_mode) go beyond the original card spec and add genuine defensive coverage.

No blockers. Two checkbox inaccuracies on the card and one missing backlog card noted below.

## BACKLOG

**L1: Card checkbox "Tests are fast enough for CI [< 20 seconds total]" is false.**
The card notes state "~71s total; rotation test ~26s due to process startup overhead per invocation," which contradicts the checked `[x]` box claiming < 20 seconds. The checkbox should be updated to reflect the actual timing, or the threshold revised. Not a code blocker since 71s is acceptable for CI, but the checkbox is misleading.

**L2: Card checkbox "Coverage target met: full override hierarchy (session_override > path_rules > rotation > default) tested" overstates coverage.**
path_rules is explicitly not tested (deferred because the feature is not implemented in peon.ps1). The checkbox text claims the full hierarchy including path_rules is tested. It should read something like "partial override hierarchy tested (path_rules excluded, not implemented in peon.ps1)."

**L3: No backlog card exists for porting path_rules to peon.ps1 and adding the 4 deferred test scenarios.**
The executor work summary says "A follow-up backlog item is needed to port path_rules to peon.ps1 and add these 4 tests" but no card was created. A card should be filed to track this so the deferred work does not get lost. This should cover both the peon.ps1 implementation of path_rules and the corresponding test scenarios 4-7 from the original card spec.
