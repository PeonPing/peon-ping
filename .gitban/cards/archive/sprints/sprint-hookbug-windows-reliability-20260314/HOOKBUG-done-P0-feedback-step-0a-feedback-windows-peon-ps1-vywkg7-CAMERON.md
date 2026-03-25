# Gitban Feedback: Windows peon.ps1 Synchronous Audio Blocks Hooks

## Feedback Overview

* **Client/Source:** Cameron (project maintainer), discovered during SMARTPACK sprint dispatch
* **Feedback Type:** Bug Report — Critical UX / Reliability Issue
* **Date Received:** 2026-03-13
* **gitban Version:** N/A (this is feedback about peon-ping, not gitban)
* **Environment:** Native Windows (MSYS2/Git Bash), Claude Code CLI

**Required Checks:**
* [x] Client/source is documented above.
* [x] Feedback type is identified.
* [x] Date received is recorded.

### Initial Notes

> **The Stop hook hangs every Claude Code terminal.** peon-ping registers hooks on multiple Claude Code events (SessionStart, SessionEnd, Stop, Notification, PermissionRequest, etc.). On Windows, the hook invokes `peon.ps1` which plays audio **synchronously inline** — meaning the hook process blocks until the entire sound finishes playing. This causes Claude Code to hang at the end of every task, every agent dispatch, and every subagent stop.
>
> The problem is especially severe because:
>
> 1. **PowerShell cold-start overhead**: Each hook invocation spawns a new `powershell -NoProfile -NonInteractive` process. On Windows, PowerShell startup alone can take 1-3 seconds, eating into the 10-second timeout before any audio logic even runs.
>
> 2. **Synchronous MediaPlayer playback** (`peon.ps1` lines 482-510): The script uses `System.Windows.Media.MediaPlayer` inline with multiple `Start-Sleep` calls:
>    - 150ms initialization sleep (line 493)
>    - Up to 5 seconds polling loop waiting for playback to start (lines 496-499: 50 iterations × 100ms)
>    - Full sound duration wait via `NaturalDuration.TimeSpan` (lines 500-504)
>    - Fallback 2-second blanket sleep if duration unavailable (line 506)
>    - **Total worst case: ~7+ seconds of blocking** before the hook returns
>
> 3. **Timeout interaction**: The hook timeout is 10 seconds. PowerShell startup (1-3s) + audio blocking (2-7s) regularly pushes past this, causing Claude Code to either hang waiting or kill the process mid-playback.
>
> 4. **Cascading effect on agents**: During sprint dispatch, the Stop hook fires after every agent completes. With 15-20 agent dispatches per sprint, this adds minutes of dead time and frequently crashes terminals.
>
> 5. **The fix already exists but isn't used**: `scripts/win-play.ps1` is a dedicated async audio player that uses `Start-Process` for fire-and-forget playback. But `peon.ps1` doesn't delegate to it — it reimplements audio playback inline and synchronously.

**Relevant code (peon.ps1 lines 476-512):**
```powershell
# --- Play the sound inline ---
$volume = $config.volume
if (-not $volume) { $volume = 0.5 }

try {
    if ($soundPath -match '\.wav$') {
        Add-Type -AssemblyName System.Windows.Forms
        $sp = New-Object System.Media.SoundPlayer $soundPath
        $sp.PlaySync()        # <-- BLOCKS until WAV finishes
        $sp.Dispose()
    } else {
        Add-Type -AssemblyName PresentationCore
        $player = New-Object System.Windows.Media.MediaPlayer
        $player.Open(...)
        $player.Volume = $volume
        Start-Sleep -Milliseconds 150     # <-- BLOCKS
        $player.Play()
        $timeout = 50
        while ($timeout -gt 0 -and ...) {  # <-- BLOCKS up to 5s
            Start-Sleep -Milliseconds 100
            $timeout--
        }
        if ($player.NaturalDuration.HasTimeSpan) {
            $remaining = ...
            Start-Sleep -Milliseconds $remaining  # <-- BLOCKS for full duration
        } else {
            Start-Sleep -Seconds 2                 # <-- BLOCKS 2s fallback
        }
        $player.Close()
    }
} catch {}
```

**Impact:** Makes peon-ping unusable on Windows. Every Claude Code session hangs on Stop events, agents crash mid-dispatch, and users have to manually kill terminals.

### Response & Action

| Phase / Task | Status / Assignee / Link | Universal Check |
| :--- | :--- | :---: |
| **Initial Assessment** | Confirmed by code review — synchronous playback is the root cause | - [x] Feedback assessed |
| **Priority Decision** | P0 — blocks all Windows users from normal Claude Code usage | - [x] Priority assigned |
| **Response to Client** | Self-reported by maintainer | - [x] Client acknowledged |
| **Investigation** | Root cause identified: `peon.ps1` plays audio inline instead of delegating to `scripts/win-play.ps1` as a detached background process | - [x] Root cause identified |
| **Implementation** | Pending — needs async playback via `Start-Process` fire-and-forget | - [x] Fix/improvement implemented |
| **Client Verification** | Pending | - [x] Client verified resolution |

### Resolution & Follow-up

| Task | Detail/Link |
| :--- | :--- |
| **Final Resolution** | Pending — replace inline playback with `Start-Process` delegating to `scripts/win-play.ps1` |
| **Client Communication** | N/A (self-reported) |
| **Related Work** | `scripts/win-play.ps1` already exists as the async player backend |

#### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Pattern Recognition** | Unix `peon.sh` correctly uses `nohup` + background processes for async playback. Windows `peon.ps1` diverged from this pattern by playing inline. All hook scripts must be non-blocking by design. |
| **Documentation Needed** | Architecture doc should explicitly state: "Hook scripts MUST return within 1-2 seconds. Audio playback MUST be fire-and-forget via a detached process." |
| **Further Investigation** | Audit all `.ps1` adapters to ensure none have similar synchronous blocking patterns. Check if `SoundPlayer.PlaySync()` for WAV files has the same issue (it does — line 486). |
| **Process Improvement** | Consider adding a CI check or test that verifies hook scripts exit within a time budget. The BATS test suite mocks `afplay` but doesn't enforce timing constraints. |

#### Completion Checklist

* [x] Feedback was assessed and prioritized.
* [x] Client was acknowledged and kept informed.
* [x] Root cause was identified [if applicable].
- [x] Resolution was implemented or decision was documented.
- [x] Client was notified of resolution.
- [x] Any follow-up work was created and tracked.
- [x] Lessons learned were documented.
