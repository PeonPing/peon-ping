# Remove unconditional --all from logs completions

## Task Overview

* **Task Description:** Remove the unconditional `--all` completion entry from both `completions.bash` and `completions.fish` for the `peon logs` command. Currently `--all` is offered as a top-level logs flag, but `peon logs --all` is not a valid standalone command. The `--all` flag should only appear conditionally after `--session`.
* **Motivation:** Tech debt from the merge of the `--prune` card (px9k89). The unconditional `--all` entry could confuse users with tab-completion suggesting an invalid command form.
* **Scope:** `completions.bash` and `completions.fish` — remove the unconditional `--all` entry from the logs subcommand completions while preserving the conditional version that appears after `--session`.
* **Related Work:** Card px9k89 (step 7a, --prune/log rotation). Card 80usvr (step 7b, --session --all). Discovered during review 1 of card 80usvr.
* **Estimated Effort:** 30 minutes

**Required Checks:**
* [x] **Task description** clearly states what needs to be done.
* [x] **Motivation** explains why this work is necessary.
* [x] **Scope** defines what will be changed.

---

## Work Log

Track the execution of this chore task step by step.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Review Current State** | Inspect `completions.bash` and `completions.fish` for the unconditional `--all` entry in logs completions | - [x] Current state is understood and documented. |
| **2. Plan Changes** | Remove the unconditional `--all` from top-level logs flags; keep only the conditional `--all` that appears after `--session` | - [x] Change plan is documented. |
| **3. Make Changes** | Edit both completion files | - [x] Changes are implemented. |
| **4. Test/Verify** | Run `bats tests/` to confirm no regressions | - [x] Changes are tested/verified. |
| **5. Update Documentation** | N/A — no user-facing docs change needed for completion fix | - [x] Documentation is updated [if applicable]. |
| **6. Review/Merge** | Sprint reviewer | - [x] Changes are reviewed and merged. |

#### Work Notes

> The `--all` flag was introduced by the --session card (80usvr) as a modifier for `peon logs --session ID --all`. The --prune card (px9k89) merge resulted in `--all` also appearing unconditionally in the top-level logs completions. Only the conditional version (after `--session`) is valid.

**Files to edit:**

| File | What to look for |
| :--- | :--- |
| `completions.bash` | Unconditional `--all` in logs completions — remove it, keep conditional version after `--session` |
| `completions.fish` | Unconditional `--all` in logs completions — remove it, keep conditional version after `--session` |

---

## Completion & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Changes Made** | Removed unconditional `--all` from logs completions in both files; deduplicated fish debug/logs sections |
| **Files Modified** | `completions.bash`, `completions.fish` |
| **Pull Request** | Sprint PR |
| **Testing Performed** | Verified grep output shows `--all` only in conditional contexts (packs install, logs after --session) |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Related Chores Identified?** | No |
| **Documentation Updates Needed?** | No |
| **Follow-up Work Required?** | No |
| **Process Improvements?** | No |
| **Automation Opportunities?** | No |

### Completion Checklist

* [x] All planned changes are implemented.
* [x] Changes are tested/verified (tests pass, configs work, etc.).
* [x] Documentation is updated (CHANGELOG, README, etc.) if applicable.
* [x] Changes are reviewed (self-review or peer review as appropriate).
* [x] Pull request is merged or changes are committed.
- [x] Follow-up tickets created for related work identified during execution.


## Executor Summary

**Commit:** `0bd1a18` — `fix: remove unconditional --all from logs completions`

**Changes made:**

1. **completions.bash (line 76):** Removed `--all` from the unconditional logs flags list (`"--last --session --all --prune --clear"` -> `"--last --session --prune --clear"`). The conditional `--all` on line 78 (offered only after `--session`) is preserved.

2. **completions.fish:** Removed the duplicate debug/logs sections (lines 155-166) that were left over from merge conflicts. The unconditional `--all` entry (`complete -c peon -n "__peon_using_subcommand logs" -a "--all"`) was in the duplicate section and is now gone. The conditional version (`__fish_seen_argument -l session`) is preserved as the sole `--all` entry for logs.

**No user-facing doc changes needed** — this is a completion-only fix with no new commands or flags.

## Review Log

| Review 1 | APPROVAL | `.gitban/agents/reviewer/inbox/HOOKLOG-pwv7yj-reviewer-1.md` | Routed to executor for close-out |
