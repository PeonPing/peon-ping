# PRD-002: Hook Observability — Structured Logging for peon-ping

> **Status**: Draft | **Date**: 2026-03-25 | **Author**: cameron
> **Roadmap**: v2/m4/hook-observability

## Problem Statement

When peon-ping misbehaves — a sound doesn't play, a hook times out, a notification vanishes — users have zero visibility into what happened. The only diagnostic tool is a commented-out `echo` line in `peon.sh` that dumps raw input to `/tmp`. On Windows, nothing exists at all. Users experiencing issues (#402, #397) can only report "it doesn't work" because there's no log to attach, no timing data to share, and no way to distinguish between "the hook timed out," "the config was wrong," "the pack manifest was missing," or "the audio backend failed." This is especially painful in worktree-heavy workflows where multiple agent sessions fire hooks concurrently against shared state, and in remote/SSH environments where the relay adds another failure surface.

Peon-ping's silent-failure-by-design philosophy (every `try/except` falls back to defaults) means the system *works* even when it's broken — users don't crash, but they also don't know why their GLaDOS pack stopped playing two hours ago.

## Background & Context

### Why now

Three converging pressures:

1. **Windows native launch (v2.16)** brought a second codebase (the Windows hook script, embedded as a ~1,650-line here-string in `install.ps1` and deployed as `peon.ps1` at install time) with its own failure modes. The `PEON_DEBUG=1` env var in `win-play.ps1` is the *only* diagnostic surface on Windows, and it only covers audio playback — not config loading, event routing, pack selection, or state management.

2. **Growing hook complexity.** `peon.sh` is ~4,000 lines total, with a ~765-line embedded Python block handling 11 event types across 7 CESP categories, plus pack rotation (3 modes), path rules, trainer reminders, notification templates, tab colors, and multi-IDE adapter translation. When something breaks in this pipeline, the debug surface is `echo >> /tmp/debug.log`.

3. **Worktree proliferation.** Claude Code's `isolation: "worktree"` spawns parallel agents in separate worktrees. Each fires its own hooks against shared global state (`.state.json`). Users running sprint dispatchers with 5-20 concurrent agents have no way to correlate "which agent's hook fired, what it decided, and how long it took."

### Prior art in the ecosystem

- **Claude Code itself** has no hook logging — when a hook times out (killed at the configured timeout), the user sees a brief warning but no details about *why* it timed out.
- **Git hooks** have no built-in logging either; projects like `overcommit` and `husky` add their own.
- **Terraform**, **Ansible**, and other infrastructure tools use leveled logging (`TF_LOG=DEBUG`) with structured output, which has become the de facto pattern for configurable observability in CLI tools.
- **systemd journal** and **Windows Event Log** are too heavy for a hook that must complete in <8 seconds. File-based logging with rotation is the right weight class.

### Current diagnostic surfaces

| Surface | Platform | Scope | Notes |
|---------|----------|-------|-------|
| `# echo ... >> /tmp/peon-ping-debug.log` | Unix | Raw stdin dump | Commented out, requires editing source |
| `PEON_DEBUG=1` → `Write-Warning` | Windows | `win-play.ps1` audio only | Only covers MediaPlayer failures |
| `afplay.log` in test mode | macOS (tests) | Mock audio calls | Test infrastructure only |
| `.state.json` | All | State mutations | Readable but not timestamped, no event history |
| `peon status --verbose` | All | Current config/notification state | Point-in-time snapshot, not historical |

## User Segments

### Solo developer debugging a broken setup
- **Who**: Individual developer who installed peon-ping, it worked for a while, and now something stopped (sounds, notifications, or both). Possibly changed IDE, updated Claude Code, or switched to a worktree workflow.
- **Current pain**: No logs to check. Only recourse is to set `PEON_DEBUG=1` (Windows audio only), manually uncomment a debug line in `peon.sh`, or open a GitHub issue saying "it doesn't work."
- **Desired outcome**: Run `peon logs` or check a log file to see exactly what happened on the last N hook invocations — what event came in, what config was loaded, what pack/sound was selected, whether audio playback succeeded, and how long each phase took.
- **Priority**: Primary

