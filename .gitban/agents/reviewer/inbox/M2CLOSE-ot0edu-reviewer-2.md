---
verdict: APPROVAL
card_id: ot0edu
review_number: 2
commit: 7011e78
date: 2026-03-25
has_backlog_items: false
---

## Rework Assessment

Both blockers from review 1 are resolved.

**B1 (Pester race condition):** All 8 hook-mode tests now use a polling loop that checks for `.notify-log.txt` every 100ms with a 5-second deadline. The pattern is consistent across all tests and eliminates the non-deterministic failure from the fixed `Start-Sleep -Milliseconds 500`. Fast machines exit in ~200ms; slow CI runners get the full 5 seconds. Correct fix.

**B2 (Extract `Resolve-NotificationTemplate`):** The function is now extracted as a standalone named function placed at line 492, between `Read-StateWithRetry` and the CLI commands block. The function signature matches the design doc interface (9 parameters covering all 5 template keys and 5 variables). Two minor deviations from the design doc are both justified:

1. Parameter type is `[object]` instead of `[hashtable]` -- correct, because `ConvertFrom-Json` produces `PSCustomObject`, not `hashtable`. The design doc was aspirational; the implementation matches the actual runtime type. Property access via `$Templates.$tplKey` works for both types.

2. Uses `.Replace()` loop + `[regex]::Replace()` instead of `-replace` with scriptblock -- justified because the function lives inside a `@'...'@` single-quoted here-string where scriptblock parsing is ambiguous. The `.Replace()` loop for known variables is equivalent, and the single-line `[regex]::Replace($rendered, '\{(\w+)\}', '')` for unknown variables replaces the 20-line character-by-character loop flagged in review 1. Clean improvement.

## Code Quality Assessment

**CLI implementation:** The `--notifications` switch case follows the established `--trainer` subcommand pattern exactly: outer regex `^--(notifications|popups)$` with inner switch on `$notifSub`. The `--popups` alias is handled by regex alternation rather than duplicated code. Template get/set/reset, on/off toggle, and help text all produce output matching the design doc format.

**Template resolution placement:** Correctly inserted between event processing and notification dispatch (line 1929-1947). The guard `if ($notify)` and `if ($tplCfg)` ensure zero-cost path when no templates are configured, preserving existing behavior for users without templates.

**`$parentPid` fix:** Both notification dispatch locations (trainer at line 1916 and main at line 1960) now handle the PS 5.1 incompatibility where `Get-Process.Parent` is PS 6+ only. The fix checks `if ($proc.Parent)` before accessing `.Id`, with a fallback to 0. Applied consistently in both locations.

**`Start-Process -ArgumentList` quoting fix:** Both dispatch sites now wrap `-body` and `-title` values in escaped quotes and cast `-dismissSeconds` and `-parentPid` to `[string]`. This fixes argument splitting for values containing spaces.

**Tests:** 20 tests covering syntax validation (1), template CLI (13), and notifications CLI (6). Test helpers (`New-TestInstall`, `Invoke-PeonCli`, `Invoke-PeonHook`, `Get-TestConfig`, `Get-NotifyLog`) follow the established `trainer-windows.Tests.ps1` pattern. Hook-mode tests use a notify stub that logs BODY/TITLE to a file for assertion. Each test creates an isolated temp directory and cleans up in a `finally` block.

**TDD evidence:** The test file covers all 19 scenarios from the design doc's test strategy sections (Phase 1: 13, Phase 2: 6) plus 1 syntax validation test. Tests assert on behavioral contracts (CLI output format, config state changes, rendered notification body) rather than implementation internals. Failure cases are covered (invalid template key exits with code 1, missing summary renders empty, unknown variables render empty).

## Close-out Actions

- CI green on Windows runner (verify post-merge -- acceptance criterion is already marked deferred on the card)
