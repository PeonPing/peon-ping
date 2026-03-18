---
verdict: APPROVAL
card_id: q52ygy
review_number: 1
commit: 0d965db0b56917726b9bfcdabd52842df58d4e0c
date: 2026-03-15
has_backlog_items: true
---

## Summary

This commit delivers a shared Pester test harness (`tests/windows-setup.ps1`) and 25 smoke tests (`tests/peon-engine.Tests.ps1`) that validate the harness infrastructure and core peon.ps1 behavior on Windows. The CI workflow is updated to run the new test file alongside the existing adapter tests.

The implementation is solid. The harness mirrors the proven BATS pattern from `tests/setup.bash` -- isolated temp directories, mock audio backend, deterministic teardown -- adapted correctly for PowerShell and Pester 5. The code is well-structured with clear function boundaries, thorough docstrings, and appropriate error handling.

Key observations:

**Architecture alignment.** The harness correctly uses `openpeon.json` (matching peon.ps1's manifest filename), includes `sounds/` prefixes in manifest paths (matching the real pack format), and resolves `$InstallDir` via `$MyInvocation.MyCommand.Path` by using `-File` invocation. These are production-accurate decisions.

**Test isolation.** Each test creates a GUID-named temp directory with fresh config/state/packs, cleaned up in AfterEach/AfterAll. No shared mutable state between tests. No network access, no real audio playback. The mock `win-play.ps1` logs to `.audio-log.txt` with `path|volume` format -- clean and inspectable.

**Process management.** `Invoke-PeonHook` uses `System.Diagnostics.Process` with async stdout/stderr reads to avoid deadlocks, a configurable timeout with `Kill()` fallback, and a 3-second polling loop for the detached audio log. The `finally` block ensures `Dispose()` is always called.

**PS 5.1 compatibility.** All `Join-Path` calls use the 2-argument form (PS 5.1 does not support 3+ positional args). This is a deliberate and correct decision noted in the work summary.

**CI integration.** The workflow change correctly passes an array to `$config.Run.Path`, which is the Pester 5 way to run multiple test files in a single configuration.

## BLOCKERS

None.

## BACKLOG

**L1: Dead environment variables in Invoke-PeonHook.** `CLAUDE_PEON_DIR` and `PEON_TEST` are set in the `ProcessStartInfo.Environment` but peon.ps1 never reads either variable. The isolation works because `-File` causes `$MyInvocation.MyCommand.Path` to resolve inside the test directory. The env vars are harmless but misleading -- a future contributor might assume peon.ps1 respects them. Consider either removing them from the harness or adding a comment explaining they exist for parity with the BATS harness (which does use `PEON_TEST` in `peon.sh`).

**L2: Locale-dependent decimal separator in config serialization.** Line 207 of `windows-setup.ps1` applies a regex `(?<=\d),(?=\d)` to fix decimal commas from `ConvertTo-Json` on non-English locales. This is a known PowerShell 5.1 issue. The fix works for `0,5` -> `0.5` but would also affect any integer sequences separated by commas (e.g., inside JSON arrays like `[1,2,3]` -> `[1.2.3]`). In practice this is unlikely to bite because the current config has no integer arrays, but if `categories` or other array-valued keys are ever added to the config, this regex would corrupt them. A safer approach would be to force `[System.Threading.Thread]::CurrentThread.CurrentCulture` to invariant before serialization, or to target only the `volume` key specifically.

**L3: Extraction regex fragility.** The regex `hookScript = @'(.+?)'@` assumes there is exactly one PowerShell here-string in install.ps1 matching this pattern. Currently true (only one `'@` terminator at line 1102), but if a second here-string is ever added to install.ps1 for a different purpose, the non-greedy match would still grab the first one, which could silently break if the hook script is no longer the first here-string. A more robust approach would be to anchor on a unique marker comment inside the here-string (e.g., `# peon-ping hook for Claude Code`).
