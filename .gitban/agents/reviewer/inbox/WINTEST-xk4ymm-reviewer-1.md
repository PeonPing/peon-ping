---
verdict: APPROVAL
card_id: xk4ymm
review_number: 1
commit: a629878152494eeafb503c43f09833e1c3deae38
date: 2026-03-15
has_backlog_items: false
---

## Summary

This commit addresses both backlog items (L2 and L3) from the q52ygy review. The scope is narrow and correct: two targeted fixes in `tests/windows-setup.ps1`, no unrelated changes.

**Item A -- Locale-dependent decimal separator (L2 fix).** The brittle `(?<=\d),(?=\d)` regex is replaced with a proper culture swap: save `CurrentCulture`, set `InvariantCulture`, serialize, restore. This is the canonical PowerShell approach and eliminates the integer array corruption vector entirely. The culture restore happens immediately after `ConvertTo-Json`, minimizing the window. The comment explains the "why" clearly, referencing the old approach and the specific failure mode.

**Item B -- Extraction regex fragility (L3 fix).** The regex now anchors on `# peon-ping hook for Claude Code`, which is the real marker comment at line 322 of `install.ps1`. I verified the marker exists and is unique. The `\r?\n` prefix handles both Unix and Windows line endings in the here-string. The error message in the `throw` now names the expected marker, which will save debugging time if the marker is ever renamed or removed.

Both fixes are minimal, well-commented, and directly address the identified risks without introducing new ones. Tests pass (204 adapter, 46 engine per the executor log).

## BLOCKERS

None.

## BACKLOG

None. Both original backlog items are resolved.
