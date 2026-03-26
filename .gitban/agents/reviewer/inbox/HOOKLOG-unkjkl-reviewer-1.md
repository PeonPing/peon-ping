---
verdict: APPROVAL
card_id: unkjkl
review_number: 1
commit: 65aaad1
date: 2026-03-26
has_backlog_items: true
---

## Summary

This commit adds `peon debug on/off/status` and `peon logs/--last/--session/--clear` CLI commands to the Windows PowerShell hook script (`peon.ps1` embedded in `install.ps1`), along with 27 Pester tests in a new test file. The implementation matches the design spec (docs/designs/structured-hook-logging.md, lines 407-438) and ADR-002's Phase 2 CLI requirements.

## Assessment

**Architecture and ADR compliance.** The implementation follows ADR-002's decisions faithfully: config-based boolean toggle, daily log files with `peon-ping-YYYY-MM-DD.log` naming, `session=` filtering for worktree correlation, and key=value log format consumption via the CLI. The commands map 1:1 to the design doc's CLI specification. The `debug` command modifies config.json via `ConvertFrom-Json`/`ConvertTo-Json` (whole-object round-trip), which is the established pattern in this codebase for config mutations that need to preserve all keys.

**DRY.** The `debug on` and `debug off` branches duplicate the culture-save/restore and config-read/write pattern (6 identical lines). This is a pre-existing pattern in install.ps1 -- the same culture-swapping sequence appears 4 times in the file before this commit. Extracting a `Set-PeonConfig` helper would reduce all 8 instances, but that refactoring crosses card boundaries. Tracked as a follow-up below.

**TDD evidence.** The test file covers the contract comprehensively: happy paths, edge cases (idempotent debug on, fewer-than-50 lines, no log files, unknown subcommands), failure paths (session not found, no logs to clear), and config preservation (debug on does not destroy other keys). The test structure leads the implementation -- each `Describe` block defines the expected behavior, not the implementation details. The executor's work log reports 27 Pester tests passing alongside full regression (360 adapters-windows + 29 hook-logging-windows tests).

**Test quality.** Tests use the shared `windows-setup.ps1` harness (`New-PeonTestEnvironment`, `Remove-PeonTestEnvironment`) which creates isolated temp directories with extracted `peon.ps1`, mock audio backends, and configurable overrides. The `Invoke-PeonCli` helper spawns a fresh `powershell.exe` process per test, which is realistic (matches how `peon.cmd` invokes the script) though slower than dot-sourcing. The `New-FakeLogFile` helper is well-scoped to this test file's needs without leaking into the shared harness.

**Security.** No secrets exposed. Config mutations use `ConvertTo-Json` (no string interpolation injection). `Remove-Item` targets only `peon-ping-*.log` files in the logs directory -- no path traversal risk. The `[int]$Arg2` cast in `--last` would throw on non-numeric input, which PowerShell surfaces as a terminating error -- acceptable behavior for a CLI tool.

**Help text.** The "Debug & Logs" section is appended to `--help` output in the correct location, after the existing sections. Command descriptions match the actual behavior.

**Checkbox integrity.** All checked `[x]` boxes in the card are truthful. The unchecked documentation box correctly notes that documentation is deferred to step 5. The "Output format matches Unix" checkbox is checked with a truthful note: step 4A (Unix) is not yet implemented, so Windows defines the reference format per the design doc.

## FOLLOW-UP

**L1: Extract a `Set-PeonConfig` helper to DRY the culture-swap + config-write pattern.** The culture-save, `ConvertTo-Json -Depth 10`, `Set-Content`, culture-restore sequence now appears 8 times in install.ps1 (4 pre-existing + 2 new in this commit + 2 from other recent work). A helper function would reduce each call site to 1-2 lines. This is non-blocking because the pattern is pre-existing and the new code follows the established convention, but it should be addressed before more config-mutating commands are added.

**L2: `--last` with non-numeric argument produces an unhandled terminating error.** `[int]$Arg2` throws `InvalidArgument` if the user passes `peon logs --last foo`. The other commands handle bad input gracefully (usage messages). Adding a `try/catch` or `-as [int]` pattern with a fallback usage message would be more consistent. Low priority since this is a developer CLI, not a public API.
