---
verdict: APPROVAL
card_id: zwho9i
review_number: 1
commit: ef87de0
date: 2026-03-17
has_backlog_items: false
---

## Summary

Two focused improvements to the Python quoting lint scanner and its test suite, both originating from reviewer feedback on card csedqi. The changes are small, well-scoped, and correct.

## Analysis

### 1. Multi-hazard scanning (`scripts/lint-python-quoting.sh`)

The `is_hazard` flag approach is sound. When an unescaped `"` is identified as a hazard site (`["` or `.get("`), the scanner advances `start = i + 1` and continues walking forward. When a clean closing `"` is found (no hazard pattern), it breaks -- correctly treating that as the end of the `python3 -c` block.

I traced through the multi-hazard test input (`d["a"], d.get("b", 0))`) and the scanner correctly identifies both the `["` hazard at the first unescaped `"` and the `.get("` hazard at the third. The intermediate `"` (closing `"a"`) triggers the "suspicious `"]`" branch, which now also correctly sets `is_hazard = True` and continues scanning rather than breaking early. The fourth unescaped `"` (closing `"b"`) has no hazard pattern and triggers the break -- correct behavior since from bash's perspective this is already well past the broken block.

The `is_hazard` flag is correctly scoped inside the `if ch == "\""` block and reset to `False` on each iteration through that block, so there is no stale state between iterations.

### 2. Test grep exclusion (`tests/lint-python-quoting.bats`)

Replacing `grep -v` pipes with `--exclude-dir` flags is a strict improvement:
- `--exclude-dir=tests` prevents future `.sh` test helpers with intentional bad patterns from causing false positives in the "all shell scripts" sweep.
- `--exclude-dir=node_modules` and `--exclude-dir=.git` are more precise than the previous `grep -v` patterns, which matched substrings anywhere in the path.
- The self-exclusion of `lint-python-quoting.sh` remains as `grep -v` since it is a specific file, not a directory -- appropriate.

### 3. Multi-hazard regression test

The new test at line 114 directly verifies the card's primary behavioral change: that both `["` and `.get("` hazards are reported from a single `python3 -c` block. Assertions check for both patterns in the output. Exit status 1 is asserted. This is the right test for this change.

### TDD assessment

The test was added alongside the implementation in the same commit. The test structure defines the expected behavior (report ALL hazards, not just the first) and asserts on output content, not implementation details. The existing test suite already covered the single-hazard cases and clean-file cases, so this commit correctly adds only the new multi-hazard behavior test. Proportionate to the scope.

## BLOCKERS

None.

## BACKLOG

None.
