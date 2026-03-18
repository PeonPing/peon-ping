## Task Overview

* **Task Description:** Audit all `python3 -c "..."` blocks in `peon.sh` for bash double-quoting hazards. The pattern of using Python dict access like `["key"]` inside bash double-quoted strings causes silent failures or syntax errors. Find and fix any remaining instances of this class of bug.
* **Motivation:** Test 567 failure (card i0u93q) was caused by exactly this pattern — double quotes inside `python3 -c "..."` broke the bash quoting. The status block was fixed, but the same hazard may exist in other `python3 -c` invocations throughout `peon.sh`. This is a recurring class of bug that should be systematically eliminated.
* **Scope:** `peon.sh` — all embedded `python3 -c` blocks.
* **Related Work:** Root cause identified during card i0u93q review (L3 non-blocking item). Test 567 fix was the immediate remediation; this card covers the broader audit.
* **Estimated Effort:** 2-4 hours

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Grep `peon.sh` for all `python3 -c` invocations and catalog quoting style used in each | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | For each block: determine if dict access `["key"]` or other double-quote usage exists inside a bash double-quoted string. Plan remediation (heredoc, single-quote wrapping, or escape). | - [ ] Change plan is documented. |
| **3. Make Changes** | Fix any hazardous quoting patterns found | - [ ] Changes are implemented. |
| **4. Test/Verify** | Run `bats tests/` — all tests must pass | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A unless new patterns are adopted | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> The hazard pattern: `python3 -c "import json; d = json.load(f); print(d[\"key\"])"` — the escaped inner double quotes can break depending on shell context, nesting depth, and variable expansion. Preferred fix: use heredoc (`python3 -c <<'PYEOF' ... PYEOF`) or single-quoted Python strings with `['key']` access.

**Commands/Scripts Used:**
```bash
# Find all python3 -c invocations
grep -n 'python3 -c' peon.sh

# Check for double-quote hazards within those blocks
grep -n 'python3 -c ".*\[' peon.sh
```

**Decisions Made:**
* TBD — will decide on consistent quoting pattern during audit.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | TBD |
| **Files Modified** | TBD |
| **Pull Request** | TBD |
| **Testing Performed** | TBD |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | TBD |
| **Documentation Updates Needed?** | TBD |
| **Follow-up Work Required?** | TBD |
| **Process Improvements?** | Consider adding a lint rule or BATS test that detects `python3 -c "` patterns with unescaped inner quotes |
| **Automation Opportunities?** | Could add a shellcheck or custom CI check for this pattern |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
