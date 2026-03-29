---
verdict: APPROVAL
card_id: 02x5jy
review_number: 1
commit: ef63b3b
date: 2026-03-28
has_backlog_items: false
---

## Review: Consolidate tail-section PEON_TEST checks into single _PEON_SYNC flag

### Summary

Clean, well-scoped refactoring. The commit introduces a single `_PEON_SYNC` boolean flag evaluated once after the Python block's early-exit gate, then references it in 4 locations where 5 separate `${PEON_TEST:-0}` evaluations previously existed. The file-write observability points (`.tab_color_rgb`, `.icon_path`) are grouped into one `if` block instead of two standalone one-liners.

### What was verified

1. **Correctness of flag placement.** `_PEON_SYNC` is set at line 3798, immediately after the `PEON_EXIT` early-return block. All 4 usage sites are downstream. No code path between the flag and its consumers can alter `PEON_TEST`, so the cached value is always consistent.

2. **Scope boundary respected.** The 10 `PEON_TEST` references inside function bodies (`play_sound`, `send_notification`, `send_mobile_notification`) and the 2 early-bootstrap checks (lines 234, 256) are correctly left untouched. These functions are defined before `_PEON_SYNC` exists and are also invoked outside the tail section (e.g., `peon test notification`), so converting them would require parameter threading -- a different, larger change. The executor's summary documents this reasoning explicitly.

3. **Behavioral equivalence.** Each replaced check was `[ "${PEON_TEST:-0}" = "1" ]`; the new flag mirrors this exactly with `_PEON_SYNC=false` / `[ "${PEON_TEST:-0}" = "1" ] && _PEON_SYNC=true`. No semantic difference.

4. **Test contract preserved.** The file paths written (`.tab_color_rgb`, `.icon_path`) and their content are unchanged. BATS tests that assert on these files will continue to pass.

5. **Card description discrepancy acknowledged.** The card describes "8 scattered `if PEON_TEST:` file-write blocks in the embedded Python block." The executor correctly identified that the Python block contains zero `PEON_TEST` references -- all conditionals are in shell code, and the tail section had 5 (not 8). This is documented in the execution summary. The card's description was inaccurate; the executor adapted to reality.

### TDD assessment

This is a pure refactoring of test-infrastructure code. No runtime behavior changes. The existing BATS test suite serves as the safety net -- the refactoring preserves the exact test contract (same files, same content, same synchronous execution). No new tests are needed. The executor notes `bash -n peon.sh` passes; BATS is deferred to CI (macOS runner) since the worktree is on Windows. This is proportionate.

### BLOCKERS

None.

### FOLLOW-UP

None.
