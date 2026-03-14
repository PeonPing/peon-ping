# Documentation Maintenance & Review

## Documentation Scope & Context

* **Related Work:** SMARTPACK sprint — v2 > m1 > Smart Pack Selection
* **Documentation Type:** README updates, Chinese translation, llms.txt, help text
* **Target Audience:** peon-ping users configuring per-project pack assignment

**Required Checks:**
* [x] Related work/context is identified above
* [x] Documentation type and audience are clear
* [x] Existing documentation locations are known (avoid creating duplicates)

---

## Pre-Work Documentation Audit

* [x] Repository root reviewed for doc cruft (stray .md files, outdated READMEs)
* [x] `/docs` directory (or equivalent) reviewed for existing coverage
* [x] Related service/component documentation reviewed
* [x] Team wiki or internal docs reviewed

| Document Location | Current State | Action Required |
| :--- | :--- | :--- |
| **README.md** | No path_rules docs, still references `active_pack` | Add path_rules section, update config key references to `default_pack` |
| **README_zh.md** | Mirror of README — same gaps | Mirror all README changes in Chinese |
| **docs/public/llms.txt** | References old config keys | Update config key references |
| **peon.sh help text** | No bind/unbind help | Already handled by CLI card — verify consistency |

**Documentation Organization Check:**
* [x] No duplicate documentation found across locations
* [x] Documentation follows team's organization standards
* [x] Cross-references between docs are working
* [x] Orphaned or outdated docs identified for cleanup

---

## Documentation Work

Per CLAUDE.md change enforcement rules:
- README.md update → also update README_zh.md
- README.md update → also update docs/public/llms.txt

| Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **README: path_rules config section** | Document path_rules array format, glob syntax, first-match-wins, override hierarchy | - [x] Complete |
| **README: bind/unbind CLI reference** | Document `peon packs bind/unbind/bindings` commands | - [x] Complete |
| **README: default_pack rename** | Update all references from `active_pack` to `default_pack` | - [x] Complete |
| **README: session_override rename** | Update agentskill references to session_override | - [x] Complete |
| **README: override hierarchy** | Document full 5-layer hierarchy table | - [x] Complete |
| **README_zh.md** | Mirror all README changes in Chinese translation | - [x] Complete |
| **docs/public/llms.txt** | Update config key references and add path_rules context | - [x] Complete |

**Documentation Quality Standards:**
* [x] All code examples tested and working
* [x] All commands verified
* [x] All links working (no 404s)
* [x] Consistent formatting and style
* [x] Appropriate for target audience
* [x] Follows team's documentation style guide

---

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Final Location** | README.md, README_zh.md, docs/public/llms.txt |
| **Path to final** | Root-level README files + docs/public/llms.txt |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Documentation Gaps Identified?** | No gaps; all SMARTPACK features now documented |
| **Style Guide Updates Needed?** | None |
| **Future Maintenance Plan** | Update docs when path_rules features evolve |

### Completion Checklist

* [x] All documentation tasks from work plan are complete
* [x] Documentation is in the correct location (not in root dir or random places)
* [x] Cross-references to related docs are added
* [x] Documentation is peer-reviewed for accuracy
* [x] No doc cruft left behind (old files cleaned up)
* [x] Future maintenance plan identified [if applicable]
* [x] Related work cards are updated [if applicable]


## Work Summary

Commit: `c998fa3` — docs: add pack selection hierarchy and per-project assignment docs

Changes made:
- **README.md**: Added "Pack Selection Hierarchy" subsection with 5-layer priority table (session_override > path_rules > pack_rotation > default_pack > hardcoded). Added "Per-Project Pack Assignment (path_rules)" subsection with CLI examples (bind/unbind/bindings) and manual config JSON example.
- **README_zh.md**: Added Chinese translations of both new sections. Added `peon packs bind/unbind/bindings` CLI commands to the quick controls section (was missing).
- **docs/public/llms.txt**: Added pack selection hierarchy summary and per-project CLI reference. Updated CLI command list to include bind/unbind/bindings.

Pre-existing state verified:
- `default_pack` rename from `active_pack` was already done in both READMEs and llms.txt
- `session_override` rename from `agentskill` was already done in both READMEs
- `path_rules` inline config docs were already present; new standalone section adds CLI usage and hierarchy context

## Review Log

| Review 1 | **APPROVAL** | Commit `0a67a57` | `.gitban/agents/reviewer/inbox/SMARTPACK-janrlf-reviewer-1.md` |
| | 2 BACKLOG items routed to planner | | `.gitban/agents/planner/inbox/SMARTPACK-janrlf-planner-1.md` |
| | Executor close-out instructions written | | `.gitban/agents/executor/inbox/SMARTPACK-janrlf-executor-1.md` |