### Sprint dispatcher operator (multi-agent)
- **Who**: Developer using gitban or similar orchestration to run 5-20 concurrent Claude Code agents, each in its own worktree, each firing peon-ping hooks. Needs to understand why some agents play sounds and others don't, or why hooks are timing out under load.
- **Current pain**: Hooks fire concurrently against shared state. No way to tell which agent's hook wrote what to `.state.json`, or which hooks raced and lost. State corruption is rare (atomic writes) but event *suppression* (debounce, agent detection, cooldowns) is common and invisible.
- **Desired outcome**: Logs that correlate by session ID and worktree path, showing per-invocation decisions ("suppressed: delegate mode," "debounced: stop within 5s," "skipped: session_start cooldown").
- **Priority**: Secondary

### Contributor or adapter author
- **Who**: Developer writing a new IDE adapter (e.g., `adapters/kiro.sh`) or contributing to the core Python block. Needs to verify their event translation produces the right CESP category and triggers the expected sound.
- **Current pain**: Must read the Python block and trace mentally, or add temporary `print()` statements and remember to remove them.
- **Desired outcome**: Set `debug: true` in config, trigger events, read structured log entries showing the full decision chain from raw event → CESP category → sound file.
- **Priority**: Tertiary

## Goals & Non-Goals

### Goals

- **G1**: A developer experiencing a peon-ping issue can diagnose the root cause from log output alone, without reading source code or opening a GitHub issue.
- **G2**: Logging is off by default and adds zero overhead to normal hook execution when disabled.
- **G3**: Logs are structured enough to filter by session, event type, or time range using standard CLI tools (`grep`, `Select-String`, `jq`).
- **G4**: Log files self-manage — users never need to manually clean up old logs.
- **G5**: Works correctly in worktrees, SSH sessions, devcontainers, and multi-agent dispatch without log corruption or cross-session pollution.
- **G6**: A single config key (`debug`) enables useful logging; power users can tune verbosity and retention.

### Non-Goals

- **Centralized log aggregation or dashboards** — peon-ping is a personal CLI tool, not a service. Logs are local files. If someone wants to ship them somewhere, they can use standard log forwarding tools.
- **Real-time log streaming / `peon logs --follow`** — nice to have but not necessary for the core debugging use case. Tail works.
- **Metrics, counters, or histograms** — this is observability for debugging, not monitoring. We don't need to know that "742 hooks fired today with a p95 latency of 340ms." We need to know why *this* hook didn't play a sound.
- **Modifying Claude Code's hook timeout behavior** — we can't change how Claude Code kills hooks. We can log what happened before the kill.
- **Structured logging format (JSON lines)** — tempting but overkill for a tool whose primary consumer is a human reading a file. Plain text with parseable structure (timestamp, level, session, message) is the right call. Users who need machine parsing can grep. The internal log-writing code should be a simple format-string-per-phase — no pluggable formatter abstraction needed unless JSON support is added later.
- **Per-adapter logging** — adapters are thin translators. Logging belongs in the core hook scripts where the decisions happen.

## User Experience

### Scenario 1: "My sounds stopped working"

A developer notices peon-ping hasn't played sounds in a while. They don't know when it broke.

```
$ peon debug on
peon-ping: debug logging enabled → ~/.openpeon/logs/

$ # ... use Claude Code normally, trigger a few events ...

$ peon logs
2026-03-25T14:22:01.003 [hook] event=Stop session=abc123 cwd=/home/user/myproject
2026-03-25T14:22:01.005 [config] loaded=/home/user/.openpeon/config.json volume=0.5 pack=glados
2026-03-25T14:22:01.008 [route] category=task.complete suppressed=false
2026-03-25T14:22:01.010 [sound] file=mission-complete.wav pack=glados
2026-03-25T14:22:01.012 [play] backend=afplay pid=48291 async=true
2026-03-25T14:22:01.013 [exit] duration_ms=10 exit=0

2026-03-25T14:22:33.401 [hook] event=Notification session=abc123 type=permission_prompt
2026-03-25T14:22:33.404 [config] loaded=/home/user/.openpeon/config.json volume=0.5 pack=glados
2026-03-25T14:22:33.407 [route] category=input.required suppressed=false
2026-03-25T14:22:33.408 [sound] file=attention.wav pack=glados
2026-03-25T14:22:33.410 [play] backend=afplay error="afplay: command not found"
2026-03-25T14:22:33.411 [exit] duration_ms=10 exit=0
```

