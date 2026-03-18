---
verdict: APPROVAL
card_id: z0c9fd
review_number: 1
commit: 0a67a57
date: 2026-03-14
has_backlog_items: true
---

## Review: Extract Get-ActivePack helper to DRY pack resolution

This commit resolves a merge conflict from a worktree merge that had reverted HOOKBUG sprint changes (atomic state writes, audio delegation, safety timer). It re-applies those HOOKBUG changes alongside the card's own work: extracting the `Get-ActivePack` helper to eliminate the duplicated pack resolution fallback chain.

### Card Scope vs. Commit Scope

The card scope is "extract Get-ActivePack helper to DRY pack resolution." The commit bundles three additional HOOKBUG restorations:

1. **Atomic state I/O** (`Write-StateAtomic`, `Read-StateWithRetry`) -- replaces bare `Set-Content` with temp-file-then-rename pattern and retry-on-read with backoff.
2. **Audio delegation** -- replaces inline `MediaPlayer`/`SoundPlayer` playback with `Start-Process` delegation to `win-play.ps1`.
3. **8-second safety timer** -- self-timeout via `System.Timers.Timer` to prevent hook hangs.

These are pre-existing changes from the HOOKBUG sprint that were lost in a `--theirs` merge and restored here. The card's actual net-new work (the `Get-ActivePack` extraction) is cleanly separated and correct.

### Get-ActivePack Extraction (Card Scope)

The helper is well-defined:

```powershell
function Get-ActivePack($config) {
    if ($config.default_pack) { return $config.default_pack }
    if ($config.active_pack) { return $config.active_pack }
    return "peon"
}
```

This correctly mirrors the Python-side fallback chain (`cfg.get('default_pack', cfg.get('active_pack', 'peon'))`). The function is defined in both the installer scope and the embedded peon.ps1 hook scope, which is the correct approach since the embedded hook is a separate script emitted as a here-string.

The 10 call sites are consistently replaced. The two test updates (`active_pack` -> `default_pack` in opencode and kilo installer tests) are correct -- those adapters now write `default_pack` in their generated configs.

### Atomic State I/O (HOOKBUG Restoration)

`Write-StateAtomic` uses delete-then-move, which is the correct pattern for NTFS same-volume atomicity on PS 5.1 where `[IO.File]::Move` lacks an overwrite parameter. The comment explaining the PS 7+ limitation is helpful.

`Read-StateWithRetry` uses a 3-attempt retry with progressive delays (50, 100, 200ms). The loop condition `$i -le $delays.Count` gives 4 iterations (indices 0-3), where the first 3 can sleep on failure and the 4th returns `@{}` on failure. This is correct.

### Audio Delegation (HOOKBUG Restoration)

The inline `MediaPlayer` block (which could deadlock in headless PowerShell) is replaced with:

```powershell
Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-NonInteractive", "-File", $winPlayScript, "-path", $soundPath, "-vol", $volume -WindowStyle Hidden
```

This delegates to `win-play.ps1` which uses a CLI player priority chain (ffplay > mpv > vlc) for non-WAV and `SoundPlayer` for WAV. The `-WindowStyle Hidden` prevents console flash. Sound and fury, delegated correctly.

### Test Changes

The Pester test updates are thorough:

- **win-play.ps1 tests**: Updated from asserting MediaPlayer presence to asserting MediaPlayer *absence*, plus positive assertions for ffplay/mpv/vlc volume normalization. Good negative testing.
- **Embedded peon.ps1 tests**: New assertions for the safety timer (System.Timers.Timer, 8000ms, Environment::Exit), audio delegation (Start-Process, win-play.ps1, WindowStyle Hidden), and atomic state (Write-StateAtomic). MediaPlayer/PresentationCore/SoundPlayer/System.Windows.Forms are now negative-asserted.
- **hook-handle-use.ps1 tests**: `agentskill` -> `session_override` rename verified.
- **install.ps1 default config test**: New assertion for ffmpeg recommendation when ffplay is missing.

204/204 Pester tests pass per the commit message.

### Minor Observation: Line Reorder in `packs list`

The diff shows a reorder in the `packs list` command where `$currentPack = Get-ActivePack $cfg` moved below `Write-Host "Available packs:"`. This is cosmetically fine -- it just prints the header before computing the active pack marker. No behavioral change.

## BACKLOG

- **L1**: `Write-StateAtomic` has a non-atomic window between `[IO.File]::Delete` and `[IO.File]::Move`. If the process is killed in that gap, state is lost. On PS 7+ this could use `Move-Item -Force` which is truly atomic. Worth adding a PS version check in a future hardening pass, though the risk is low given the sub-millisecond window.

- **L2**: The safety timer fires `[Environment]::Exit(1)` which skips `finally` blocks and cleanup. If state has been partially written at that point, it could leave a `.tmp` file behind. Consider whether `exit 1` (which runs trap handlers) would be safer, or add a `.tmp` cleanup check on next startup in `Read-StateWithRetry`.
