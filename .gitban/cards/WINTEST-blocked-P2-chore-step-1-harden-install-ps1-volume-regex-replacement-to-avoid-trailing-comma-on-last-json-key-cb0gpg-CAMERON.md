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
| **1. Review Current State** | Line 706: regex `[\d.]+,` requires trailing comma; fails silently when volume is last key | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Capture optional comma in group `(,?)` and replay with `$1` in replacement | - [x] Change plan is documented. |
| **3. Make Changes** | Updated line 706 regex from `[\d.]+,` to `[\d.]+(,?)` with `$1` replay | - [x] Changes are implemented. |
| **4. Test/Verify** | Tested 3 cases (comma, no comma, multiline) — all produce valid JSON. Pester: 275/275 passed. | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A — internal fix, no user-facing doc changes | - [x] Documentation is updated [if applicable]. |
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
| **Changes Made** | Hardened volume regex to capture optional trailing comma and replay it |
| **Files Modified** | `install.ps1` (line 706) |
| **Pull Request** | Pending merge to sprint/WINTEST |
| **Testing Performed** | Manual regex tests (3 cases, all valid JSON); Pester 275/275 passed |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |
| **Automation Opportunities?** | N/A |

### Completion Checklist

* [x] All planned changes are implemented.
* [x] Changes are tested/verified (tests pass, configs work, etc.).
* [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [x] Changes are reviewed (self-review or peer review as appropriate).
* [x] Pull request is merged or changes are committed.
* [x] Follow-up tickets created for related work identified during execution.


## Executor Summary

**Commit:** `2f128a5` — fix: harden volume regex to preserve trailing comma state

**Change:** In `install.ps1` line 706, the `--volume` CLI handler used a regex that always appended a comma in the replacement output: `'"volume"\s*:\s*[\d.]+,'` replaced with `"volume": $volStr,`. When `volume` was the last key in the JSON object (no trailing comma), this produced `"volume": 0.5,}` — invalid JSON.

**Fix:** Changed the regex to capture the optional comma in a group `(,?)` and replay it with `$1`: `'"volume"\s*:\s*[\d.]+(,?)'` replaced with `"volume": $volStr$1`. This preserves the comma when present and omits it when absent.

**Testing:**
- Manual test with 3 JSON shapes (comma present, comma absent, multiline last key) — all produce valid JSON via `ConvertFrom-Json`
- Full Pester suite: 275 passed, 0 failed
- PowerShell syntax validation: clean

## BLOCKED
Review 1 REJECTION: Missing test for volume-as-last-key edge case (TDD violation). See .gitban/agents/reviewer/inbox/WINTEST-cb0gpg-reviewer-1.md


## Router Log

Review 1 routed: REJECTION with 1 blocker (B1: missing test for volume-as-last-key edge case). Executor instructions written to `.gitban/agents/executor/inbox/WINTEST-cb0gpg-executor-1.md`. No planner items.