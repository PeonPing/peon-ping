# Harden install.ps1 volume regex replacement to avoid trailing comma on last JSON key

## Task Overview

* **Task Description:** Fix the volume regex replacement in `install.ps1` so it does not produce malformed JSON when `volume` is the last key in the object. Currently the replacement string always appends a comma (`"volume": $volStr,`), but the regex matches an optional trailing comma via `,?`. When there is no trailing comma in the input (i.e. `volume` is the last key), the output becomes `"volume": 0.5,}` which is invalid JSON.
* **Motivation:** PowerShell's `ConvertFrom-Json` tolerates trailing commas, but other JSON parsers (jq, Python, Node) would reject the output. This is a correctness issue that could surface if config files are read by external tools.
* **Scope:** `install.ps1` — volume regex replacement logic only.
* **Related Work:** Identified during review of card f4w9gu (techdebt2 sprint cleanup). Commit `470c328` hardened the regex but did not address the trailing-comma edge case.
* **Estimated Effort:** 30 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Review the volume regex in `install.ps1` — confirm the `,?` capture and replacement string behavior | - [ ] Current state is understood and documented. |
| **2. Plan Changes** | Capture the optional comma in a regex group and replay it in the replacement, or use a conditional approach | - [ ] Change plan is documented. |
| **3. Make Changes** | Update the regex replacement to preserve or omit the comma based on input | - [ ] Changes are implemented. |
| **4. Test/Verify** | Test with `volume` as last key (no comma) and non-last key (with comma) | - [ ] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal fix, no user-facing doc changes | - [ ] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [ ] Changes are reviewed and merged. |

#### Work Notes

> The fix should capture the optional comma in a group (e.g. `(,?)`) and replay it in the replacement string so the output preserves whatever punctuation the input had.

**Commands/Scripts Used:**
```powershell
# Example: test the regex against both cases
$json = '{ "volume": 0.8 }'       # last key, no comma
$json = '{ "volume": 0.8, "pack": "peon" }'  # not last key, has comma
```

**Decisions Made:**
* Prefer capturing the comma in a group and replaying it, rather than a conditional approach, for simplicity.

**Issues Encountered:**
* None yet.

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | |
| **Files Modified** | `install.ps1` |
| **Pull Request** | |
| **Testing Performed** | |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [ ] All planned changes are implemented.
* [ ] Changes are tested/verified (tests pass, configs work, etc.).
* [ ] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [ ] Changes are reviewed (self-review or peer review as appropriate).
* [ ] Pull request is merged or changes are committed.
* [ ] Follow-up tickets created for related work identified during execution.
