---
verdict: APPROVAL
card_id: d5wz2f
review_number: 1
commit: 57964e9
date: 2026-03-14
has_backlog_items: true
---

## Summary

This change eliminates the P0 deadlock and synchronous blocking in the Windows hook audio path by (1) replacing inline SoundPlayer/MediaPlayer code in the embedded peon.ps1 with a single `Start-Process` delegation to `scripts/win-play.ps1`, (2) rewriting win-play.ps1 to remove MediaPlayer entirely and use a CLI player priority chain for non-WAV formats, (3) adding an 8-second self-timeout safety net, and (4) printing an ffmpeg install recommendation post-install. All changes align with ADR-001 Phase 1.

## Review

The diff is clean, surgical, and well-scoped. Each change maps directly to ADR-001 Phase 1 requirements with no scope creep.

**Architecture alignment with ADR-001**: The detached process model (`Start-Process -WindowStyle Hidden`), the CLI player priority chain (`ffplay` -> `mpv` -> `vlc`), the `System.Timers.Timer` self-timeout, and the MediaPlayer removal all match the ADR's decision and rationale. The minor deviation from the ADR (omitting `-PassThru` on `Start-Process`) is functionally equivalent -- without `-PassThru`, `Start-Process` returns no object, so `| Out-Null` is a no-op. Not a concern.

**win-play.ps1 rewrite**: The CLI player chain mirrors `peon.sh`'s `play_linux_sound()` pattern. Volume normalization is correct: ffplay and mpv use `int($vol * 100)` clamped to 0-100, matching the Unix implementation. VLC uses `$vol * 2.0` for its 0.0-2.0 gain scale with `InvariantCulture` formatting to avoid locale-dependent decimal separators -- good attention to detail. The VLC path resolution handles both `Get-Command` results (`ApplicationInfo.Source`) and `Get-Item` results (`FileInfo.FullName`) correctly. The `SoundPlayer` path correctly removes the unnecessary `Add-Type -AssemblyName System.Windows.Forms` that was previously loaded -- `System.Media.SoundPlayer` is available by default in PowerShell without loading the Forms assembly.

**Self-timeout**: Correctly guarded by `if (-not $Command)` so it only fires in hook mode, not CLI mode (`peon --status`, `peon --toggle`, etc.). Uses `System.Timers.Timer` (thread pool timer) rather than `Forms.Timer` (message pump timer), which is the correct choice for headless PowerShell. `[Environment]::Exit(1)` is the right termination method -- it tears down the process immediately without running finally blocks that could themselves block.

**Embedded peon.ps1 delegation**: The inline audio block (30+ lines of SoundPlayer/MediaPlayer code with sleep loops, timeout counters, and duration polling) is replaced with 4 lines: volume default, path join, existence check, Start-Process. This is a significant complexity reduction.

**Test coverage**: Tests are updated symmetrically -- old assertions for MediaPlayer/SoundPlayer presence are replaced with assertions for their absence. New assertions verify the Timer, Start-Process delegation, CLI player chain, and volume normalization. The tests are content-matching (regex against file content), which is the established pattern in this test suite. The ffmpeg recommendation test in the "install.ps1 Default Config" describe block is correctly placed.

**Acceptance criteria audit**: All 10 checked boxes are truthful. I verified each against the diff and current file state.

## BLOCKERS

None.

## BACKLOG

**L1: `Start-Process` without `-PassThru` makes `| Out-Null` a no-op.** The pipe to `Out-Null` on line 806 of install.ps1 does nothing because `Start-Process` without `-PassThru` returns no output. Either add `-PassThru` (matching the ADR example) or remove `| Out-Null`. Cosmetic only -- no functional impact.

**L2: Silent failure when `win-play.ps1` is missing.** The `if (Test-Path $winPlayScript)` guard on line 805 silently skips audio if the script doesn't exist. This is reasonable as a defensive check, but a corrupted install where win-play.ps1 is missing would produce no sound with no diagnostic output. Consider logging to stderr in a future pass.

**L3: `catch {}` swallows all exceptions in WAV playback path.** Both in the embedded peon.ps1 state write (line 797-798) and in win-play.ps1 WAV path (line 10-14), empty catch blocks swallow errors silently. This is pre-existing (carried over from the old code), but worth addressing in a future reliability pass -- at minimum, logging to a debug file or stderr when a `$DebugPreference` is set.
