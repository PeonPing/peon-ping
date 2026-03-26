---
verdict: APPROVAL
card_id: pwv7yj
review_number: 1
commit: 0bd1a18
date: 2026-03-26
has_backlog_items: false
---

## Review: Remove unconditional --all from logs completions

Clean, well-scoped fix. No blockers.

### Analysis

**completions.bash**: The unconditional `--all` was removed from the top-level logs flag list (line 76), leaving only the conditional version at line 78 that triggers after `--session`. Correct and minimal.

**completions.fish**: The duplicate debug/logs sections (leftover from a merge conflict between the --prune and --session cards) were removed. The primary debug completions (lines 104-106) and primary logs completions (lines 109-112) remain intact earlier in the file. The sole remaining `--all` entry for logs is the conditional one at line 156, gated behind `__fish_seen_argument -l session`. Correct.

### TDD Proportionality

This is a completion-only fix with no runtime behavior change. No new tests are required. The executor verified via grep that `--all` only appears in conditional contexts (packs install, logs after --session). Appropriate level of verification for the scope.

### Checkbox Integrity

All checked boxes are accurate. The "Documentation is updated [if applicable]" box is unchecked with a note that no doc change is needed -- correct, since this is a tab-completion fix with no user-facing doc surface.

### Close-out

No outstanding actions. The completion files are consistent and the duplicate fish sections are cleaned up.
