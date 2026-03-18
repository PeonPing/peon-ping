---
verdict: APPROVAL
card_id: qufq3f
review_number: 1
commit: 0957def
date: 2026-03-17
has_backlog_items: true
---

## Review: step 1A -- clean up state helper test timing and narrow retry exception scope

### Change 1: Narrow `_read_state` exception scope (`peon.sh:195`)

**Before:** `except Exception` -- catches everything, silently retries on any error including `TypeError`, `MemoryError`, `KeyboardInterrupt` (via `BaseException` is not caught, but `Exception` still masks too much).

**After:** `except (json.JSONDecodeError, OSError)` -- catches exactly the two failure modes the retry loop is designed for: corrupt/partial JSON reads and filesystem I/O errors.

This is correct. `OSError` covers the full I/O error hierarchy (`PermissionError`, `IsADirectoryError`, `BlockingIOError`, etc.), so transient filesystem issues remain retried. `json.JSONDecodeError` covers partial writes where the file exists but contains truncated JSON. Unexpected errors (`TypeError`, `MemoryError`, `RecursionError`, etc.) will now propagate immediately rather than being silently swallowed through three retry cycles, which is the right behavior.

No callers of `_read_state` or `read_state` wrap the call in their own try/except, so propagating unexpected exceptions will surface as a hook failure -- which is preferable to silent corruption of the state dict.

**Verdict:** Correct, well-scoped change.

### Change 2: Add timing assertion to BATS test (`tests/peon.bats:3756`)

The test "first run with no .state.json succeeds without retry delay" was computing `start_ms` and `end_ms` but never asserting on them -- dead code that gave the appearance of a timing guard without actually providing one.

The new assertion `[ $((end_ms - start_ms)) -lt 3000 ]` closes that gap. The 3-second threshold is generous (the retry delay sums to 350ms), but this is appropriate for CI environments where macOS runners can exhibit high variance. The assertion will catch the failure case it guards against (an accidental retry loop adding 350ms+ of `time.sleep`) without producing flaky failures on slow runners.

**Verdict:** Correct. The dead variables now serve their documented purpose.

### TDD Assessment

This card is a cleanup/chore card fixing pre-existing dead code in a test and narrowing an exception clause. The test change activates an assertion that was already structurally present (variables computed, comment explaining intent, but assertion missing). The production change narrows error handling, which is a safety improvement. No new behavior was introduced, so no new test-first cycle is required. Proportionality applies.

### Checkbox Audit

All checked boxes on the card are truthful. The "tested/verified" box notes that BATS is not available on Windows and CI will validate on macOS, which is an honest statement of the testing gap. The changes are syntactically simple enough that manual verification is reasonable for this environment.

---

## BLOCKERS

None.

## BACKLOG

**L1: Pre-existing timing fallback bug in the BATS test.** The Python fallback path in the timing computation (`python3 -c "import time; print(int(time.time()*1000))"`) produces milliseconds, but the outer arithmetic `$((...)) / 1000000)` divides by 1,000,000 -- which is correct for nanoseconds from `date +%s%N` but wrong for the Python fallback (it would truncate to near-zero). On macOS CI where `date +%s%N` works, this is not a problem. If the test ever runs on a platform where `date +%s%N` is unsupported and the Python fallback fires, the timing assertion would be trivially true (both values near zero, difference near zero). This is a pre-existing issue, not introduced by this commit, but worth a future cleanup card.
