---
verdict: APPROVAL
card_id: 2d99d1
review_number: 1
commit: 6eb6274
date: 2026-03-26
has_backlog_items: true
---

## Review: gate informational status lines behind --verbose flag

The diff cleanly re-indents all informational status output (desktop notifications, notification style/position/dismiss, label overrides, project name map, notification templates, mobile notifications, headphones-only mode, path rules, IDE detection) under the existing `if verbose:` guard. Essential output (paused/active state, default pack, pack count) remains unconditional. A hint line (`run "peon status --verbose" for full details`) is printed when not in verbose mode.

**What was reviewed:**

1. `peon.sh` -- the status command handler Python block. All informational sections correctly gated. The debug logging status line (`debug logging: enabled/disabled`) stays unconditional, with its detail lines (log dir, retention) gated behind verbose. This is a reasonable classification choice -- debug mode is operational state users may want to see without verbose.

2. `tests/peon.bats` -- two new tests added:
   - "status default output omits verbose-only lines" -- asserts essential info present, informational lines absent, hint line present.
   - "status --verbose shows full details" -- asserts verbose-only sections appear, hint line absent.
   - Four existing tests updated to pass `--verbose` since they assert on verbose-only output (Codex IDE detection x2, path rules x2). This is correct.

3. `completions.bash` / `completions.fish` -- `--verbose` added to `status` subcommand completions. Correct.

4. `README.md` / `README_zh.md` -- CLI reference updated to show both `peon status` (concise) and `peon status --verbose` (full details). Both language variants updated consistently.

**Assessment against standards:**

- **TDD**: The two new tests define the behavioral contract (what appears in default vs verbose). The negative assertions (`!= *"desktop notifications"*`) are particularly good -- they verify the gating actually works rather than just testing the happy path. Existing tests were correctly updated rather than deleted. Proportionate to the change.
- **DRY**: No new duplication introduced. The refactoring is purely structural (re-indentation under a conditional).
- **DaC**: README updated in both languages. Completions updated for discoverability.
- **Change enforcement rules**: README updated -> README_zh.md also updated (satisfied). CLI completions updated for the `--verbose` flag on `status` (satisfied). No new CESP categories, hook events, config keys, or adapters.
- **Security**: No concerns. Output-only change.

**Merge conflict resolution**: The merge commit shows a conflict in the debug logging area where sprint/HOOKLOG had added debug status lines while this branch was re-indenting around them. The resolution correctly keeps debug status as unconditional (essential) with detail lines as verbose-only. Clean resolution.

## FOLLOW-UP

**L1**: The card notes "Consider applying same pattern to peon.ps1" -- the Windows PowerShell status handler still prints all lines unconditionally. This should be a follow-up card to keep parity between platforms.
