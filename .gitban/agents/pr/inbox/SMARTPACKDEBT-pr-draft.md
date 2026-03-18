# sprint/SMARTPACKDEBT: Resolve tech debt from SMARTPACK sprint reviews

## Motivation

The SMARTPACK sprint (v2.15.1 -> v2.16.0) delivered path_rules, config key renames, and Windows CLI parity, but reviewers flagged four non-blocking quality issues across the delivered cards. Left unresolved, these create a shell quoting bug class that could recur in future peon.sh changes, a sub-millisecond state corruption window on Windows, confusing ffplay install guidance, and duplicated config I/O patterns that make the bind/unbind CLI harder to maintain. This sprint systematically closes all four items.

Lands as v2.15.2 (patch -- all fixes, no new user-facing features).

## What changed

**Shell quoting safety in peon.sh** (card dsmh31, P1)
Audited all 61 `python3 -c` invocations in peon.sh. Found 3 hazardous patterns across 7 call sites where escaped double quotes inside bash double-quoted strings could silently break: dict bracket access (`r[\"key\"]`), method arguments with escaped string literals, and docstrings using `\"\"\"`. Fixed by extracting dict access to temp variables with single-quoted `.get()` calls and converting docstrings to `'''`. The remaining 30 display-string `\"` occurrences are safe (POSIX-defined behavior) and left unchanged.

**Windows atomic state I/O hardening** (card exg19y, P2)
`Write-StateAtomic` in the embedded peon.ps1 hook now branches on PowerShell version: PS 7+ uses `Move-Item -Force` for a truly atomic overwrite with no delete gap, while the PS 5.1 delete-then-move fallback is preserved. `Read-StateWithRetry` now scans for and removes orphaned `.tmp` files on startup, guarding against partial writes left behind when the 8-second safety timer fires `[Environment]::Exit(1)` (which skips `finally` blocks).

**Windows ffplay install guidance** (card ji2847, P2)
The post-install tip when ffplay is not on PATH now recommends `choco install ffmpeg` as the primary option (adds ffplay to PATH automatically), warns that `winget install ffmpeg` installs the Gyan build which may not add ffplay to PATH, and provides manual PATH fallback instructions.

**Windows CLI bind/unbind quality** (card inexon, P2)
This card went through two review cycles. The first submission was rejected with 6 blockers (runtime path_rules engine deleted, --status display lost, out-of-scope regressions to Get-ActivePack and Write-StateAtomic, ffmpeg guidance removed, and functional E2E tests replaced with weaker unit tests). Cycle 2 resolved all blockers:
- Added `Get-ActivePack` helper with `default_pack -> active_pack -> "peon"` fallback chain, matching peon.sh behavior
- Restored the runtime `path_rules` matching engine (first-match-wins glob evaluation of `$event.cwd` against configured rules)
- Added bind/unbind/bindings subcommands with `--pattern` and `--install` flags, plus `Update-PeonConfig` shared helper to eliminate duplicated config I/O
- Restored `--status` path_rules display (shows active rule or configured count)
- bind `--install` now shows per-file download progress instead of running silently
- 37 new Pester tests including 10 functional E2E tests that extract the embedded hook script and invoke it via `powershell.exe`

## Verification

- **peon.sh**: `bash -n peon.sh` passes. Python `compile()` validation passes on all embedded blocks. BATS tests updated across 12 test files to use `default_pack` instead of `active_pack` in fixtures.
- **install.ps1**: 241 Pester tests pass (37 new), 0 failures. Functional E2E tests exercise the real hook script extracted to a temp directory with mock packs and config.
- **Rework**: Card inexon required a second review cycle (6 blockers resolved). All other cards approved on first review.
- **Limitation**: Full BATS suite was not run locally (Windows worktree). CI will validate on macOS. Bash syntax checks and Python compile checks passed locally.

## Risks and limitations

- The `Write-StateAtomic` PS 7+ path uses `Move-Item -Force` which has different error semantics than the .NET `File.Move` call. In practice both are atomic on NTFS same-volume moves, but error messages on failure will differ between PS versions.
- Card 26yooi (`Write-StateAtomic` upgrade to 3-arg `[IO.File]::Move` with overwrite) remains blocked on dropping PowerShell 5.1 support -- this sprint's PS version branch is the interim solution.
- The bind `--install` flag uses sequential downloads with progress feedback rather than true parallelism. `ForEach-Object -Parallel` requires PS 7+ and would break PS 5.1 compatibility.

## How to review

The diff is 229 files / +16,060 lines, but the vast majority is gitban agent infrastructure (traces, review logs, executor inboxes, templates, sprint archives). The production changes worth reviewing:

- **`peon.sh`** -- ~30 lines changed. The quoting fixes at lines 1677, 2215, and 2877 are the substantive changes. Search for `.get('` to see the pattern.
- **`install.ps1`** -- ~300 lines changed. Key sections: `Get-ActivePack` helper (line 36), `Write-StateAtomic` PS7+ branch (line 812), `.tmp` cleanup in `Read-StateWithRetry` (line 827), bind/unbind/bindings CLI (lines 438-667), path_rules runtime engine (lines 964-1023).
- **`tests/adapters-windows.Tests.ps1`** -- +287 lines. New structural and functional E2E tests.
- **Test fixture updates** across 12 `.bats` files -- mechanical `active_pack` -> `default_pack` renames, safe to skim.
- **CHANGELOG.md**, **VERSION** -- version bump to 2.15.2.
- Everything under `.gitban/` is agent traces, card archives, and sprint metadata -- skip unless auditing the agent workflow.

## Deferred work

| Item | Disposition |
|---|---|
| 26yooi -- `Write-StateAtomic` 3-arg `[IO.File]::Move` upgrade | Backlog, blocked on PS 5.1 deprecation |
| 5efwxz -- `Update-PeonConfig` skip-write optimization | Backlog (reviewer suggestion from inexon review 2) |
| laimst -- Harden `--install` flag E2E tests, registry fallbacks, help text | Backlog (reviewer suggestion from inexon review 2) |
| csedqi -- Pre-commit check for python3 bash quoting hazards | Backlog (process improvement from dsmh31) |
| gtb6dm -- Formal Pester tests for state I/O helpers | Backlog (reviewer suggestion from exg19y) |

## Sprint metrics

| Metric | Value |
|---|---|
| Cards completed | 5 (1 P0 sprint card, 1 P1 chore, 3 P2 chores) |
| Review cycles | 6 total (4 first-pass approvals, 1 rejection + rework + approval) |
| Follow-up cards created | 5 (all backlog) |
| Version | 2.15.1 -> 2.15.2 |
| Production files changed | 4 (peon.sh, install.ps1, CHANGELOG.md, VERSION) |
| Test files changed | 13 |
| New Pester tests | 37 |
