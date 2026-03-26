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
| **1. Review Current State** | Confirmed: line 706 regex `[\d.]+,` requires trailing comma; fails silently when volume is last key | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Capture optional comma in group `(,?)` and replay with `$1` in replacement string | - [x] Change plan is documented. |
| **3. Make Changes** | Changed regex from `[\d.]+,` to `[\d.]+(,?)` with `$1` backreference in replacement | - [x] Changes are implemented. |
| **4. Test/Verify** | Tested 4 cases (inline/multiline x with/without comma) -- all produce valid JSON. 275 Pester tests pass. | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A -- internal fix, no user-facing doc changes | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | PR review and merge | - [x] Changes are reviewed and merged. |

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
| **Changes Made** | Changed `--volume` regex to capture optional trailing comma in group and replay it |
| **Files Modified** | `install.ps1` (line 706) |
| **Pull Request** | Pending review |
| **Testing Performed** | 4 manual regex cases (valid JSON in all), 275/275 Pester tests pass |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |
| **Automation Opportunities?** | N/A |

### Completion Checklist

- [x] All planned changes are implemented.
- [x] Changes are tested/verified (tests pass, configs work, etc.).
- [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
- [x] Changes are reviewed (self-review or peer review as appropriate).
- [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Executor Summary

Commit `4de19b8` -- fix: preserve trailing comma in install.ps1 volume regex replacement

**Change:** Line 706 in `install.ps1`, the `--volume` CLI command regex was changed from `'\"volume\"\\s*:\\s*[\\d.]+,'` (requires comma) to `'\"volume\"\\s*:\\s*[\\d.]+(,?)'` (captures optional comma in group 1) with the replacement replaying `$1` to preserve or omit the comma based on input.

**Testing:** Verified 4 cases in PowerShell (inline with comma, inline without comma, multiline with comma, multiline without comma) -- all produce valid JSON. All 275 existing Pester tests pass.

**No documentation or version bump needed** -- this is an internal correctness fix with no user-facing change.

## Review Log

| Review 2 | APPROVAL | `.gitban/agents/reviewer/inbox/WINTEST-cb0gpg-reviewer-2.md` | Routed to executor: `.gitban/agents/executor/inbox/WINTEST-cb0gpg-executor-2.md` |
