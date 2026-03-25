# Improve ffmpeg/ffplay install guidance on Windows

**When to use this template:** Tech debt — improve user guidance for ffplay installation on Windows.

---

## Required Reading

| File / Area | What to Look For |
| :--- | :--- |
| `install.ps1` lines 1558-1561 | Current ffplay detection and `winget install ffmpeg` recommendation |
| `README.md` audio backend section | Current documentation of platform audio backends |
| Card d5wz2f (archived) | Original ffplay integration work |
| Card 5fdxw4 (archived) | Windows reliability sprint — context on audio backend decisions |

## Acceptance Criteria

- [x] Post-install message explains that `winget install ffmpeg` (Gyan build) may not add `ffplay` to PATH
- [x] Message provides at least one alternative: `choco install ffmpeg` or manual PATH instructions
- [x] If README.md install guidance is updated, README_zh.md is also updated (per CLAUDE.md documentation rules)
- [x] Pester tests pass

---

## Task Overview

* **Task Description:** The `winget install ffmpeg` recommendation in the installer installs the Gyan build which may not add `ffplay` to PATH automatically. Consider adding a note or linking to project docs if users report confusion about ffplay not being found after installing ffmpeg via winget.
* **Motivation:** Users following the post-install recommendation may end up with ffmpeg installed but ffplay not on PATH, leading to silent audio playback failures on Windows.
* **Scope:** `install.ps1` (post-install message), possibly `README.md` if documentation is updated.
* **Related Work:** Flagged during SMARTPACK-janrlf review. Original ffplay integration in card d5wz2f (archived). Windows reliability sprint card 5fdxw4 (archived).
* **Estimated Effort:** 1-2 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | `install.ps1` prints `winget install ffmpeg` recommendation post-install if ffplay not on PATH | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Expand install.ps1 tip: recommend choco as primary, warn about winget Gyan build PATH issue, add manual PATH fallback. Add Pester tests for new guidance. | - [x] Change plan is documented. |
| **3. Make Changes** | Updated install.ps1 post-install tip and added 2 Pester tests. Commit 93ae253. | - [x] Changes are implemented. |
| **4. Test/Verify** | Pester tests pass: 45 passed, 0 failed (including 2 new tests for choco recommendation and winget PATH warning) | - [x] Changes are tested/verified. |
| **5. Update Documentation** | No README change needed — native Windows uses MediaPlayer, ffplay tip is console-only guidance for MSYS2/Git Bash users | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Commit 93ae253. Ready for review. | - [x] Changes are reviewed and merged. |

#### Work Notes

> This is a low-priority improvement. The Gyan ffmpeg build from winget may not place ffplay on PATH automatically. If users report confusion, improve the guidance. Consider alternatives like suggesting `choco install ffmpeg` or providing manual PATH instructions.

**Decisions Made:**
* Monitor for user reports before investing effort.

**Issues Encountered:**
* None yet — this is a proactive improvement.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Expanded ffplay install tip in install.ps1 to recommend choco, warn about winget Gyan build PATH issue, and provide manual PATH fallback. Added 2 Pester tests. |
| **Files Modified** | `install.ps1`, `tests/adapters-windows.Tests.ps1` |
| **Pull Request** | Pending |
| **Testing Performed** | Pester: 45 passed, 0 failed (install-related tests including 2 new) |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | Possibly README if install guidance changes |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | Could auto-detect Gyan build and warn specifically |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Executor Summary

**Commit:** `93ae253` — `fix: improve ffplay install guidance on Windows`

**Changes:**
- `install.ps1` (lines 1310-1319): Expanded the post-install ffplay tip from a single `winget install ffmpeg` suggestion to:
  - `choco install ffmpeg` as the recommended method (adds ffplay to PATH automatically)
  - `winget install ffmpeg` with a warning that the Gyan build may not add ffplay to PATH
  - Manual PATH fallback instructions for users who already installed via winget
- `tests/adapters-windows.Tests.ps1`: Added 2 new Pester tests validating the choco recommendation and winget PATH warning

**README decision:** No README update needed. The ffplay tip in `install.ps1` is console-only guidance for MSYS2/Git Bash users. Native Windows uses `MediaPlayer` (no ffplay needed). The README already correctly documents platform audio backends.

**Test results:** 45 Pester tests passed, 0 failed.

## Review Log

| Review | Verdict | Report | Routed To |
| :--- | :--- | :--- | :--- |
| Review 1 | APPROVAL | `.gitban/agents/reviewer/inbox/SMARTPACKDEBT-ji2847-reviewer-1.md` | Executor: `.gitban/agents/executor/inbox/SMARTPACKDEBT-ji2847-executor-1.md` |
