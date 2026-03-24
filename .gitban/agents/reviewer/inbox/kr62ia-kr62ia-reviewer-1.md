---
verdict: APPROVAL
card_id: kr62ia
review_number: 1
commit: 4856b0f
date: 2026-03-24
has_backlog_items: true
---

## Summary

This card ports the notification template resolution engine from the Unix Python block (`peon.sh:3698-3723`) to PowerShell in the Windows hook script (`install.ps1`). The implementation is clean, well-scoped, and achieves behavioral parity with the Unix version. The test suite is thorough and demonstrates TDD discipline.

## BLOCKERS

None.

## Analysis

**Implementation quality.** The 34-line PowerShell block is a faithful port of the Unix Python logic. The `[regex]::Replace` with ScriptBlock evaluator is the correct PS 5.1 idiom for replicating Python's `format_map()` with a `defaultdict(str)`. The insertion point (after sound dispatch, before notification dispatch) is exactly right -- `$notifyMsg` gets overwritten before `win-notify.ps1` consumes it.

**Behavioral parity.** Verified line-by-line against `peon.sh:3698-3723`:
- Template key mapping: identical (`task.complete -> stop`, `task.error -> error`)
- Event-specific overrides: functionally equivalent. The Unix version guards `idle_prompt`/`elicitation_dialog` behind `event == 'Notification'`, while the Windows version uses flat `if` statements. This is acceptable because `PermissionRequest` events will never carry `ntype` values of `idle_prompt` or `elicitation_dialog`, and the flat structure is more readable in PowerShell.
- Unknown variables: both resolve to empty string.
- Summary truncation: both cap at 120 characters.
- Fallback: both preserve original `$notifyMsg` when no template is configured.

**Defensive coding.** The `try/catch` around `$event.transcript_summary`, the null-coalescing to empty string, and the whitespace trim before truncation all handle edge cases that the Unix version handles implicitly via Python's `dict.get()` default. Good.

**Test quality.** 16 Pester tests across 10 `Describe` blocks. The extraction approach (parsing the template block out of `install.ps1` and executing it with `Invoke-Expression`) is a reasonable unit-testing strategy that avoids needing the full hook execution context. Tests cover:
- All 5 template keys (stop, permission, error, idle, question)
- All 5 variables (project, summary, tool_name, status, event)
- Truncation boundary (200-char input truncated to 120)
- Unknown variable rendering
- Missing config fallback
- Special characters in variable values
- Syntax validation of the extracted block

The `task.error` test (line 171-175) only validates presence in install.ps1 via regex rather than invoking the resolution engine. This is weaker than the other template key tests but non-blocking -- the regex assertion confirms the mapping exists, and the resolution engine itself is thoroughly tested through the other 4 keys.

**TDD compliance.** The card documents test-first workflow. The test file defines behavioral contracts (what should the template engine produce given these inputs?) rather than testing implementation internals. Failure cases and edge cases are covered. Proportionate to the change.

**Design doc.** `docs/designs/win-notification-templates.md` is well-structured and accurately describes what was implemented. The test strategy section lists 8 scenarios (matching the 8 Describe blocks in the test file); the actual test count of 16 reflects multiple `It` blocks within some Describes.

## Close-out actions

- CI must go green (both BATS macOS and Pester Windows) before merge. The card correctly leaves this checkbox unchecked.

## BACKLOG

**L1: Invoke-based `task.error` test.** The `task.error -> error` template key is only verified via regex match on `install.ps1` source, not by actually invoking the template resolution engine. Consider adding an `Invoke-TemplateResolution` test case for `task.error` to match the coverage level of the other four keys. Low priority -- the engine is well-tested through the other paths and the regex confirms the mapping exists.

**L2: Event-override guard parity.** The Unix implementation guards `idle_prompt`/`elicitation_dialog` overrides behind `event == 'Notification'`, which means those overrides cannot fire for non-Notification events. The Windows version uses flat `if` statements that would fire regardless of `$hookEvent`. In practice this is harmless (no real event combines `PermissionRequest` with `ntype = 'idle_prompt'`), but aligning the guard structure would eliminate the possibility of a future edge case divergence. Cosmetic.
