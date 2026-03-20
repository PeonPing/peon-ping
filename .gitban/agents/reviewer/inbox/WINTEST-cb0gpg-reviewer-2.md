---
verdict: APPROVAL
card_id: cb0gpg
review_number: 2
commit: ebca2b1
date: 2026-03-20
has_backlog_items: false
---

## Review: Harden install.ps1 volume regex -- test addition

### Summary

This commit addresses the sole blocker from review 1 by adding a Pester test that exercises the volume-as-last-key edge case. The test is well-constructed and directly verifies the bug that this card exists to fix.

### Assessment

**B1 resolution (from review 1): Test for volume-as-last-key edge case -- RESOLVED**

The new test at line 294 of `cli-config-write.Tests.ps1` does exactly what was requested:

1. Constructs a config where `volume` is the final key with no trailing comma.
2. Runs `--volume 0.7` against it.
3. Asserts via regex that no trailing comma precedes `}` in the raw output.
4. Asserts via `ConvertFrom-Json` that the result is valid JSON.
5. Asserts the value was updated and sibling keys were preserved.

This is a behavior-focused test (not implementation-coupled), it would have caught the original bug, and it will catch regressions. The test name and inline comment clearly describe the failure mode being guarded against.

**Production fix (commit 7b5c5ae, already in the branch):** The regex change on line 696 of `install.ps1` from `[\d.]+,?` to `[\d.]+(,?)` with `$1` replay is correct and minimal. The capture-and-replay approach is the right pattern for preserving optional syntax elements in regex-based text rewriting.

### Checkbox audit

All checked boxes on the card are truthful. The unchecked "Documentation is updated" and "Pull request is merged" boxes are appropriately left unchecked.

No blockers. No backlog items.
