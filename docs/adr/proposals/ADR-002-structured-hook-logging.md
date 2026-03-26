# ADR-002: Structured Hook Logging via Inline Phase Emitters

> **Status**: Accepted | **Date**: 2026-03-25 | **Accepted**: 2026-03-25 | **Deciders**: cameron

## Context

peon-ping's hook scripts (`peon.sh` and `peon.ps1`) are silent-failure-by-design: every `try/except` falls back to defaults, every missing config key gets a safe value. This means the system keeps running even when it's broken — but gives users zero visibility into why sounds stopped, notifications vanished, or hooks started timing out.

The current diagnostic surface is:

- **Unix**: A commented-out `echo` line in `peon.sh` that dumps raw stdin to `/tmp/peon-ping-debug.log`. Requires editing source. Additionally, the Python block's stderr is redirected to `/dev/null` (`2>/dev/null` on the `python3 -c` invocation), meaning any diagnostic output from the decision pipeline is silently swallowed.
- **Windows**: `PEON_DEBUG=1` env var in `win-play.ps1` that emits `Write-Warning` for audio failures only — covers none of config loading, event routing, pack selection, or state management.
- **All platforms**: `.state.json` is readable but has no timestamps and no event history.

Three pressures make this urgent now:

1. **Dual-codebase parity.** The Windows hook script (`peon.ps1`, deployed from `install.ps1`) is a separate ~1,650-line implementation with its own failure modes and essentially no diagnostics.
2. **Pipeline complexity.** The Unix Python block is ~765 lines handling 11 event types across 7 CESP categories, with pack rotation (3 modes), path rules, trainer reminders, notification templates, and multi-IDE adapter translation. When something breaks mid-pipeline, the only signal is absence of sound.
3. **Worktree concurrency.** Sprint dispatchers running 5-20 parallel agents in worktrees fire hooks concurrently against shared global state. Suppression decisions (delegate mode, debounce, cooldowns) are invisible — there's no way to tell which agent's hook fired, what it decided, or whether it was killed by timeout.

The fundamental tension is: **observability vs. performance and simplicity.** The hook runs in a constrained environment (8-second self-imposed timeout, 10-second Claude Code timeout, ~120-200ms typical execution) and must never break audio playback. Any logging architecture must have zero cost when disabled and negligible cost when enabled.

## Decision

We will add inline phase-emitting log calls at each decision point in both `peon.sh` (Python block) and `peon.ps1` (PowerShell), writing append-only log lines to daily-rotated files under `$PEON_DIR/logs/`. Logging is gated on a `debug` boolean in `config.json` (default `false`) with a `PEON_DEBUG=1` env var override. A `peon debug on|off` CLI command toggles the config key. A `peon logs` CLI command reads log files with basic filtering.

Log format is human-readable key=value lines, one per phase. Every line carries a short invocation ID (`inv=`) so concurrent hook executions can be correlated even when interleaved:

```
2026-03-25T14:22:01.003 [hook] inv=7a3f event=Stop session=abc123 cwd=/home/user/proj
2026-03-25T14:22:01.005 [config] inv=7a3f loaded=/home/user/.openpeon/config.json volume=0.5 pack=glados
2026-03-25T14:22:01.008 [route] inv=7a3f category=task.complete suppressed=false
2026-03-25T14:22:01.010 [sound] inv=7a3f file=mission-complete.wav pack=glados candidates=4
2026-03-25T14:22:01.012 [play] inv=7a3f backend=afplay pid=48291 async=true
2026-03-25T14:22:01.013 [exit] inv=7a3f duration_ms=10 exit=0
```

Values containing spaces or special characters are double-quoted. Values without spaces are unquoted. This keeps simple cases scannable while remaining unambiguous:

```
2026-03-25T14:22:01.003 [hook] inv=7a3f event=Stop session=abc123 cwd="/home/user/my project"
2026-03-25T14:22:01.010 [notify] inv=7a3f desktop=true template="✅ {project}: done" rendered="✅ my project: done"
```

