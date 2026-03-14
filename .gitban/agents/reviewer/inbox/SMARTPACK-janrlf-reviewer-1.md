---
verdict: APPROVAL
card_id: janrlf
review_number: 1
commit: 0a67a57
date: 2026-03-14
has_backlog_items: true
---

## Review Context

Card janrlf is a documentation card. Its actual documentation work was completed in commit `c998fa3` (README.md, README_zh.md, docs/public/llms.txt updates for pack selection hierarchy). That commit is not the one under review.

Commit `0a67a57` is a merge conflict resolution that restores HOOKBUG sprint changes that were reverted by a `--theirs` merge strategy in a prior worktree merge. The code changes in this commit span two concerns:

1. **HOOKBUG restorations**: atomic state writes (`Write-StateAtomic`, `Read-StateWithRetry`), audio delegation to `win-play.ps1` via `Start-Process`, and the 8-second self-timeout safety timer -- all previously reviewed and approved under the HOOKBUG sprint.
2. **Get-ActivePack refactor**: owned by card z0c9fd, already reviewed in `SMARTPACK-z0c9fd-reviewer-1.md`.

This review evaluates the merge conflict resolution commit for correctness -- whether the restored code faithfully matches the HOOKBUG-approved patterns and the z0c9fd refactor, and whether the test updates are aligned.

## Code Assessment

### Atomic State I/O (ADR-001 compliance)

The `Write-StateAtomic` function implements the ADR-001 pattern correctly:
- Writes to a PID-scoped temp file in the same directory (same NTFS volume)
- Uses `[System.IO.File]::Move()` for the rename
- Cleans up the temp file on failure
- Comment correctly explains the PS 5.1 compatibility reason for delete-then-move

The `Read-StateWithRetry` function implements the ADR-001 retry spec (3 attempts, 50/100/200ms backoff) and falls back to empty state on exhaustion.

Both state write sites (post-category-mapping and post-last-played) now use `Write-StateAtomic`. Correct.

### Audio Delegation (ADR-001 compliance)

The inline SoundPlayer/MediaPlayer block (~30 lines) is replaced with a single `Start-Process` delegation to `win-play.ps1`. The invocation matches the ADR-001 spec exactly: `-NoProfile`, `-NonInteractive`, `-File`, `-WindowStyle Hidden`. The hook now returns immediately after spawning the detached process.

### Safety Timer (ADR-001 compliance)

The 8-second `System.Timers.Timer` with `[Environment]::Exit(1)` is correctly scoped to hook mode only (`if (-not $Command)`), preventing it from firing during CLI commands like `peon packs list`.

### Test Updates

Tests are updated to match the new implementation:
- `win-play.ps1` tests now validate the CLI player priority chain (ffplay, mpv, vlc) with correct volume normalization assertions, and assert the absence of MediaPlayer/PresentationCore
- `peon.ps1` embedded hook tests assert the absence of all inline audio APIs (MediaPlayer, PresentationCore, SoundPlayer, System.Windows.Forms) and validate `Start-Process` delegation
- State management test updated from `ConvertTo-Json.*Set-Content` pattern to `Write-StateAtomic`
- Self-timeout test added (System.Timers.Timer, 8000, Environment::Exit)
- `hook-handle-use.ps1` test updated from `agentskill` to `session_override`
- OpenCode/Kilo installer tests updated from `active_pack` to `default_pack`
- ffmpeg recommendation test added for install output

All test changes verify behavior, not implementation details. The negative assertions (Should -Not -Match) are appropriate here -- they enforce that removed APIs stay removed.

### Get-ActivePack Integration

The two call sites at the installer end (`testPack` and `activePack`) were updated to avoid piping the config object directly into `Get-ActivePack`. The original code `Get-ActivePack (Get-PeonConfigRaw $configPath | ConvertFrom-Json)` used pipeline syntax that could pass the wrong object. The fix assigns to `$cfg` first, then calls `Get-ActivePack $cfg`. This is a genuine bug fix in the refactor integration.

The `packs list` reorder (moving `Write-Host` before `Get-ActivePack`) has no behavioral impact -- cosmetic only.

### Checkbox Integrity

All checked boxes on card janrlf reference documentation work completed in commit `c998fa3`, not this commit. The work summary correctly references that commit. The checkboxes are truthful.

## BLOCKERS

None.

## BACKLOG

**L1: Write-StateAtomic delete-then-move is not truly atomic under concurrent access.**

The comment says "atomic on NTFS same-volume" but the delete-then-move pattern has a window where the file does not exist (between `Delete` and `Move`). If a concurrent `Read-StateWithRetry` hits that window, it gets `Test-Path` returning false and returns empty state. The retry logic mitigates this (the window is microseconds and the retry delays are 50-200ms), but it is not the same guarantee as a true atomic rename. On PowerShell 7+ `[System.IO.File]::Move($src, $dst, $true)` provides a true atomic overwrite. The ADR acknowledges PS 5.1 compat as the constraint. This is acceptable for now -- the retry-on-read makes data loss extremely unlikely -- but worth revisiting when PS 5.1 support is eventually dropped.

**L2: ffmpeg recommendation could link to install docs.**

The new `winget install ffmpeg` recommendation in the installer output is helpful, but `winget install ffmpeg` installs the Gyan build which may not add `ffplay` to PATH automatically. Consider adding a note or linking to project docs if users report confusion.
