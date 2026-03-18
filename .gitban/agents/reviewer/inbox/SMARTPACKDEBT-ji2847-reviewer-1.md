---
verdict: APPROVAL
card_id: ji2847
review_number: 1
commit: 4126d41152221fd6db1a3fadb6fbf2e4b2c99024
date: 2026-03-15
has_backlog_items: false
---

## Summary

Card ji2847 improves the post-install ffplay guidance in `install.ps1` for Windows users. The original tip recommended only `winget install ffmpeg`, which installs the Gyan build that may not place `ffplay` on PATH. The fix expands the guidance to recommend `choco install ffmpeg` as the primary method (which adds ffplay to PATH automatically), warns about the winget PATH issue, and provides manual PATH fallback instructions.

The actual ji2847 work is in commit `93ae253` (6 lines added to `install.ps1`, 2 Pester tests added). The reviewed commit `4126d41` is a merge commit that also incorporates work from cards exg19y and inexon. This review evaluates only the ji2847 changes.

## Assessment

**Scope and correctness.** The change is narrow and well-targeted. The three-tier guidance (choco recommended, winget with caveat, manual fallback) is practical and addresses the real user pain point. The console output formatting is clean and uses appropriate color coding (Yellow for the tip header, DarkGray for the commands).

**Tests.** Two Pester tests were added: one asserts `choco install ffmpeg` appears in the install script, the other asserts the `may not add ffplay to PATH` warning text. These are string-presence tests against the embedded hook script content, consistent with the existing test pattern in this file (e.g., the adjacent ffplay detection test on line 1049). Sufficient for a documentation-level change.

**README decision.** The card correctly determined no README update was needed. The ffplay tip only appears in the installer's post-install console output, targeting MSYS2/Git Bash users. Native Windows uses `MediaPlayer` (no ffplay dependency). The README already documents platform audio backends accurately.

**Checkbox integrity.** All four acceptance criteria checkboxes are truthful:
- Post-install message explains the winget Gyan build PATH issue: verified at line 1561.
- Message provides alternatives (choco + manual PATH): verified at lines 1560, 1563-1564.
- README_zh.md conditional: no README change, so N/A. Correctly marked.
- Pester tests pass: card reports 45 passed, 0 failed.

## BLOCKERS

None.

## BACKLOG

None.