The user immediately sees: `afplay: command not found` — they updated macOS and something changed in their PATH. Problem identified in 30 seconds instead of a GitHub issue thread.

```
$ peon debug off
peon-ping: debug logging disabled
```

### Scenario 2: Debugging a timeout in a worktree sprint

A dispatcher operator sees "hook error" warnings in their Claude Code sessions. Multiple agents are running in worktrees.

```
$ peon logs --last 10
2026-03-25T15:01:12.100 [hook] event=Stop session=agent-7 cwd=/tmp/worktrees/feature-auth
2026-03-25T15:01:12.103 [config] loaded=/home/user/.openpeon/config.json volume=0.3 pack=peasant
2026-03-25T15:01:12.200 [hook] event=Stop session=agent-12 cwd=/tmp/worktrees/feature-db
2026-03-25T15:01:12.203 [config] loaded=/home/user/.openpeon/config.json volume=0.3 pack=peasant
2026-03-25T15:01:12.801 [state] read=/home/user/.openpeon/.state.json retry=2 delay_ms=150 session=agent-7
2026-03-25T15:01:12.804 [route] category=task.complete suppressed=true reason="delegate mode" session=agent-7
2026-03-25T15:01:12.805 [exit] duration_ms=705 exit=0 session=agent-7
2026-03-25T15:01:19.500 [state] read=/home/user/.openpeon/.state.json error="locked" retries_exhausted=true session=agent-12
2026-03-25T15:01:19.501 [state] fallback=empty_defaults session=agent-12
2026-03-25T15:01:19.900 [play] backend=paplay pid=91202 async=true session=agent-12
--- hook killed by timeout (8s safety net) --- session=agent-12
```

The operator sees the interleaved timeline: agent-7 completed in 705ms (suppressed — delegate mode), while agent-12's state read took 7.3 seconds because the file was locked by concurrent writes. The 8-second safety timer killed agent-12's process. Root cause: too many agents writing state simultaneously. Fix: reduce agent concurrency or accept the graceful degradation. Filtering to one agent: `peon logs --last 5 --session agent-12`.

### Scenario 3: Contributor testing a new adapter

```
$ PEON_DEBUG=1 echo '{"hook_event_name":"Stop","session_id":"test"}' | bash peon.sh
# No env var needed if config has debug: true

$ peon logs --last 1
2026-03-25T16:00:01.000 [hook] event=Stop session=test cwd=/home/user/peon-ping
2026-03-25T16:00:01.003 [config] loaded=/home/user/peon-ping/.claude/hooks/peon-ping/config.json volume=0.5 pack=peon
2026-03-25T16:00:01.005 [route] raw_event=Stop notification_type=none → category=task.complete
2026-03-25T16:00:01.007 [sound] manifest=/home/user/.claude/hooks/peon-ping/packs/peon/openpeon.json
2026-03-25T16:00:01.008 [sound] category_key=task.complete candidates=4 selected=job-done.wav (no-repeat filtered=1)
2026-03-25T16:00:01.010 [play] backend=pw-play vol_scaled=0.5 pid=55012 async=true
2026-03-25T16:00:01.011 [notify] desktop=true template="✅ {project}: done" rendered="✅ peon-ping: done"
2026-03-25T16:00:01.012 [exit] duration_ms=12 exit=0
```

Full decision chain visible: event → category mapping → manifest lookup → candidate filtering → sound selection → playback backend → notification rendering.

### Scenario 4: Windows user with no sounds