Each invocation logs 6-10 lines covering phases: `[hook]`, `[config]`, `[state]`, `[route]`, `[sound]`, `[play]`, `[notify]`, `[trainer]`, `[exit]`. Every suppression, debounce, fallback, and error path logs *why* it happened. If a hook is killed by timeout before emitting `[exit]`, the incomplete invocation is identifiable by its `inv=` prefix — all preceding lines for that invocation are present and the absence of `[exit]` is itself diagnostic.

Log files are daily (`peon-ping-YYYY-MM-DD.log`), pruned on each invocation based on `debug_retention_days` (default 7). Files live in `$PEON_DIR/logs/`, created on first write.

## Rationale

### Key Factors

1. **Inline emitters over a logging framework.** The Python block runs inside a bash here-doc and the PowerShell script is embedded in `install.ps1`. Neither environment supports importing external logging libraries cleanly. Inline `log("phase", "key=val ...")` calls — where `log` is a no-op lambda when disabled — match the existing code structure and keep the dependency footprint at zero.

2. **Daily file rotation over size-based rotation.** Size-based rotation requires tracking file size on every write and handling rollover atomically during concurrent appends. Date-based rotation is trivially correct: each invocation opens today's file and deletes files whose datestamp is older than the retention window. Solo developers generate 10-50 invocations/day; sprint dispatch operators running 20 concurrent agents may hit 200-500. At ~100 bytes per log line and 8 lines per invocation, even the sprint case produces ~400 KB/day — well under 1 MB per daily file.

3. **Key=value format over JSON lines.** The PRD explicitly identifies the primary consumer as a human reading a file. Key=value lines are immediately scannable, `grep`-able, and don't require `jq` to read. Values containing spaces or special characters are double-quoted; values without spaces are unquoted. Both implementations must follow this convention — the shared test fixture includes edge-case inputs (paths with spaces, notification templates with braces and emoji) to enforce it. If machine-parseable output becomes necessary later, a `debug_format: "jsonl"` config key can be added — the call sites pass structured data already, so adding a JSON formatter is a small refactor (~10 sites per platform).

4. **Single boolean over leveled logging.** Adding `info`/`debug`/`trace` levels introduces a decision at every call site ("is this info or debug?") and a usability question for users ("which level do I need?"). The PRD's three user segments (solo debugger, sprint operator, contributor) all need the same information: the full decision chain. Starting with a single boolean that emits everything keeps the implementation simple. Levels can be added later if the single level proves too noisy, with the no-op-when-disabled pattern unchanged.

5. **Global log directory over per-worktree logs.** Worktrees are temporary directories cleaned up when the agent finishes. Per-worktree logs would be lost. Global logs with `cwd` and `session` fields per line let users filter by worktree path (`grep "/tmp/worktrees/feature-auth"`) while keeping all activity visible in one place for sprint operators.

## Consequences

### Positive

- Users can diagnose the five most common failure modes (missing audio backend, bad config, pack not installed, timeout, state lock contention) from log output alone, without reading source or filing a GitHub issue.
- Sprint operators can correlate concurrent hook invocations by session ID and worktree path, making delegate-mode suppression, debounce decisions, and timeout kills visible.
- Contributors testing new adapters or modifying the Python block can see the full event-to-sound decision chain without adding temporary print statements.

### Negative

- Every code change to the decision pipeline requires adding or updating log calls in *two* independent implementations (Python and PowerShell). There is no shared code — format drift between platforms is a real risk. Mitigated by shared test fixtures: known JSON input producing expected log output, validated by both BATS and Pester.
- The `debug` config key and `peon debug`/`peon logs` CLI commands add surface area to the CLI and config schema. These are permanent additions that must be maintained across both platforms.
- On Windows, `Add-Content` uses a lock-open-seek-write-close cycle rather than POSIX `O_APPEND` atomic semantics. Under heavy concurrent load (20+ agents in sprint dispatch), lock contention may cause an `IOException`, which the try/catch guard handles by disabling logging for the remainder of that invocation. This means some Windows log entries may be dropped under extreme concurrency — an acceptable tradeoff given the "logging must never break the hook" principle, but an asymmetry with Unix where `O_APPEND` writes under `PIPE_BUF` are guaranteed atomic.

