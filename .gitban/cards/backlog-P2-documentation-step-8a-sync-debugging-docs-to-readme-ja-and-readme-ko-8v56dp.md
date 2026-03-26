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
* [ ] Related service/component documentation reviewed
* [ ] Team wiki or internal docs reviewed

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
* [ ] Cross-references between docs are working
* [ ] Orphaned or outdated docs identified for cleanup

---

## Documentation Work

Track the actual documentation tasks that need to be completed:

| Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **Translate Debugging section to Japanese** | Not started | - [ ] Complete |
| **Add Debugging section to README_ja.md** | Not started | - [ ] Complete |
| **Translate Debugging section to Korean** | Not started | - [ ] Complete |
| **Add Debugging section to README_ko.md** | Not started | - [ ] Complete |
| **Verify section placement matches README.md** | Not started | - [ ] Complete |

**Documentation Quality Standards:**
* [ ] All code examples tested and working
* [ ] All commands verified
* [ ] All links working (no 404s)
* [ ] Consistent formatting and style
* [ ] Appropriate for target audience
* [ ] Follows team's documentation style guide

### Required Reading

- `README.md` -- source Debugging section to translate
- `README_zh.md` -- reference for how the Chinese translation was done
- `README_ja.md` -- target file for Japanese translation
- `README_ko.md` -- target file for Korean translation

### Acceptance Criteria

- [ ] README_ja.md contains a translated Debugging section matching the structure and location of README.md
- [ ] README_ko.md contains a translated Debugging section matching the structure and location of README.md
- [ ] Section placement in both files matches the position in README.md and README_zh.md
- [ ] All CLI commands and code examples are preserved exactly (not translated)

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

* [ ] All documentation tasks from work plan are complete
* [ ] Documentation is in the correct location (not in root dir or random places)
* [ ] Cross-references to related docs are added
* [ ] Documentation is peer-reviewed for accuracy
* [ ] No doc cruft left behind (old files cleaned up)
* [ ] Future maintenance plan identified [if applicable]
* [ ] Related work cards are updated [if applicable]
