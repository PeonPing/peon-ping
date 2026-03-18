---
verdict: REJECTION
card_id: jwh5zl
review_number: 1
commit: 3f622ac
date: 2026-03-15
has_backlog_items: true
---

## Summary

This commit adds `tests/peon-security.Tests.ps1` (366 lines, 16 Pester 5 tests) covering security boundaries in `hook-handle-use.ps1` (path traversal, injection, session ID sanitization, state mutations) and `win-play.ps1` (WAV/MP3 branching, volume clamping, player priority chain). The test structure is solid: full isolation per test via GUID temp dirs, mock CLI players via PATH manipulation, and process-level isolation using wrapper scripts for clean exit code propagation.

The architecture is well-considered. The `cmd.exe /c "type ... | powershell.exe -File ..."` technique for stdin piping is the correct workaround for `[Console]::OpenStandardInput()` not reading the PowerShell pipeline. The mock player `.cmd` batch files with argument logging are clean and inspectable. The helper functions (`New-PeonTestEnv`, `Invoke-HookCli`, `Invoke-HookStdin`, `Invoke-WinPlay`, `New-MockPlayer`) provide good abstraction without over-engineering.

One blocker: two tests assert the wrong value for `pack_rotation_mode`.

## BLOCKERS

**B1: Scenarios 1 and 7 assert `"agentskill"` but the source sets `"session_override"`.**

`hook-handle-use.ps1` line 137 sets `pack_rotation_mode` to `"session_override"`:

```powershell
$config | Add-Member -NotePropertyName "pack_rotation_mode" -NotePropertyValue "session_override" -Force
```

But the tests assert a different value:

- Scenario 1 (line 152): `$config.pack_rotation_mode | Should -Be "agentskill"`
- Scenario 7 (line 222): `$config.pack_rotation_mode | Should -Be "agentskill"`

These tests will fail against the current source. The assertions must match what the source actually writes. Change both to `Should -Be "session_override"`.

**Refactor plan:** Two-line fix -- replace `"agentskill"` with `"session_override"` on lines 152 and 222 of `tests/peon-security.Tests.ps1`.

## BACKLOG

**L1: Scenario 5 does not assert exit code for CLI-mode "pack not found".** The test verifies output text ("not found", "peon") but does not check the exit code. In the current source, `hook-handle-use.ps1` calls `Write-Response` + `exit 0` for missing packs even in CLI mode (lines 110-123), which is inconsistent with how other CLI-mode errors return `exit 1` (lines 76, 99). This is arguably a bug in the source rather than the test, but the test should still assert the exit code to document the current behavior -- either `$r.ExitCode | Should -Be 0` (documenting the current behavior) or, if the source is fixed to return `exit 1` in CLI mode for missing packs, `$r.ExitCode | Should -Be 1`.

**L2: VLC gain assertion is loose.** Scenario 15 asserts `Should -Match "--gain 1"` which would also match `--gain 10`, `--gain 100`, etc. A tighter pattern like `"--gain 1(\.\d+)?(\s|$)"` or `"--gain 1\.0"` would be more precise. Not a functional issue today since the only value tested is `0.5 * 2.0 = 1.0`, but would mask bugs if the test matrix is ever expanded.