```
PS> peon debug on
peon-ping: debug logging enabled → C:\Users\user\.openpeon\logs\

PS> # trigger some events...

PS> peon logs
2026-03-25T14:30:01.200 [hook] event=Stop session=xyz cwd=C:\Users\user\project
2026-03-25T14:30:01.350 [config] loaded=C:\Users\user\.openpeon\config.json volume=0.5 pack=glados
2026-03-25T14:30:01.380 [route] category=task.complete suppressed=false
2026-03-25T14:30:01.400 [sound] file=C:\Users\user\.claude\hooks\peon-ping\packs\glados\task-complete.wav
2026-03-25T14:30:01.420 [play] backend=win-play.ps1 async=Start-Process detached=true
2026-03-25T14:30:01.430 [exit] duration_ms=230 exit=0
```

The hook itself completed fine (230ms). The problem is downstream in `win-play.ps1`. User can then:
```
PS> $env:PEON_DEBUG="1"
# trigger event again
# now win-play.ps1 also logs to stderr
```

### Error & Edge Cases

**Log directory doesn't exist**: Created automatically on first write. If creation fails (permissions), log a warning to stderr and continue without logging — logging must never break the hook.

**Disk full**: Log write fails silently. The hook continues. Next invocation's rotation may free space by deleting old logs.

**Concurrent writes from multiple hooks**: Each hook invocation appends to the log file. On Unix, short `write()` calls to a file opened with `O_APPEND` are atomic per POSIX. On Windows, `Add-Content` with `-Encoding UTF8` is safe for line-sized writes. No file locking needed for append-only logging.

**Worktree isolation**: Logs go to the *global* log directory (`$PEON_DIR/logs/`), not per-worktree. Each log line includes the `cwd` and `session` fields, so filtering by worktree path is trivial: `grep "/tmp/worktrees/feature-auth" peon-ping.log`.

**Hook killed mid-write**: The log line was either fully written (atomic append) or not written at all. No corruption risk. The last line in the log might show the hook started but not the exit — which is itself diagnostic ("this hook was killed before completing").

## Success Criteria

| Criterion | Measurement | Target |
|-----------|-------------|--------|
| Zero-overhead when disabled | Time `peon.sh` with `debug: false` vs. no logging code at all | <1ms difference |
| Actionable diagnosis | Given 5 common failure modes (missing audio backend, bad config, pack not installed, timeout, state locked), a user can identify the root cause from logs alone | 5/5 identifiable |
| Log rotation works | After 7 days of continuous use with `debug: true`, total log size stays bounded | <10 MB retained |
| Cross-platform parity | Same log format, same config keys, same CLI commands on macOS, Linux, WSL2, and native Windows | Feature parity on all 4 platforms |
| Worktree-safe | 10 concurrent hook invocations writing to the same log file produce 10 non-interleaved, complete log entries | Zero corruption in 100 trials |
| Config-driven | `peon debug on` enables logging; `peon debug off` disables it; no source editing, no env vars required | Works as described |

## Scope & Boundaries

### In Scope

- **`debug` config key** — boolean, enables/disables all logging. Off by default.
- **`debug_retention_days` config key** — integer, how long to keep log files. Default 7.
- **Log output in both `peon.sh` (Python block) and the Windows hook script** (embedded in `install.ps1`, deployed as `peon.ps1`) — same format, same phases logged.
- **`peon debug on|off` CLI command** — toggles `debug` in config.json.
- **`peon logs` CLI command** — displays recent log entries with optional `--last N` and `--session <id>` filters.
- **Log rotation** — daily log files (`peon-ping-YYYY-MM-DD.log`), old files pruned on each invocation based on `debug_retention_days`.
- **Phase timing** — each log entry includes millisecond timestamps; the `[exit]` line includes total `duration_ms`.
- **Decision logging** — every suppression, debounce, fallback, and error path logs *why* it happened.

### Out of Scope

- **Log shipping / aggregation** — users can `tail -f` or pipe to whatever they want. Not our problem.
- **`peon logs --follow`** — would require a watcher process. Users can use `tail -f` directly.
- **JSON log format** — human-readable lines are the right default. If demand emerges, a `debug_format: json` key could be added later without breaking anything.
- **Performance profiling** — we log phase timestamps, not flame graphs. If someone needs to profile the Python block, they can use `cProfile`.
- **Adapter-level logging** — adapters are thin stdin/stdout translators. If an adapter is broken, the log will show "no event received" or "unrecognized event" at the core level, which is sufficient.
- **GUI log viewer** — this is a CLI tool. Logs are text files.

