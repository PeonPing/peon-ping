# Documentation Maintenance & Review

## Documentation Scope & Context

* **Related Work:** HOOKLOG sprint card r783op (step-5-documentation-and-discoverability)
* **Documentation Type:** README translations (Japanese and Korean)
* **Target Audience:** Japanese and Korean-speaking users of peon-ping

**Required Checks:**
* [x] Related work/context is identified above
* [x] Documentation type and audience are clear
* [x] Existing documentation locations are known (avoid creating duplicates)

---

## Pre-Work Documentation Audit

Before creating new documentation or updating existing docs, review what's already there to avoid duplication and ensure proper organization.

* [x] Repository root reviewed for doc cruft (stray .md files, outdated READMEs)
* [x] `/docs` directory (or equivalent) reviewed for existing coverage
* [x] Related service/component documentation reviewed
* [x] Team wiki or internal docs reviewed

Use the table below to log findings and identify what needs attention:

| Document Location | Current State | Action Required |
| :--- | :--- | :--- |
| **README.md** | Has Debugging section (added in HOOKLOG sprint) | Source of truth for translation |
| **README_zh.md** | Has Debugging section (synced in HOOKLOG sprint) | Already up to date |
| **README_ja.md** | Missing Debugging section | Add translated Debugging section |
| **README_ko.md** | Missing Debugging section | Add translated Debugging section |

**Documentation Organization Check:**
* [x] No duplicate documentation found across locations
* [x] Documentation follows team's organization standards
* [x] Cross-references between docs are working
* [x] Orphaned or outdated docs identified for cleanup

---

## Documentation Work

Track the actual documentation tasks that need to be completed:

| Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Translate Debugging section to Japanese** | Done (commit 8f67b4b) | - [x] Complete |
| **Add Debugging section to README_ja.md** | Done (commit 8f67b4b) | - [x] Complete |
| **Translate Debugging section to Korean** | Done (commit 8f67b4b) | - [x] Complete |
| **Add Debugging section to README_ko.md** | Done (commit 8f67b4b) | - [x] Complete |
| **Verify section placement matches README.md** | Done -- section order matches all 4 READMEs | - [x] Complete |

**Documentation Quality Standards:**
* [x] All code examples tested and working
* [x] All commands verified
* [x] All links working (no 404s)
* [x] Consistent formatting and style
* [x] Appropriate for target audience
* [x] Follows team's documentation style guide

### Required Reading

- `README.md` -- source Debugging section to translate
- `README_zh.md` -- reference for how the Chinese translation was done
- `README_ja.md` -- target file for Japanese translation
- `README_ko.md` -- target file for Korean translation

### Acceptance Criteria

- [x] README_ja.md contains a translated Debugging section matching the structure and location of README.md
- [x] README_ko.md contains a translated Debugging section matching the structure and location of README.md
- [x] Section placement in both files matches the position in README.md and README_zh.md
- [x] All CLI commands and code examples are preserved exactly (not translated)

---

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Final Location** | README_ja.md, README_ko.md |
| **Path to final** | README_ja.md, README_ko.md |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Documentation Gaps Identified?** | CLAUDE.md only mandates zh sync -- ja/ko drift is expected unless enforcement rules are expanded |
| **Style Guide Updates Needed?** | Consider adding ja/ko to CLAUDE.md enforcement rules |
| **Future Maintenance Plan** | Monitor for further drift in future sprints |

### Completion Checklist

* [x] All documentation tasks from work plan are complete
* [x] Documentation is in the correct location (not in root dir or random places)
* [x] Cross-references to related docs are added
* [x] Documentation is peer-reviewed for accuracy
* [x] No doc cruft left behind (old files cleaned up)
* [x] Future maintenance plan identified [if applicable]
* [x] Related work cards are updated [if applicable]


## Work Summary

**Commit:** `8f67b4b` — `docs: add Debugging section to README_ja.md and README_ko.md`

**What was done:**
- Merged sprint/HOOKLOG branch to pick up the Debugging section added in earlier sprint work
- Translated the full Debugging section (6 subsections) to Japanese and added to README_ja.md
- Translated the full Debugging section (6 subsections) to Korean and added to README_ko.md
- Verified section placement: Sound packs -> Debugging -> Uninstall matches across all 4 READMEs
- All CLI commands (`peon debug on/off/status`, `peon logs` variants) and code examples (log format samples) preserved verbatim
- Used README_zh.md as translation reference for style consistency

**Files changed:** `README_ja.md`, `README_ko.md` (+116 lines total)

## Review Log

- **Review 1 (2026-03-26):** APPROVAL — `.gitban/agents/reviewer/inbox/HOOKLOG-8v56dp-reviewer-1.md`