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

* [ ] Repository root reviewed for doc cruft (stray .md files, outdated READMEs)
* [ ] `/docs` directory (or equivalent) reviewed for existing coverage
* [ ] Related service/component documentation reviewed
* [ ] Team wiki or internal docs reviewed

| Document Location | Current State | Action Required |
| :--- | :--- | :--- |
| **README.md** | No "Debugging" section exists | Add new Debugging section with `peon debug` and `peon logs` examples. Also update the CLI command reference table/listing to include `debug` and `logs` commands. |
| **README_zh.md** | No debugging section | Add translated Debugging section (change enforcement rule) |
| **docs/public/llms.txt** | No debug/logging info | Add debug config keys, CLI commands, log format |
| **peon help output** | No debug/logs commands listed | Must be updated in steps 4A/4B — verify here |
| **peon status --verbose** | No debug state shown | Add debug enabled/disabled to verbose status output |

**Documentation Organization Check:**
* [ ] No duplicate documentation found across locations
* [ ] Documentation follows team's organization standards
* [ ] Cross-references between docs are working
* [ ] Orphaned or outdated docs identified for cleanup

---

## Documentation Work

| Task | Status / Link to Artifact | Universal Check |
| :--- | :--- | :---: |
| **README.md Debugging section** | New section: enabling debug, reading logs, common failure examples, log format reference. Update existing CLI command reference to include `debug` and `logs`. | - [ ] Complete |
| **README_zh.md translated Debugging section** | Chinese translation of the Debugging section | - [ ] Complete |
| **docs/public/llms.txt** | Add debug config keys, CLI commands, log phases, log format | - [ ] Complete |
| **peon status --verbose debug state** | Show "Debug logging: enabled/disabled" and log directory path in verbose output | - [ ] Complete |
| **Verify peon help** | Confirm debug and logs commands appear in help output (should be done by steps 4A/4B) | - [ ] Complete |

**Documentation Quality Standards:**
* [ ] All code examples tested and working
* [ ] All commands verified
* [ ] All links working (no 404s)
* [ ] Consistent formatting and style
* [ ] Appropriate for target audience
* [ ] Follows team's documentation style guide

---

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Final Location** | README.md, README_zh.md, docs/public/llms.txt, peon.sh (status --verbose) |
| **Path to final** | README.md Debugging section, README_zh.md equivalent |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Documentation Gaps Identified?** | TBD |
| **Style Guide Updates Needed?** | No |
| **Future Maintenance Plan** | Update docs when debug_level or JSON format is added in the future |

### Completion Checklist

* [ ] All documentation tasks from work plan are complete
* [ ] Documentation is in the correct location (not in root dir or random places)
* [ ] Cross-references to related docs are added
* [ ] Documentation is peer-reviewed for accuracy
* [ ] No doc cruft left behind (old files cleaned up)
* [ ] Future maintenance plan identified [if applicable]
* [ ] Related work cards are updated [if applicable]