### Future Considerations

- **`debug_level` config key** (e.g., `info` vs `debug` vs `trace`) — could be added later if `debug: true` produces too much output. Start with a single level that's useful for all three user segments.
- **Structured JSON output mode** — if CI/automation users need machine-parseable logs, add `debug_format: "jsonl"` config key. The Phase 1 code uses simple format strings — adding a JSON formatter later would require refactoring the log calls to pass structured data, but the surface area is small (~10 call sites per platform).
- **`peon doctor` command** — a diagnostic command that checks config validity, pack integrity, audio backend availability, and state file health. Logging data could feed this, but `peon doctor` is a separate feature.

## Delivery Phases

### Phase 1: Core logging in hook scripts — "Users can see what happened"

**What ships:**
- `debug` and `debug_retention_days` config keys with defaults (`false`, `7`)
- Logging infrastructure in the `peon.sh` Python block: log open, phase logging (hook, config, route, sound, play, notify, exit), log close
- Logging infrastructure in the Windows hook script (the `$hookScript` here-string in `install.ps1`, deployed as `peon.ps1`): same phases, same format. Users must re-run `install.ps1` to pick up logging changes.
- Daily log rotation with retention pruning (on each invocation, delete files older than `debug_retention_days`)
- Log directory: `$PEON_DIR/logs/` (typically `~/.openpeon/logs/` or `~/.claude/hooks/peon-ping/logs/` depending on install — follows the same directory resolution as config and state files). Created on first write.
- Log format: `YYYY-MM-DDTHH:MM:SS.mmm [phase] key=value key=value ...`
- `PEON_DEBUG=1` env var override (enables logging regardless of config, for one-off debugging without changing config)

**Launch criteria:**
- All 5 failure scenarios from Success Criteria are diagnosable from log output
- Zero measurable overhead when `debug: false` (early return before any log I/O)
- Existing BATS and Pester test suites pass unchanged
- New tests: logging enabled produces expected log entries; logging disabled produces no log files; rotation prunes correctly

**Decisions needed:**
- Whether logging functions are inlined in the Python block or extracted into a helper (the Python block is embedded in a bash here-doc, so extraction means either a separate `.py` file or functions defined at the top of the block)
- On Windows, the hook script is embedded in `install.ps1` — changes require users to re-run the installer. Consider whether `peon update` should regenerate `peon.ps1` automatically.

**Dependencies:**
- None — no external changes required

### Phase 2: CLI commands — "Users can toggle and read logs without editing files"

**What ships:**
- `peon debug on` / `peon debug off` — toggles `debug` key in config.json
- `peon debug status` — shows whether logging is enabled and the log directory path
- `peon logs` — shows the most recent log file content (last 50 lines by default)
- `peon logs --last N` — show last N log entries
- `peon logs --session <id>` — filter by session ID
- `peon logs --clear` — delete all log files
- Windows parity in the Windows hook script CLI for all above commands
- Shell completions updated (`completions.bash`, `completions.fish`)

**Launch criteria:**
- CLI commands work identically on macOS, Linux, WSL2, and native Windows
- BATS tests for `peon debug on/off/status` and `peon logs` variations
- Pester tests for Windows CLI parity
- `peon help` updated with debug/logs commands

**Decisions needed:**
- None

**Dependencies:**
- Phase 1 (log files must exist before CLI can read them)

### Phase 3: Documentation and discoverability — "Users know logging exists"

**What ships:**
- README.md: new "Debugging" section with examples
- README_zh.md: translated equivalent
- `peon help` output updated with debug/logs commands
- `docs/public/llms.txt` updated
- Troubleshooting guide: common failure modes and what to look for in logs
- `peon status --verbose` updated to show debug logging state

**Launch criteria:**
- A new user encountering their first issue can find the debug instructions within 2 clicks from README
- All language variants updated

**Decisions needed:**
- None

**Dependencies:**
- Phase 2 (CLI commands must be finalized before documenting them)

