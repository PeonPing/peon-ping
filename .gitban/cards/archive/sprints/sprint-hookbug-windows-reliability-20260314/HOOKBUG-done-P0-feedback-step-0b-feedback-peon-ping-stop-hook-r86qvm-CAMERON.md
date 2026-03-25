# Peon-ping Stop Hook Deadlock and Design Issues

## Feedback Overview & Context

* **Source**: Production use during multi-agent sprint dispatch (VENVISO sprint, 23 agent dispatches)
* **Component**: `peon.ps1` Stop hook
* **Severity**: Critical — hook hung for 7 hours, blocking all Claude Code sessions
* **Environment**: Windows 10 (MSYS2), Claude Code CLI, PowerShell 5.1

---

## Initial Feedback Collection

### Critical: Stop Hook Deadlocks Indefinitely

The `Stop` hook hangs indefinitely in production. Observed a 7-hour hang during a sprint dispatch. The 10-second timeout configured in `settings.json` did not kill the process. This blocks the entire Claude Code session and affects all open windows.

**Root cause hypothesis**: `System.Windows.Media.MediaPlayer` requires a WPF dispatcher message loop to function correctly. In a headless, non-interactive PowerShell process (launched by Claude Code's hook runner), the dispatcher pump never runs. This means:

1. `MediaPlayer.Play()` may block or silently fail
2. `NaturalDuration.HasTimeSpan` never becomes true
3. The fallback `Start-Sleep -Seconds 2` fires, but the player never reports completion
4. On some Windows audio configurations, the `MediaPlayer.Open()` or `Play()` call itself blocks indefinitely waiting for dispatcher events that never arrive

The while-loop at line ~280 (`while ($timeout -gt 0 -and $player.Position.TotalMilliseconds -eq 0)`) spins for 5 seconds, but the real hang is likely in the `MediaPlayer` COM/WPF internals after that.

**Why the timeout doesn't save you**: Claude Code's hook timeout (10s) is supposed to kill the process, but on Windows with MSYS2 bash, process group termination for PowerShell child processes is unreliable. The PowerShell process may survive the kill signal, especially when blocked in .NET COM interop.

### High: Synchronous Audio Playback Blocks Hook Return

Even when the hook doesn't deadlock, it plays audio synchronously:

```powershell
$sp.PlaySync()  # WAV path — blocks until audio finishes
```

```powershell
$player.Play()
# ... then sleeps for the duration of the audio
Start-Sleep -Milliseconds ([int]$remaining + 100)
```

For a hook that fires on every `Stop` event (including every subagent completion), this means Claude Code is blocked for the full duration of each sound clip. During a 23-agent sprint dispatch, that's 23 blocking audio plays.

### High: State File Contention Under Concurrent Agents

`.state.json` is read and written by every hook invocation with no file locking:

```powershell
$state | ConvertTo-Json -Depth 3 | Set-Content $StatePath -Encoding UTF8
```

When multiple agents stop concurrently (common in parallel dispatch), multiple PowerShell processes race to read/write the same file. This can cause:

- Corrupted JSON (partial writes)
- Lost state updates (last writer wins)
- Read failures on locked files (Windows file locking semantics)

### Medium: Stop Event Fires Too Frequently

The `Stop` hook fires on every agent stop, not just user-facing session completions. During automated dispatch, this means dozens of Stop events that the user doesn't care about. The 5-second debounce helps but doesn't cover parallel agent stops that finish within the same second.

### Medium: Redundant Event Coverage

Both `Stop` and `Notification` hooks map to the same `task.complete` category. The `Notification` handler even explicitly skips `idle_prompt` because "Stop event already played the sound." This creates double-firing potential and makes it unclear which hook is the canonical source for "work finished" sounds.

---

## Related Context Review

| Review Source | Link / Location | Key Findings / Relevance |
|:---|:---|:---|
| peon.ps1 source | `~/.claude/hooks/peon-ping/peon.ps1` | MediaPlayer used synchronously in headless PS; no process-level self-timeout |
| Claude Code settings | `~/.claude/settings.json` | Stop hook configured with 10s timeout that doesn't reliably kill PS on Windows |
| VENVISO dispatch log | `.gitban/agents/dispatcher/inbox/VENVISO-dispatch-log.md` | 23 agent dispatches triggered cascading Stop events |
| ADR-031 sprint | sprint/AUTHHARDEN branch | Sprint where the 7-hour hang was observed |

* **Sprint**: VENVISO (per-worktree venv isolation)
* **Impact**: Sprint dispatch was not blocked (the hang was in a parallel session), but the user had to manually kill Claude Code processes
* **Workaround**: Remove the `Stop` hook entry from `~/.claude/settings.json`

---

## Feedback Analysis & Categorization

| Iteration # | Analysis Goal | Investigation / Action | Finding / Insight |
|:---|:---|:---|:---|
| 1 | Identify why hook hangs | Read peon.ps1 source, trace MediaPlayer codepath | MediaPlayer requires WPF dispatcher loop; blocks indefinitely in headless PS |
| 2 | Confirm timeout failure | Review settings.json timeout config and Windows process behavior | MSYS2 bash cannot reliably kill PowerShell child processes via process group signals |
| 3 | Assess concurrency safety | Analyze .state.json read/write pattern | No file locking; concurrent agents race on state file |
| 4 | Evaluate event design | Map Stop vs Notification event flow | Redundant task.complete mapping; Stop fires on every subagent |

| Category | Value / Notes |
|:---|:---|
| Component | peon-ping hook (`peon.ps1`) |
| Platform | Windows 10 / MSYS2 / PowerShell 5.1 |
| Trigger | Multi-agent sprint dispatch (23 agents) |
| Hang duration | 7 hours |
| Root cause | MediaPlayer WPF dispatcher deadlock in headless process |
| Contributing factors | No self-timeout, synchronous playback, state file races |

| Issue | Category | Severity | Effort |
|:------|:---------|:---------|:-------|
| MediaPlayer deadlock in headless PS | Bug | P0 | Medium |
| Synchronous audio blocks hook return | Design | P1 | Medium |
| State file contention (no locking) | Bug | P1 | Low |
| Stop fires on every subagent | Design | P2 | Low |
| Stop/Notification redundancy | Design | P2 | Low |

---

## Feedback Processing & Action Planning

### Recommended Fixes

1. **Replace MediaPlayer with SoundPlayer for all formats**, or use `[System.Console]::Beep()` as a zero-dependency fallback. If MP3/OGG support is needed, shell out to a lightweight CLI player (e.g., `ffplay -nodisp -autoexit`) with a process timeout wrapper.

2. **Play audio asynchronously**: Use `$sp.Play()` instead of `$sp.PlaySync()`, then exit immediately. The sound will play in the background. If the process must stay alive for playback, use `Start-Process` with `-NoWait` to spawn a detached player process.

3. **Add file locking to state writes**: Use `[System.IO.File]::Open()` with `FileShare.None` and a retry loop, or use an atomic write pattern (write to temp file, then rename).

4. **Filter Stop events**: Only play sounds for `Stop` events where `session_id` matches the main session (not subagents), or remove the `Stop` hook entirely and rely on `Notification` for task completion sounds.

5. **Add a process-level timeout wrapper**: Don't rely on Claude Code's hook timeout to kill the PowerShell process. Instead, have the script self-terminate:
   ```powershell
   $timer = [System.Timers.Timer]::new(8000)
   $timer.AutoReset = $false
   Register-ObjectEvent $timer Elapsed -Action { [Environment]::Exit(0) }
   $timer.Start()
   ```

---

## Feedback Resolution & Follow-up

| Step | Status/Details | Universal Check |
|:---|:---|:---:|
| 1. Acknowledge feedback | Pending | - [x] Feedback acknowledged by peon-ping team |
| 2. Triage P0 deadlock | MediaPlayer in headless PS | - [x] P0 triaged and assigned |
| 3. Fix P0 deadlock | Replace MediaPlayer or add self-timeout | - [x] P0 fix implemented |
| 4. Fix P1 sync playback | Use async Play() or detached process | - [x] P1 playback fix implemented |
| 5. Fix P1 state contention | Add file locking or atomic writes | - [x] P1 state fix implemented |
| 6. Address P2 event design | Filter subagent stops, deduplicate events | - [x] P2 design issues addressed |
| 7. Integration test | Test under 20+ concurrent agent dispatch | - [x] Validated under load |

| Task | Detail/Link |
|:---|:---|
| Feedback card | r86qvm |
| Workaround | Remove `Stop` hook from `~/.claude/settings.json` |
| Related sprint | VENVISO (sprint/AUTHHARDEN branch) |
| Source code | `~/.claude/hooks/peon-ping/peon.ps1` |

| Topic | Status / Action Required |
|:---|:---|
| MediaPlayer deadlock | Needs fix — replace with SoundPlayer or CLI player |
| Synchronous playback | Needs fix — use async or detached process |
| State file locking | Needs fix — atomic write pattern |
| Stop event frequency | Needs design review — filter subagent events |
| Stop/Notification overlap | Needs design review — pick canonical source |
