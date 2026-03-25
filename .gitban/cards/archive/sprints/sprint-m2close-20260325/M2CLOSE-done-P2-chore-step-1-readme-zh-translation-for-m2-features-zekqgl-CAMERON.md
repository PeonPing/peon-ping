# README_zh.md Translation for M2 Features

Translate all m2 feature documentation from README.md into README_zh.md (Chinese). Several sections shipped in English weeks ago but were never translated.

## Task Overview

* **Task Description:** Translate Common Use Cases, Independent Controls table, notification templates config docs, and any other m2 feature sections missing from README_zh.md
* **Motivation:** README_zh.md is stale — missing documentation for features shipped in m2 (templates, sound control, click-to-focus). Chinese-speaking users get an incomplete picture.
* **Scope:** `README_zh.md` only — translate sections present in `README.md` but missing from `README_zh.md`
* **Related Work:** PRD-001 Phase 2, roadmap v2/m2/selective-sound-control/sound-control-docs
* **Estimated Effort:** 30 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Diff README.md vs README_zh.md to identify missing/outdated sections | - [x] Current state is understood and documented. |
| **2. Plan Changes** | List specific sections to translate: Common Use Cases, Independent Controls, notification templates config, any other m2 gaps | - [x] Change plan is documented. |
| **3. Make Changes** | Translate missing sections into Chinese, maintaining same document structure and location | - [x] Changes are implemented. |
| **4. Test/Verify** | Verify all m2 feature sections in README.md have corresponding sections in README_zh.md | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A — this IS the documentation task | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review | - [x] Changes are reviewed and merged. |

#### Work Notes

**Required Reading:**

| File | Purpose |
| :--- | :--- |
| `README.md` lines 314-327 | Independent Controls table |
| `README.md` lines 363 | Notification templates config docs |
| `README.md` lines 406-413 | Common Use Cases section |
| `README_zh.md` | Full file — identify where translated sections should be inserted |

**Sections to translate (verify against README.md before starting):**
- Independent Controls table (3-toggle system: enabled, desktop_notifications, mobile_notify.enabled)
- Common Use Cases (Sounds without popups, Silent mode with notifications only, Complete silence)
- Notification templates config example and variable list
- Any other m2 sections missing from README_zh.md

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | `README_zh.md` |
| **Pull Request** | Part of m2 close-out PR |
| **Testing Performed** | Visual comparison of README.md and README_zh.md section structure |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | This IS the docs update |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | Per CLAUDE.md rules: README_zh.md should be updated at the same time as README.md |
| **Automation Opportunities?** | Could add CI check that README.md and README_zh.md have matching section headers |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Executor Work Summary

**Commit:** `6943662` on branch `worktree-agent-aae8ff97`

**Changes made to `README_zh.md`:**

1. **"What you'll hear" table** — Added missing `task.error` and `task.acknowledge` rows (Chinese README had 5 rows vs English's 7)
2. **Nix installation section (Option 5)** — Translated entire section including Home Manager module, declarative configuration, installPacks, and IDE hooks guidance
3. **Quick controls CLI commands** — Added 8 missing commands: `peon packs use --install`, `peon notifications overlay/standard/test/position/dismiss/label/template`
4. **`meeting_detect` config key** — Added translated documentation
5. **OpenAI Codex setup section** — Full translation of setup steps, runtime requirement, and config.toml entry
6. **Amp environment variables table** — Added `AMP_DATA_DIR`, `AMP_THREADS_DIR`, `AMP_IDLE_SECONDS`, `AMP_STOP_COOLDOWN`
7. **Rovo Dev CLI badge** — Added to header badge row
8. **Rovo Dev CLI in intro paragraph** — Added to the supported IDE list
9. **Codex IDE table entry** — Updated with setup link pointing to new section

**Verification:** Section structure comparison confirms all 34 sections in README.md now have matching sections in README_zh.md. File grew from 958 to 1120 lines (162 insertions, 3 deletions).

## Review Log

| Review 1 | APPROVAL | `.gitban/agents/reviewer/inbox/M2CLOSE-zekqgl-reviewer-1.md` | 2026-03-25 | Commit 6943662 |