## Technical Considerations

### Performance budget

The hook has an 8-second safety timeout (self-imposed) and a 10-second Claude Code timeout (user-configured in `settings.json`). The Python block typically runs in 120-200ms. Logging must add <5ms when enabled and <1ms when disabled.

**When disabled**: The Python block checks `cfg.get('debug', False)` once. If false, the log function is a no-op lambda. Zero I/O, zero string formatting.

**When enabled**: File open (once per invocation), 6-10 formatted writes (~100-200 bytes each), file close. Append mode, no fsync. Daily rotation check adds one `os.listdir()` call.

### Log file design

- **Path**: `$PEON_DIR/logs/peon-ping-YYYY-MM-DD.log` (resolves to `~/.openpeon/logs/` or `~/.claude/hooks/peon-ping/logs/` depending on install)
- **One file per day**: Keeps individual files small, makes rotation trivial (delete files by date), and avoids the need for log size limits.
- **Append-only**: Multiple concurrent hooks append to the same file. POSIX guarantees atomicity for `write()` calls under `PIPE_BUF` (4096 bytes). Each log entry is a single line well under this limit.
- **No buffering**: Each line is flushed immediately. If the hook is killed, all previously written lines are preserved.

### Dual-implementation reality

Logging must be implemented independently in two different languages against two different runtimes:

| | Unix (macOS / Linux / WSL2) | Native Windows |
|---|---|---|
| **Hook script** | `peon.sh` — bash shell + embedded Python block | `$hookScript` here-string in `install.ps1`, deployed as `peon.ps1` — pure PowerShell |
| **Log writing** | Python `open(path, 'a')` with `O_APPEND` | PowerShell `Add-Content -Encoding UTF8` |
| **Atomic append guarantee** | POSIX `write()` under `PIPE_BUF` (4096 bytes) | .NET `StreamWriter` holds lock for write duration |
| **Timestamp** | `datetime.now().isoformat(timespec='milliseconds')` | `[datetime]::Now.ToString('yyyy-MM-ddTHH:mm:ss.fff')` |
| **Rotation** | `os.listdir()` + `os.remove()` on each invocation | `Get-ChildItem` + `Remove-Item` |
| **CLI (`peon debug`, `peon logs`)** | bash `case` block in `peon.sh` | PowerShell `switch` block in embedded `$hookScript` |
| **Env var override** | `PEON_DEBUG=1` reaches Python block naturally | `$env:PEON_DEBUG` reaches `peon.ps1` but does **not** propagate to detached `win-play.ps1` (spawned via `Start-Process`) |
| **Deployment** | File edited in-place — changes take effect immediately | Embedded in `install.ps1` — users must re-run installer (or `peon update`) to pick up changes |

This dual-implementation is the primary source of **format drift risk**. The two codebases must produce byte-identical log lines for the same event, but there's no shared code between them. The design phase should consider:

