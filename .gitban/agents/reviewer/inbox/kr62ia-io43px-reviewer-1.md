---
verdict: APPROVAL
card_id: io43px
review_number: 1
commit: 9904ff7
date: 2026-03-24
has_backlog_items: false
---

## Summary

This card hardens the Windows notification template engine by closing two gaps identified during the kr62ia review: (1) replacing a regex-only `task.error` test with a proper invoke-based test, and (2) aligning the `idle_prompt`/`elicitation_dialog` override guards with the Unix `peon.sh` structure.

## Assessment

**Production code change (install.ps1 lines 1350-1355):**
The `idle_prompt` and `elicitation_dialog` overrides are now gated behind `$hookEvent -eq 'Notification'`, matching the Unix Python block at peon.sh lines 3706-3708. The change is minimal and correct. Without this guard, a malformed event carrying `ntype=idle_prompt` on a non-Notification hook event would incorrectly override the category-based template key. The fix eliminates that edge case.

I verified the Unix reference. The structural difference (Unix uses `elif` for PermissionRequest vs Windows using a separate `if`) is functionally equivalent since `$hookEvent` cannot simultaneously be both `PermissionRequest` and `Notification`. No behavioral divergence.

**Test changes (win-notification-templates.Tests.ps1):**
- The `task.error` test case now invokes the full template resolution engine with `HookEventName=PostToolUseFailure` and `CategoryName=task.error`, matching the invoke-based pattern used for the other four keys. This is a genuine improvement over the prior regex-only assertion.
- Four new guard parity tests cover both positive and negative cases for `idle_prompt` and `elicitation_dialog`. The negative tests are the important ones: they prove that when `$hookEvent` is not `Notification`, the `ntype`-based overrides do not fire and the category-based mapping takes precedence instead. These tests directly exercise the guard logic added in the production code.

**TDD compliance:**
This is a test-hardening card. The card's own framing shows tests defined first (test case table in the card), then implementation to make them pass. The tests assert on behavioral contracts (template resolution output), not implementation details. Negative cases are present. The proportionality is appropriate for the scope.

**Checkbox integrity:**
All checked boxes are truthful. The card reports 20/20 template tests and 360/360 regression tests passing. The executor's work summary documents the specific commits and changes. No deferred work is claimed and none is needed.

**DRY / architecture:**
No duplication introduced. The new tests follow the established `Invoke-TemplateResolution` helper pattern used throughout the file.

## Close-out

No outstanding actions. The card is complete as submitted.
