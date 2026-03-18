# Improve ffmpeg/ffplay install guidance on Windows

**When to use this template:** Tech debt — improve user guidance for ffplay installation on Windows.

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
| **2. Plan Changes** | Add note about Gyan build PATH issue, or link to docs, or detect and warn specifically | - [ ] Change plan is documented. |
| **3. Make Changes** | Pending — wait for user reports to confirm this is a real pain point | - [ ] Changes are implemented. |
| **4. Test/Verify** | Verify updated message displays correctly | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | Update README.md and README_zh.md if install guidance changes | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Pending | - [ ] Changes are reviewed and merged. |

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
| **Changes Made** | Pending |
| **Files Modified** | `install.ps1`, possibly `README.md`, `README_zh.md` |
| **Pull Request** | Pending |
| **Testing Performed** | Pending |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | Possibly README if install guidance changes |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | Could auto-detect Gyan build and warn specifically |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