- A shared test fixture (known JSON input → expected log output) that both BATS and Pester validate against, to catch drift
- Whether `PEON_DEBUG=1` should propagate to `win-play.ps1` child processes (currently it doesn't — the detached `Start-Process` starts a fresh environment). If not, the Windows `[play]` phase log entry can only capture "launched win-play.ps1" but not downstream audio failures, which is an asymmetry with Unix where the audio backend is invoked directly.

### Windows-specific considerations

- PowerShell startup overhead (~200-400ms) is already the dominant cost on Windows. Logging adds negligible time on top.
- Log path uses forward slashes internally, resolved via `Join-Path` for Windows compatibility.

### Worktree correctness

Logs are global (not per-worktree) because:
1. The user wants to see *all* hook activity in one place, especially during multi-agent dispatch
2. Per-worktree logs would scatter across temporary directories that are cleaned up when the worktree is removed
3. The `cwd` and `session` fields in each log line provide worktree identification without separate files

### Backward compatibility

- `debug: false` is the default — existing users see no change
- No config migration needed — missing keys use defaults
- `PEON_DEBUG=1` env var (already exists in `win-play.ps1` for stderr audio warnings) is extended to *also* enable core hook file logging, in addition to the existing stderr behavior. Both outputs are additive — enabling `PEON_DEBUG=1` gets you the existing `Write-Warning` stderr diagnostics from `win-play.ps1` *plus* the new structured log file entries from the hook script
- No changes to hook stdin/stdout contract — logging is purely a side effect

### What gets logged at each phase

| Phase | Key fields | Example |
|-------|-----------|---------|
| `[hook]` | event, session, cwd | `event=Stop session=abc123 cwd=/home/user/proj` |
| `[config]` | loaded (path), volume, pack, rotation_mode | `loaded=~/.openpeon/config.json volume=0.5 pack=glados` |
| `[state]` | read (path), retry count, errors | `read=~/.openpeon/.state.json retry=0` |
| `[route]` | raw_event, notification_type, category, suppressed, reason | `category=task.complete suppressed=false` |
| `[sound]` | manifest, category_key, candidates, selected, no-repeat info | `selected=job-done.wav candidates=4` |
| `[play]` | backend, volume_scaled, pid, async, error | `backend=afplay pid=48291 async=true` |
| `[notify]` | desktop, mobile, template, rendered message | `desktop=true template="✅ {project}: done"` |
| `[trainer]` | reminder, reps, goal, pace | `reminder=true reps=50/300 pace=behind` |
| `[exit]` | duration_ms, exit code | `duration_ms=12 exit=0` |

## Risks & Open Questions

### Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Users enable debug and forget, logs accumulate | Low — 7-day rotation caps at ~10MB | Medium | Default retention of 7 days; `peon status --verbose` shows debug state as a reminder |
| Logging I/O causes hook timeout under disk pressure | High — hook killed, no sound | Low | Logging wraps in try/catch; any I/O failure disables logging for the rest of the invocation |
| Log format changes break user scripts that parse logs | Low — logs are for humans | Low | Document that log format is not a stable API; if JSON format is added later, it will be a separate config |
| Concurrent appends on Windows produce interleaved lines | Medium — confusing logs | Low | Each log entry is a single `Add-Content` call; PowerShell's underlying .NET `StreamWriter` holds a lock for the write duration |

### Open Questions

- **Should `peon doctor` be part of this PRD or a separate one?** A diagnostic command that actively *checks* config, packs, audio backends, and state health is complementary to logging but has its own scope and user stories. Recommendation: separate PRD, but ensure the log infrastructure makes `peon doctor` easier to build later.
- **Should there be a `debug_level` from the start (info/debug/trace)?** Starting with a single boolean is simpler and covers all three user segments. If the single level proves too noisy for casual users or too quiet for contributors, levels can be added later without breaking config. Recommendation: start with boolean, add levels only if needed.

## Related Documents

- [ADR-001: Async Audio and Safe State on Windows](docs/adr/proposals/ADR-001-async-audio-and-safe-state-on-windows.md) — M0 reliability work that established the 8-second safety timeout, atomic state writes, and `PEON_DEBUG` env var in `win-play.ps1`
- [M2 notification templates design](docs/plans/2026-02-24-notification-templates-design.md) — the notification template system adds another decision point that logging must cover
- [GitHub #402: Windows hook error after switching pack](https://github.com/PeonPing/peon-ping/issues/402) — open bug that would be trivially diagnosable with hook logging
- [GitHub #397: MSYS2 python3 argument too long](https://github.com/PeonPing/peon-ping/issues/397) — open bug where logging would capture the exact error before the process dies
- [Claude Code hooks documentation](https://code.claude.com/docs/en/hooks) — hook timeout behavior, JSON payload schema, exit code semantics

---

## Revision History

| Date | Author | Notes |
|------|--------|-------|
| 2026-03-25 | cameron | Initial draft |
| 2026-03-25 | cameron | Post-review revisions: corrected Python block size (765 lines, not ~4,000), event count (11 types / 7 categories, not 24), documented peon.ps1 embedded-in-install.ps1 architecture, resolved JSON format contradiction between non-goals and future considerations, fixed Scenario 2 session filter inconsistency, clarified PEON_DEBUG=1 additive semantics, added Phase 1 decisions, normalized log directory to $PEON_DIR/logs/ |
