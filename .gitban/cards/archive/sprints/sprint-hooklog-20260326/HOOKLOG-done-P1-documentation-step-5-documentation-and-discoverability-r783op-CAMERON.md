# step 5: Documentation and discoverability

## Documentation Scope & Context

* **Related Work:** HOOKLOG sprint — PRD-002 Phase 3 "Documentation and discoverability"
* **Documentation Type:** README updates, CLI help text, llms.txt, troubleshooting guide
* **Target Audience:** End users debugging peon-ping issues; contributors testing adapters

**Required Checks:**
* [x] Related work/context is identified above
* [x] Documentation type and audience are clear
* [x] Existing documentation locations are known (avoid creating duplicates)

---

## Pre-Work Documentation Audit

- [x] Repository root reviewed for doc cruft (stray .md files, outdated READMEs)
- [x] `/docs` directory (or equivalent) reviewed for existing coverage
- [x] Related service/component documentation reviewed
- [x] Team wiki or internal docs reviewed

| Document Location | Current State | Action Required |
| :--- | :--- | :--- |
| **README.md** | No "Debugging" section exists | Add new Debugging section with `peon debug` and `peon logs` examples. Also update the CLI command reference table/listing to include `debug` and `logs` commands. |
| **README_zh.md** | No debugging section | Add translated Debugging section (change enforcement rule) |
| **docs/public/llms.txt** | No debug/logging info | Add debug config keys, CLI commands, log format |
| **peon help output** | No debug/logs commands listed | Must be updated in steps 4A/4B — verify here |
| **peon status --verbose** | No debug state shown | Add debug enabled/disabled to verbose status output |

**Documentation Organization Check:**
- [x] No duplicate documentation found across locations
- [x] Documentation follows team's organization standards
- [x] Cross-references between docs are working
- [x] Orphaned or outdated docs identified for cleanup

---

## Documentation Work

| Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **README.md Debugging section** | New section: enabling debug, reading logs, common failure examples, log format reference. Update existing CLI command reference to include `debug` and `logs`. | - [x] Complete |
| **README_zh.md translated Debugging section** | Chinese translation of the Debugging section | - [x] Complete |
| **docs/public/llms.txt** | Add debug config keys, CLI commands, log phases, log format | - [x] Complete |
| **peon status --verbose debug state** | Show "Debug logging: enabled/disabled" and log directory path in verbose output | - [x] Complete |
| **Verify peon help** | Confirm debug and logs commands appear in help output (should be done by steps 4A/4B) | - [x] Complete |

**Documentation Quality Standards:**
- [x] All code examples tested and working
- [x] All commands verified
- [x] All links working (no 404s)
- [x] Consistent formatting and style
- [x] Appropriate for target audience
- [x] Follows team's documentation style guide

---

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Final Location** | README.md, README_zh.md, docs/public/llms.txt, peon.sh (status --verbose) |
| **Path to final** | README.md Debugging section, README_zh.md equivalent |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Documentation Gaps Identified?** | README_ja.md and README_ko.md exist but were not updated (not in scope per card/CLAUDE.md enforcement rules, which only mandate zh). Consider a follow-up to add debug docs to ja/ko. |
| **Style Guide Updates Needed?** | No |
| **Future Maintenance Plan** | Update docs when debug_level or JSON format is added in the future. Update README_ja.md and README_ko.md when the next language sync happens. |

### Completion Checklist

- [x] All documentation tasks from work plan are complete
- [x] Documentation is in the correct location (not in root dir or random places)
- [x] Cross-references to related docs are added
- [x] Documentation is peer-reviewed for accuracy
- [x] No doc cruft left behind (old files cleaned up)
- [x] Future maintenance plan identified [if applicable]
- [x] Related work cards are updated [if applicable]


## Work Summary

Commit: `2a0e43f` on branch `worktree-agent-a8aec86f`

### Changes made

1. **README.md** -- Added Debugging section (between Sound packs and Uninstall) with subsections: enabling debug logs, reading logs, log format reference, common failure examples table, and config keys table. Added `peon debug` and `peon logs` commands to the CLI listing in Quick controls. Updated TOC.

2. **README_zh.md** -- Full Chinese translation of the Debugging section and CLI commands, matching README.md structure exactly.

3. **docs/public/llms.txt** -- Added `peon debug` and `peon logs` to CLI commands listing. Added new Debugging section with log format, config keys, and usage. Updated Configuration key list to include `debug` and `debug_retention_days`.

4. **peon.sh** (peon status --verbose) -- Added debug logging state (`enabled`/`disabled`), log directory path, and retention days to verbose status output.

5. **config.json** -- Fixed duplicate `debug` and `debug_retention_days` keys (appeared twice due to merge from prior HOOKLOG cards).

6. **Verified peon help** -- Confirmed `debug on/off/status` and `logs` commands appear in help output (implemented by step 4A card kt3ucx).

### Not in scope (noted for follow-up)
- README_ja.md and README_ko.md were not updated (CLAUDE.md change enforcement rules only mandate zh updates)

## Review Log

- **Review 1**: APPROVAL (commit `2a0e43f`, 2026-03-26). Report: `.gitban/agents/reviewer/inbox/HOOKLOG-r783op-reviewer-1.md`. Two non-blocking follow-ups routed to planner (L1: ja/ko translation sync, L2: verbose status gating).