### Neutral

- The `PEON_DEBUG=1` env var in `win-play.ps1` continues to work as before (stderr `Write-Warning` for audio failures). When the new logging is also active, both outputs fire — they are additive, not conflicting.
- Log files are not a stable API. Users who build tooling on top of the log format do so at their own risk. This is documented explicitly.

## Alternatives Considered

### Alternative 1: External Logging Library (Python `logging` / PowerShell `Start-Transcript`)

**Description**: Use Python's built-in `logging` module in `peon.sh`'s Python block and PowerShell's `Start-Transcript` or a third-party module in `peon.ps1`. Configure handlers for file output with rotation.

**Pros**:
- Python `logging` provides leveled output, configurable formatters, and `RotatingFileHandler` out of the box.
- `Start-Transcript` captures all PowerShell output automatically — zero manual instrumentation.

**Cons**:
- The Python block runs inside a bash here-doc (`python3 -c "..."`). Importing `logging` and configuring handlers adds ~10 lines of boilerplate and a measurable startup cost (~15-30ms for module import + handler setup) on every invocation, even when logging is disabled, unless the import itself is gated behind the debug check — which negates the benefit of using the module.
- `Start-Transcript` captures *everything* (verbose/debug streams, command output, errors) with no phase structure. The output is a wall of text, not parseable log entries. It also writes to a separate file per session, not a shared daily log — breaking the "one log directory, filter by session" model.
- Neither approach produces cross-platform-identical output. Format drift risk remains, just hidden behind framework differences.

**Why not chosen**: The overhead of importing `logging` on every invocation (even when disabled) violates the zero-cost-when-disabled requirement. `Start-Transcript` produces unstructured output that doesn't serve the debugging use cases. Inline emitters are lighter, more predictable, and produce identical format on both platforms by construction.

### Alternative 2: Structured JSON Log Lines (JSONL)

**Description**: Each log entry is a JSON object on one line. Tools like `jq` can filter and transform. Format: `{"ts":"2026-03-25T14:22:01.003","phase":"hook","event":"Stop","session":"abc123","cwd":"/home/user/proj"}`.

**Pros**:
- Machine-parseable out of the box. Enables future tooling (log viewers, CI analysis, `peon logs --json`).
- No ambiguity in parsing — keys and values are always properly quoted and escaped.
- Could support a `peon logs --filter 'phase=route AND suppressed=true'` command trivially.

**Cons**:
- Less scannable for humans. Reading raw JSONL requires mental parsing or `jq` for any non-trivial query. The primary user segment (solo developer reading a log file to find why sounds stopped) would have a worse experience.
- JSON serialization on every log call adds overhead: `json.dumps()` in Python, `ConvertTo-Json` in PowerShell. Small per-call, but 6-10 calls per invocation adds up vs. simple string formatting.
- Requires escaping values that contain special characters (file paths with spaces, notification template strings with quotes). Key=value format handles this with simpler conventions.

**Why not chosen**: The primary consumer is a human reading a file. Key=value lines serve that use case better. If machine-parseable output becomes necessary, adding `debug_format: "jsonl"` as a config option later is straightforward — the inline emitters already pass structured data, so adding a JSON code path is a small refactor, not a rewrite.

### Alternative 3: Stderr-Based Logging — Remove `2>/dev/null` and Print Diagnostics to Stderr

**Description**: Instead of building file-based logging infrastructure, remove the `2>/dev/null` redirect on the Python block invocation (`peon.sh:3780`), gate `print(..., file=sys.stderr)` calls behind the debug flag, and let users capture diagnostics via shell redirection (`peon.sh 2>>debug.log`). On Windows, use `Write-Warning` (which already writes to the warning stream) for diagnostic output beyond the existing audio-only scope.

