# Port path_rules to peon.ps1 and add pack selection test scenarios 4-7

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
| **1. Review Current State** | Review `peon.sh` path_rules implementation (Python block: glob matching, first-match-wins, fallthrough to default_pack). Review frjune card scenarios 4-7 specs. | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Design PowerShell equivalent using `-like` operator for glob matching. Map the Python logic to pure PowerShell: iterate path_rules array, match `cwd` against each pattern, return first matching pack, fall through to default_pack if no match or pack directory missing. | - [ ] Change plan is documented. |
| **3. Implement path_rules in peon.ps1** | Add path_rules processing to the pack selection logic in `peon.ps1`. Must support: glob pattern matching via `-like`, first-match-wins semantics, fallthrough when cwd matches no rule, fallthrough when matched pack directory does not exist. | - [ ] Changes are implemented. |
| **4. Add test scenarios 4-7** | Add the 4 deferred scenarios to `tests/peon-packs.Tests.ps1`: Scenario 4 (path_rules glob match selects pack), Scenario 5 (first-match-wins when multiple rules match), Scenario 6 (missing cwd fallthrough to default_pack), Scenario 7 (matched pack directory missing fallthrough to default_pack). | - [ ] Changes are implemented. |
| **5. Test/Verify** | Run `Invoke-Pester -Path tests/peon-packs.Tests.ps1` — all scenarios pass including new 4-7. | - [ ] Changes are tested/verified. |
| **6. Review/Merge** | PR review and merge. | - [ ] Changes are reviewed and merged. |

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
| **Changes Made** | |
| **Files Modified** | `peon.ps1`, `tests/peon-packs.Tests.ps1` |
| **Pull Request** | |
| **Testing Performed** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No — path_rules is already documented in README for Unix; Windows parity is implicit |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | N/A |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
