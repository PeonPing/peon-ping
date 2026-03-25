---
verdict: APPROVAL
card_id: w7eys1
review_number: 1
commit: 2004f14
date: 2026-03-21
has_backlog_items: true
---

## Summary

Clean Phase 1 implementation of click-to-focus for Windows toast notifications. The diff aligns with ADR-001 and the design doc. The architecture is sound: P/Invoke type, two focused helper functions, activation event loop modeled on the proven `win-play.ps1` pattern, and proper PS 7+ delegation forwarding. The parentPid plumbing is correctly wired end-to-end (hook script, win-notify.ps1, WSL placeholder) for Phase 2 without adding unused logic now.

## Code Assessment

**`scripts/win-notify.ps1` (core implementation)**

The implementation matches the design doc's interface contracts line-for-line. The P/Invoke declarations are correct (user32.dll for window APIs, kernel32.dll for thread ID). `Find-FocusableWindow` correctly filters by `MainWindowHandle -ne [IntPtr]::Zero` and short-circuits on first match. `Set-WindowFocus` correctly brackets the `SetForegroundWindow` call with `AttachThreadInput` attach/detach, and correctly guards the attach/detach behind a thread-ID inequality check (no-op when our thread IS the foreground thread). The `-ErrorAction SilentlyContinue` on `Add-Type` handles the case where the type is already loaded (idempotent). The event loop registers both events before `Show()`, polls at 100ms, and cleans up on all exit paths (activation, dismissal, timeout). The entire block sits inside the existing `try/catch` with `exit 0`, preserving silent degradation.

The "Code - Insiders" addition in the priority list is a good catch from the risk table in the design doc.

**`install.ps1` (hook script integration)**

Parent PID resolution via `(Get-Process -Id $PID).Parent.Id` with try/catch fallback to 0 is correct. The `.Parent` property is available in PS 5.1 on Windows 10+ (where WinRT toasts also work), so no compatibility concern. The `$parentPid` variable name doesn't collide with anything in the hook script scope.

**`scripts/notify.sh` (WSL placeholder)**

Both WSL and MSYS2 toast XML templates gain `launch="parentPid=0"`. This is a no-op placeholder (no activation handler in the inline PowerShell) that keeps the toast XML schema forward-compatible with Phase 2. The comment explains the intent.

**README.md / README_zh.md / llms.txt**

Documentation updates are minimal and accurate. The new sentence describes what happens (click focuses IDE window) and lists supported targets. Both language variants updated.

**ADR-001 compliance**

The implementation follows every decision point in the ADR: launch attribute (not protocol handler), P/Invoke (not COM AppActivate), AttachThreadInput (not keybd_event), process stays alive for dismissSeconds + 5s, zero registry footprint preserved.

## Test Assessment

38 new Pester tests in `tests/win-click-to-focus.Tests.ps1`. The tests are predominantly structural/static -- they parse the AST or search file content for expected patterns rather than executing the functions with mocked dependencies. This is a pragmatic choice given that `win-notify.ps1` is tightly coupled to WinRT (which only loads on PS 5.1 with the Windows runtime), making true unit testing of `Find-FocusableWindow` and `Set-WindowFocus` via dot-sourcing impractical without also loading the P/Invoke type.

The structural tests effectively verify the contract: parameter signatures, type constraints, default values, function existence, API call ordering (AttachThreadInput before SetForegroundWindow), event registration, cleanup, and backward compatibility of existing parameters. The AST-based tests (parameter acceptance, type constraint, Set-WindowFocus param block) are stronger than string matching because they verify parseable PowerShell, not just text patterns.

The test proportionality is appropriate for Phase 1 -- this is a UI interaction layer where the meaningful integration testing is manual (click a toast, observe window focus). The card documents manual QA as part of the validation plan.

Evidence of test execution: The card's executor summary reports 38/38 new tests pass and 360/360 existing tests pass. The commit message confirms zero regressions.

## Close-out Actions

- Merge the PR.
- Manual QA: fire a peon-ping notification on Windows 10/11, click the toast, verify the IDE/terminal window comes to the foreground.

## BACKLOG

**L1: Structural tests could be supplemented with behavioral mocks for Find-FocusableWindow.**
The priority chain logic (return first process with a visible window, in order) is the most important behavioral contract in this change. A Pester test that dot-sources just the function definition, mocks `Get-Process` to return controlled process objects, and asserts the return value would catch regressions that string-matching cannot (e.g., someone reorders the priority list or changes the `Where-Object` filter). This is non-blocking because the current structural tests do verify the priority list contents and the `MainWindowHandle` filter, but a behavioral test would be more robust. Worth adding in Phase 2 when the test file is already being extended.

**L2: Event queue not drained after activation.**
When the `Activated` event fires, `Get-Event` returns the event object but the code doesn't call `Remove-Event` to clear it from the queue. The `Unregister-Event` at cleanup removes the subscription but doesn't guarantee the queued event is removed. In practice this is harmless because the process exits shortly after, but it's a minor hygiene gap. If this script ever becomes long-lived (unlikely), stale events could accumulate.

**L3: WSL click-to-focus activation handler is deferred.**
The WSL path gets the `launch` attribute placeholder but no activation handler. The design doc's Open Question #2 explains why (inline PowerShell exits immediately, conflicts with `setsid &` backgrounding). This is correctly deferred, but worth tracking as a follow-up if WSL users request parity.
