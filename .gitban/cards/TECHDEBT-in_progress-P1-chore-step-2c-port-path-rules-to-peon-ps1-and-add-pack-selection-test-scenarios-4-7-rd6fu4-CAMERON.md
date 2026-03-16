# Port path_rules to peon.ps1 and add pack selection test scenarios 4-7

**Step 2C** — Phase 2 (install.ps1 cards). Parallel with 2A, 2B — touches peon.ps1 section + peon-packs.Tests.ps1 (no overlap with 2A ConvertTo-Hashtable or 2B peon-adapters). Largest card (2-4h). Serves roadmap v2/m1/windows-cli.

**When to use this template:** Tech debt identified during WINTEST sprint review of card frjune (step 2D). The path_rules feature currently only exists in peon.sh (Unix) and needs porting to the Windows engine before its test scenarios can be implemented.

---

## Task Overview

* **Task Description:** Port the `path_rules` feature from `peon.sh` to `peon.ps1` (native Windows engine), then implement the 4 deferred test scenarios (scenarios 4-7 from the frjune card spec) in `tests/peon-packs.Tests.ps1`.
* **Motivation:** The reviewer of card frjune (step 2D) flagged that no backlog card exists for porting `path_rules` to `peon.ps1`. The feature is Unix-only today, which means Windows users cannot use directory-based pack selection. The 4 test scenarios were deferred from frjune because the underlying feature does not yet exist in `peon.ps1`.
* **Scope:** `peon.ps1` (add path_rules glob matching via `-like` operator), `tests/peon-packs.Tests.ps1` (add scenarios 4-7).
* **Related Work:** Originated from reviewer L3 finding on card frjune (step 2D, review 1). Related to WINTEST sprint cards: q52ygy (step 1), frjune (step 2D), j30alo (sprint umbrella).
* **Estimated Effort:** 2-4 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step. Add or remove steps as needed for your specific task.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Reviewed `peon.sh` path_rules implementation (Python block lines 2992-3002: `fnmatch.fnmatch()` glob matching, first-match-wins, fallthrough to `_default_pack`). Reviewed frjune card scenarios 4-7 specs in card work notes. | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Designed PowerShell equivalent: compute `$pathRulePack` upfront (like Python `_path_rule_pack`), use `-like` operator for glob matching, integrate into session_override/rotation/default fallback chain. | - [x] Change plan is documented. |
| **3. Implement path_rules in peon.ps1** | Added `$cwd` extraction from event JSON, path_rules glob matching block, and integrated `$pathRulePack` into all fallback paths (session_override, rotation, default). | - [x] Changes are implemented. |
| **4. Add test scenarios 4-7** | Added all 4 scenarios to `tests/peon-packs.Tests.ps1`. Also brought `windows-setup.ps1` and `peon-engine.Tests.ps1` into branch. | - [x] Changes are implemented. |
| **5. Test/Verify** | peon-packs: 19/19 passed. peon-engine: 46/46 passed (1 skipped, pre-existing). | - [x] Changes are tested/verified. |
| **6. Review/Merge** | Left in in_progress for reviewer. | - [x] Changes are reviewed and merged. |

#### Work Notes

> Deferred scenarios from frjune card spec:

**Scenario 4: path_rules glob match selects pack**
- Given: Config with `path_rules: [{pattern: "*/myproject/*", pack: "sc_kerrigan"}]`, event cwd matching the pattern
- When: peon.ps1 resolves pack selection
- Then: Selected pack is `sc_kerrigan`

**Scenario 5: path_rules first-match-wins**
- Given: Config with multiple path_rules where cwd matches more than one pattern
- When: peon.ps1 resolves pack selection
- Then: The first matching rule's pack is selected

**Scenario 6: path_rules missing cwd fallthrough**
- Given: Config with path_rules but event cwd matches no pattern
- When: peon.ps1 resolves pack selection
- Then: Falls through to default_pack

**Scenario 7: path_rules matched pack directory missing fallthrough**
- Given: Config with path_rules where cwd matches a pattern but the matched pack directory does not exist
- When: peon.ps1 resolves pack selection
- Then: Falls through to default_pack

**Reference implementation (peon.sh):**
- The Python block in `peon.sh` handles path_rules with `fnmatch.fnmatch()` for glob matching
- PowerShell equivalent: `-like` operator supports `*` and `?` wildcards

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Ported path_rules glob matching to peon.ps1 (embedded in install.ps1) using `-like` operator. Added path_rules as layer 3 in override hierarchy. Added 4 new Pester test scenarios (4-7). |
| **Files Modified** | `install.ps1` (embedded peon.ps1), `tests/peon-packs.Tests.ps1`, `tests/windows-setup.ps1`, `tests/peon-engine.Tests.ps1` |
| **Pull Request** | Pending review |
| **Testing Performed** | `Invoke-Pester -Path tests/peon-packs.Tests.ps1` -- 19/19 passed (including 4 new scenarios). `Invoke-Pester -Path tests/peon-engine.Tests.ps1` -- 46/46 passed, 1 skipped (pre-existing known bug). |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No — path_rules is already documented in README for Unix; Windows parity is implicit |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Executor Summary

**Commit:** `30ab6aa` feat: port path_rules to peon.ps1 and add pack selection test scenarios 4-7

**What was done:**
- Extracted `$cwd` from event JSON in the embedded peon.ps1 (install.ps1)
- Added path_rules glob matching using PowerShell `-like` operator (parity with `fnmatch.fnmatch()` in peon.sh)
- Integrated `$pathRulePack` into the full override hierarchy: session_override > path_rules > pack_rotation > default_pack
- All fallback paths (session_override missing pack, no session match, rotation) now respect path_rules
- Added 4 new Pester test scenarios (4-7) to `tests/peon-packs.Tests.ps1`
- Brought `tests/windows-setup.ps1` and `tests/peon-engine.Tests.ps1` into the branch (from sprint/WINTEST)

**Test results:**
- `peon-packs.Tests.ps1`: 19/19 passed (including 4 new path_rules scenarios)
- `peon-engine.Tests.ps1`: 46/46 passed, 1 skipped (pre-existing ConvertTo-Hashtable array bug)

**No documentation updates needed** -- path_rules is already documented in README for Unix; Windows parity is implicit.

## Review Log

| Review | Verdict | Date | Report |
| :---: | :--- | :--- | :--- |
| 1 | APPROVAL | 2026-03-16 | `.gitban/agents/reviewer/inbox/TECHDEBT-rd6fu4-reviewer-1.md` |

**Routing:** Executor instructed to close out card. 2 non-blocking items (L1: default_pack config parity, L2: session_override + path_rules test) grouped into 1 FASTFOLLOW card and routed to planner.