**Pros**:
- Dramatically simpler implementation. No log directory management, no daily rotation, no `peon logs` CLI command, no file I/O in the hot path. The only code change is adding `print()` calls to stderr behind a boolean check.
- Zero new infrastructure — uses the OS-provided diagnostic channel that already exists.
- Users who want persistent logs can redirect stderr themselves. Users who want one-off debugging see output immediately in the terminal.

**Cons**:
- Claude Code captures hook stdout but does **not** surface hook stderr to the user — stderr from hooks is discarded by the host process. Removing `2>/dev/null` in `peon.sh` would let stderr flow to Claude Code's process, but the user would never see it. This is the fundamental reason stderr-based logging doesn't work for the primary use case: a user who runs `peon debug on` and then uses Claude Code normally needs diagnostics to land in a file they can read later, not in a stream that Claude Code silently discards.
- On Windows, `peon.ps1` is invoked by Claude Code as a hook subprocess. PowerShell's warning stream (`Write-Warning`) is similarly not surfaced to the user — it would only be visible if the user ran `peon.ps1` manually from a terminal, which is not the normal execution path.
- No historical log — stderr is ephemeral. Sprint operators debugging an issue that happened 10 minutes ago in one of 20 concurrent agents have nothing to look at. The "what just happened" use case requires persistent storage.
- No worktree correlation — stderr output from concurrent hooks interleaves with no session or invocation identifier unless the user manually sets up per-agent redirection, which is impractical in automated dispatch.

**Why not chosen**: The hook's execution context makes stderr non-viable as the primary diagnostic channel. Claude Code discards hook stderr, so the user never sees it. The `2>/dev/null` on `peon.sh`'s Python block exists because stderr output was never useful in hook context — removing it wouldn't change that, because the output would flow to Claude Code's process and be discarded there instead. File-based logging is more infrastructure, but it's the only approach that produces output the user can actually read after the fact.

### Alternative 4: Do Nothing — Improve Ad-Hoc Debugging Guides

**Description**: Instead of building logging infrastructure, document the existing debugging approaches better: how to uncomment the debug line in `peon.sh`, how to use `PEON_DEBUG=1` on Windows, how to read `.state.json`, and common failure patterns.

**Pros**:
- Zero code changes. No new config keys, no new CLI commands, no dual-implementation maintenance burden.
- No risk of logging I/O causing timeout issues.
- Unblocks no-one but also breaks nothing.

**Cons**:
- Does not actually solve the problem. Users still can't diagnose issues without editing source code (Unix) or getting only audio-layer diagnostics (Windows). The five most common failure modes (missing backend, bad config, missing pack, timeout, state lock) remain invisible.
- Worktree concurrency debugging remains impossible — `.state.json` has no per-invocation history.
- Every GitHub issue about "peon-ping doesn't work" will still require a back-and-forth to establish basic facts about the execution environment, because there's no log to attach.
- Contributors and adapter authors still resort to temporary print statements.

**Why not chosen**: The problem is real and recurring (GitHub #402, #397). Documentation can help users who already know what to look for, but it cannot surface information that the system doesn't record. The maintenance cost of inline log calls is modest compared to the ongoing support cost of debugging blind.

## Implementation Notes

### Phase 1: Core Logging in Hook Scripts

- Add `debug` (boolean, default `false`) and `debug_retention_days` (integer, default `7`) to `config.json`.
- In the Python block (`peon.sh:~3016`): define a `log()` function gated on `cfg.get('debug', False) or os.environ.get('PEON_DEBUG') == '1'`. When disabled, `log` is a no-op lambda assigned before any I/O. When enabled, it opens `$PEON_DIR/logs/peon-ping-YYYY-MM-DD.log` in append mode and writes formatted lines.
- In `peon.ps1`: equivalent `$peonLog` function using `Add-Content`. Same gating logic.
- Add log calls at each phase: `[hook]`, `[config]`, `[state]`, `[route]`, `[sound]`, `[play]`, `[notify]`, `[trainer]`, `[exit]`.
- Rotation: when logging is enabled and the invocation opens a *new* daily log file (today's file didn't exist yet), prune files older than `debug_retention_days` via `os.listdir()` / `Get-ChildItem`. This avoids redundant directory scans on every invocation — pruning only runs once per day, on the first hook invocation that creates the new file.
- All logging wraps in try/catch — any I/O failure disables logging for the rest of the invocation. Logging must never break the hook.

### Phase 2: CLI Commands

- `peon debug on|off|status` — modifies `debug` in config.json.
- `peon logs [--last N] [--session ID] [--clear]` — reads/filters/manages log files.
- Update `completions.bash` and `completions.fish`.

### Phase 3: Documentation

- README.md "Debugging" section, README_zh.md translated equivalent, `docs/public/llms.txt`.

### Cross-Platform Test Fixture

To prevent format drift between the Python and PowerShell implementations, create a shared test fixture: a set of known JSON hook inputs with expected log output. Both BATS tests (validating `peon.sh` output) and Pester tests (validating `peon.ps1` output) assert against the same expected output. Any format divergence fails CI on both platforms.

## Validation

- **Zero-overhead when disabled**: Benchmark `peon.sh` with `debug: false` vs. a version with no logging code at all. Target: <1ms difference (measured as the delta in `$_PEON_PYOUT` generation time).
- **Actionable diagnosis**: Given the 5 common failure modes (missing audio backend, bad config, pack not installed, hook timeout, state lock contention), a tester enables debug logging, triggers the failure, and identifies the root cause from log output alone — all 5 must be diagnosable without reading source.
- **Log rotation**: After 7 simulated days of logging (create 10 dated log files), rotation prunes files older than `debug_retention_days`. Verified in both BATS and Pester.
- **Worktree safety**: 10 concurrent hook invocations appending to the same log file produce 10 complete, non-interleaved log entries. Verified via a BATS test that runs hooks in parallel and asserts line integrity.
- **Cross-platform parity**: The shared test fixture (same JSON input, same expected log output) passes on both macOS (BATS) and Windows (Pester) in CI.
- **Revisit trigger**: If typical invocation time with logging enabled exceeds 250ms (current baseline ~120-200ms + 5ms logging budget), investigate whether log I/O is the cause and consider buffering writes to a single flush.

## Related Decisions

- [ADR-001: Async Audio and Safe State on Windows](docs/adr/proposals/ADR-001-async-audio-and-safe-state-on-windows.md) — M0 reliability work that established the 8-second safety timeout, atomic state writes, and `PEON_DEBUG` env var in `win-play.ps1`. ADR-001 was never formally written; its `docs_ref` in the roadmap is aspirational. The decisions it covers (detached audio, atomic state I/O) are prerequisites for this ADR's logging design.

## References

- [PRD-002: Hook Observability](docs/prds/PRD-002-hook-observability.md) — product requirements driving this decision
- [CESP v1.0 Specification](https://github.com/PeonPing/openpeon) — the event category schema that logging must cover
- [Claude Code hooks documentation](https://code.claude.com/docs/en/hooks) — hook timeout behavior, JSON payload schema
- [POSIX write(2) atomicity](https://pubs.opengroup.org/onlinepubs/9699919799/functions/write.html) — guarantees for concurrent `O_APPEND` writes under `PIPE_BUF`
- [GitHub #402](https://github.com/PeonPing/peon-ping/issues/402), [#397](https://github.com/PeonPing/peon-ping/issues/397) — open bugs that motivated this work

---

## Revision History

| Date | Status | Notes |
|------|--------|-------|
| 2026-03-25 | Proposed | Initial proposal |
| 2026-03-25 | Proposed | Post-review revisions: added stderr alternative (B2), defined key=value escaping convention (B1), added per-line invocation ID for concurrent correlation (S4), corrected hook frequency estimates for sprint dispatch (S1), optimized rotation to once-per-day (S2), documented Windows `Add-Content` atomicity asymmetry (S3), renumbered to ADR-002 to avoid collision with M0's reserved ADR-001 (M3), restored roadmap `docs_ref` to PRD (M2) |
| 2026-03-25 | Accepted | Accepted as part of HOOKLOG sprint — gates implementation of v2/m4 structured hook logging |
