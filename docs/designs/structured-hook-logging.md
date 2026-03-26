# Design Doc: Structured Hook Logging via Inline Phase Emitters

> **ADR**: [ADR-002](../adr/proposals/ADR-002-structured-hook-logging.md) | **Date**: 2026-03-25 | **Author**: cameron

## Overview

peon-ping's hook scripts (`peon.sh` and `peon.ps1`) are silent-failure-by-design — every error path
falls back to defaults, giving users zero visibility into why sounds stopped, notifications vanished,
or hooks timed out. ADR-002 decided to add inline phase-emitting log calls at each decision point in
both codepaths, writing append-only key=value lines to daily-rotated files under `$PEON_DIR/logs/`.

This design doc specifies how to implement that decision: where the `log()` function lives in each
codebase, what each phase emitter captures, how daily rotation and pruning work, the CLI commands
(`peon debug`, `peon logs`), and the cross-platform test fixture that prevents format drift between
the Python and PowerShell implementations.

## Requirements

The implementation is complete when:

1. **Zero overhead when disabled**: Hook execution with `debug: false` adds <1ms compared to a
   version with no logging code at all. The `log` function is a no-op lambda/scriptblock assigned
   before any I/O when disabled.
2. **Full decision chain visibility**: All 8 pipeline phases (`[hook]`, `[config]`, `[state]`,
   `[route]`, `[sound]`, `[play]`, `[notify]`, `[trainer]`) emit log lines that trace why a
   given invocation produced (or suppressed) a specific sound/notification.
3. **Five failure modes diagnosable**: Missing audio backend, bad config, pack not installed,
   hook timeout, and state lock contention are all identifiable from log output alone.
4. **Concurrent invocation correlation**: Every log line carries an `inv=` prefix (short random
   ID) so interleaved output from 20+ concurrent agents can be grouped per invocation.
5. **Cross-platform parity**: The same JSON hook input produces identical log output (modulo
   timestamps and paths) on both macOS/Linux (BATS) and Windows (Pester), validated by shared
   test fixtures in CI.
6. **Daily rotation with pruning**: Log files are named `peon-ping-YYYY-MM-DD.log`, pruned
   based on `debug_retention_days` (default 7), with pruning running at most once per day.
7. **CLI control**: `peon debug on|off|status` toggles the config key; `peon logs` reads and
   filters log files with `--last`, `--session`, and `--clear` options.
8. **Logging never breaks the hook**: All logging I/O wraps in try/catch. Any failure disables
   logging for the remainder of that invocation.

## Current State

### peon.sh (Unix/WSL2)

The main hook script delegates the entire decision pipeline to a single Python block
(`peon.sh:3016-3780`). The Python code runs inside a bash heredoc (`python3 -c "..."`) and
outputs shell variables via `print()` statements that bash consumes via `eval`. Stderr is
redirected to `/dev/null` on the invocation (`peon.sh:3780`: `" <<< "$INPUT" 2>/dev/null`),
silencing all diagnostic output.

The Python block handles these phases sequentially:
1. **Config load** (3031-3062): Read `config.json`, extract all settings
2. **Event parse** (3064-3090): JSON from stdin, map Cursor camelCase → PascalCase
3. **State load** (3092-3129): Atomic read of `.state.json` with retry
4. **Agent detection** (3095-3106): Suppress sounds for delegate-mode sessions
5. **Pack selection** (3131-3241): Session override → path rules → rotation → default
6. **Event routing** (3329-3509): Map hook events to CESP categories with suppression logic
7. **Sound selection** (3552-3614): Load manifest, no-repeat filter, random pick
8. **Notification template** (3715-3740): Resolve `{project}`, `{summary}` placeholders
9. **Trainer** (3616-3670): Check exercise goals, emit reminder sounds
10. **State write** (3672-3692): Atomic persist, relay sync
11. **Output** (3742-3779): Print shell variables for bash to eval

After eval, bash handles audio playback (`play_sound()` at lines 254-505), desktop notifications
(`send_notification()` at 639-858), mobile push (759-859), and tab title/color (3884-3925).

The only existing debug mechanism is a commented-out line at 2992:
```bash
# echo "$(date): peon hook — $INPUT" >> /tmp/peon-ping-debug.log
```

### peon.ps1 (Windows)

Embedded in `install.ps1` (lines 323-1975). Pure PowerShell — no Python dependency. Same
decision pipeline but implemented with PowerShell constructs (`switch`, hashtables,
`ConvertFrom-Json`). Audio playback delegates to `scripts/win-play.ps1`.

The only existing debug mechanism is `PEON_DEBUG=1` in `win-play.ps1` (line 9), which emits
`Write-Warning` for audio failures only — covering none of config loading, event routing, pack
selection, or state management.

### CLI

Top-level `case` statement at `peon.sh:924`. Existing commands: `pause`, `resume`, `mute`,
`unmute`, `toggle`, `status`, `volume`, `rotation`, `packs`, `notifications`, `mobile`,
`relay`, `trainer`, `help`. Tab completions in `completions.bash` (84 lines) and
`completions.fish` (140 lines).

### config.json

44-line template with no `debug` or `debug_retention_days` keys. The config merge logic
in `peon update` backfills new keys from the template into existing user configs.

### Tests

BATS tests (`tests/peon.bats`) use `tests/setup.bash` which creates isolated temp directories
with mock `afplay`, manifests, and config. Pester tests (`tests/adapters-windows.Tests.ps1`)
validate PowerShell adapter syntax and behavior. CI runs BATS on `macos-latest` and Pester
on `windows-latest`.

## Target State

```
                         ┌─────────────────────────────────────────────┐
                         │              Hook Invocation                │
                         │                                            │
  stdin (JSON) ─────────►│  ┌────────────────────────────────────┐    │
                         │  │  Decision Pipeline (Python / PS)   │    │
                         │  │                                    │    │
                         │  │  1. [hook]   event, session, cwd   │    │
                         │  │  2. [config] loaded, volume, pack  │    │
                         │  │  3. [state]  sessions, rotation    │    │
                         │  │  4. [route]  category, suppressed  │    │
                         │  │  5. [sound]  file, pack, candidates│    │
                         │  │  6. [play]   backend, pid, async   │    │
                         │  │  7. [notify] desktop, mobile, tpl  │    │
                         │  │  8. [trainer]reminder, reps        │    │
                         │  │  9. [exit]   duration_ms, exit     │    │
                         │  │                                    │    │
                         │  │  log() ──► no-op (debug=false)     │    │
                         │  │         ──► append (debug=true) ───┼────┼──► $PEON_DIR/logs/
                         │  └────────────────────────────────────┘    │     peon-ping-2026-03-25.log
                         │                                            │     peon-ping-2026-03-24.log
                         │  Shell: play_sound(), notify, tab title    │     (pruned after 7 days)
                         └─────────────────────────────────────────────┘

  CLI:
    peon debug on        ──► sets config.debug = true
    peon debug off       ──► sets config.debug = false
    peon debug status    ──► shows current debug state + log dir size
    peon logs            ──► tails today's log file
    peon logs --last 50  ──► last 50 lines
    peon logs --session abc123 ──► grep by session ID
    peon logs --clear    ──► delete all log files
```

After all phases, a user who runs `peon debug on` and then uses Claude Code normally will find
a daily log file at `$PEON_DIR/logs/peon-ping-YYYY-MM-DD.log` containing 6-10 key=value lines
per hook invocation, each prefixed with a timestamp and invocation ID. The log traces the full
decision chain from event receipt to sound playback (or suppression reason).

## Design

### Architecture

Logging is implemented as a thin function defined at the top of each decision pipeline — a
Python `log()` function in `peon.sh`'s Python block and a PowerShell `$peonLog` scriptblock in
`peon.ps1`. Both are gated on the same condition: `config.debug == true OR PEON_DEBUG=1`. When
disabled, the function is a no-op (Python: `log = lambda *a, **kw: None`; PowerShell:
`$peonLog = { }`) — zero cost, no file I/O, no string formatting.

When enabled, the function:
1. Opens today's daily log file in append mode
2. Formats a key=value line with ISO-8601 timestamp and `[phase]` tag
3. Writes the line (Python: `print()` to file handle; PowerShell: `Add-Content`)
4. On first invocation of a new day's file, prunes old files beyond retention window

The log function is defined once per invocation — it does not re-evaluate the debug flag on
every call. This means toggling `PEON_DEBUG` mid-invocation has no effect (acceptable, since
invocations last 10-200ms).

### Key Design Decisions

**1. Log function defined in the pipeline, not as a library import.**

The Python block runs inside a bash heredoc. Importing external modules adds startup cost and
complexity. A 10-line `log()` function defined inline — with the file handle opened once at
the top and closed implicitly at exit — is simpler, faster, and has zero dependency overhead.
The alternative of `import logging` was evaluated in the ADR and rejected for its per-invocation
import cost (~15-30ms even when disabled, unless the import itself is gated).

**2. Invocation ID generated once, carried through all log lines.**

Each hook invocation generates a 4-character hex ID (`inv=7a3f`) from `os.urandom(2)` (Python)
or `[System.Random]::new().Next(0, 65535).ToString('x4')` (PowerShell). This is cheaper than
UUIDs and sufficient for correlation — collisions within a single day's log file are unlikely
at <500 invocations/day. The ID is generated before the first `log()` call and passed as a
closure variable, so it appears on every line without being passed as an argument.

**3. File handle opened once per invocation, not per log call.**

Python's `open(path, 'a')` with `O_APPEND` semantics is called once when logging is enabled.
All subsequent `log()` calls write to this handle. This avoids 6-10 open/close cycles per
invocation and ensures atomic append semantics on POSIX systems (writes under `PIPE_BUF` are
guaranteed atomic with `O_APPEND`). On Windows, `Add-Content` opens/writes/closes per call —
this is PowerShell's design constraint, and the ADR documents the resulting atomicity asymmetry
under heavy concurrency.

**4. Pruning runs once per day, not per invocation.**

When a log invocation opens a file for today and today's file didn't exist before this
invocation, it also prunes files older than `debug_retention_days`. This is detected by
attempting to create the file with exclusive mode (Python: check `os.path.exists()` before
first write; PowerShell: test `Test-Path`). Subsequent invocations on the same day skip
pruning entirely — they just append.

**5. Values with spaces are double-quoted; values without spaces are unquoted.**

This keeps simple cases (`event=Stop volume=0.5`) scannable while handling edge cases
(`cwd="/home/user/my project"`) unambiguously. The quoting logic is a simple conditional:
if the value contains spaces, quotes, or equals signs, wrap in double quotes with internal
quotes escaped. Both implementations use the same convention, enforced by shared test fixtures
with edge-case inputs.

**6. Shell-side phases ([play], [notify]) log from bash/PowerShell, not Python.**

The Python block handles phases [hook] through [exit] (the decision pipeline). But audio
playback and notification dispatch happen in bash after `eval "$_PEON_PYOUT"`. To log [play]
and [notify] phases, the Python block exports `_PEON_LOG_FILE` and `_PEON_INV_ID` as shell
variables. A small bash `_peon_log()` function (5 lines) appends to the same file using the
same format. On Windows, `peon.ps1` handles everything in PowerShell, so no handoff is needed.

**7. Log format is explicitly unstable — no backward compatibility commitment.**

The ADR states log files are "not a stable API." This design doc reinforces that: the format
may change between any version. The README Debugging section will document this explicitly.
Committing to format stability would constrain improvements to a feature whose primary consumer
is a human reading a file, not a machine parsing it. If machine-parseable output becomes
necessary, the ADR already identifies `debug_format: "jsonl"` as a small future refactor — at
that point, the JSON format would get stability guarantees while key=value stays unstable.

**8. `peon logs` writes to stdout without a pager.**

No `$PAGER` integration. Users who want paging pipe through `less` themselves
(`peon logs | less`). This keeps `peon logs` composable (`peon logs | grep route` works
without `--session`), avoids platform differences in pager availability (Windows has no
default pager), and avoids the complexity of detecting interactive vs. piped contexts. The
`--last N` flag provides output limiting for interactive use.

**9. Windows CLI commands stay inline in install.ps1.**

The `debug` and `logs` CLI branches add ~60 lines to `peon.ps1` (embedded in `install.ps1`).
This follows the existing pattern: every CLI command lives in the main hook script's case/switch
block. Extracting to standalone scripts would add file management complexity, break the
single-file deployment model, and diverge from how Unix handles it. `install.ps1` is already
large; 60 more lines is marginal.

### Interface Design

#### Config Keys

```json
{
  "debug": false,
  "debug_retention_days": 7
}
```

Both keys are added to `config.json` (the template). The `peon update` config merge logic
already backfills new template keys into existing user configs, so no migration code is needed.

#### Log Line Format

```
YYYY-MM-DDTHH:MM:SS.mmm [phase] inv=XXXX key1=val1 key2=val2 ...
```

Timestamp is ISO-8601 with millisecond precision. Phase tags are bracketed. All remaining
fields are `key=value` pairs separated by spaces. Values containing spaces, quotes, or `=`
are double-quoted with `\"` escaping.

#### Phase Emitters

Each phase logs specific fields:

```
[hook]    inv=XXXX event=Stop session=abc123 cwd=/path/to/project paused=false
[config]  inv=XXXX loaded=/path/to/config.json volume=0.5 pack=glados enabled=true
[state]   inv=XXXX sessions=3 rotation_index=2 last_stop=1711368121
[route]   inv=XXXX category=task.complete suppressed=false reason=""
[sound]   inv=XXXX file=mission-complete.wav pack=glados candidates=4 no_repeat=true
[play]    inv=XXXX backend=afplay pid=48291 async=true volume=0.5
[notify]  inv=XXXX desktop=true mobile=false template="✅ {project}: done" rendered="✅ myproj: done"
[trainer] inv=XXXX active=true exercise=pushups reps=150 goal=300 reminder=false
[exit]    inv=XXXX duration_ms=10 exit=0
```

Suppressed invocations log the reason:

```
[route]   inv=XXXX category=none suppressed=true reason=delegate_mode
[route]   inv=XXXX category=task.complete suppressed=true reason=debounce_5s
[route]   inv=XXXX category=none suppressed=true reason=paused
```

Error paths log the failure:

```
[config]  inv=XXXX error="FileNotFoundError: config.json" fallback=defaults
[sound]   inv=XXXX error="pack 'glados' not found" fallback=none
[play]    inv=XXXX error="afplay not found" backend=none
```

#### Python `log()` Function

```python
# Defined at top of Python block, after config load
_inv = os.urandom(2).hex()
_log_enabled = cfg.get('debug', False) or os.environ.get('PEON_DEBUG') == '1'

if _log_enabled:
    import datetime
    _log_dir = os.path.join(peon_dir, 'logs')
    os.makedirs(_log_dir, exist_ok=True)
    _log_date = datetime.date.today().isoformat()
    _log_path = os.path.join(_log_dir, f'peon-ping-{_log_date}.log')
    _log_is_new = not os.path.exists(_log_path)
    _log_fh = open(_log_path, 'a')

    def _log_quote(v):
        s = str(v)
        if ' ' in s or '"' in s or '=' in s or not s:
            return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'
        return s

    def log(phase, **kw):
        ts = datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S.') + \
             f'{datetime.datetime.now().microsecond // 1000:03d}'
        parts = [f'{ts} [{phase}] inv={_inv}']
        for k, v in kw.items():
            parts.append(f'{k}={_log_quote(v)}')
        try:
            print(' '.join(parts), file=_log_fh, flush=True)
        except Exception:
            pass  # logging must never break the hook

    # Prune old logs on first file of the day
    if _log_is_new:
        _retention = cfg.get('debug_retention_days', 7)
        try:
            for f in os.listdir(_log_dir):
                if f.startswith('peon-ping-') and f.endswith('.log'):
                    fdate = f[len('peon-ping-'):-len('.log')]
                    if fdate < (datetime.date.today() -
                                datetime.timedelta(days=_retention)).isoformat():
                        os.remove(os.path.join(_log_dir, f))
        except Exception:
            pass
else:
    log = lambda phase, **kw: None
```

#### PowerShell `$peonLog` Function

```powershell
$peonInv = '{0:x4}' -f [System.Random]::new().Next(0, 65535)
$peonLogEnabled = ($config.debug -eq $true) -or ($env:PEON_DEBUG -eq '1')

if ($peonLogEnabled) {
    $logDir = Join-Path $InstallDir 'logs'
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $logDate = (Get-Date).ToString('yyyy-MM-dd')
    $logPath = Join-Path $logDir "peon-ping-$logDate.log"
    $logIsNew = -not (Test-Path $logPath)

    $peonLog = {
        param([string]$Phase, [hashtable]$Fields)
        $ts = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fff')
        $parts = "$ts [$Phase] inv=$peonInv"
        foreach ($kv in $Fields.GetEnumerator()) {
            $v = [string]$kv.Value
            if ($v -match '[ "=]' -or $v -eq '') {
                $v = '"' + ($v -replace '\\','\\' -replace '"','\"') + '"'
            }
            $parts += " $($kv.Key)=$v"
        }
        try { Add-Content -Path $logPath -Value $parts -ErrorAction Stop }
        catch { $script:peonLogEnabled = $false }  # disable for rest of invocation
    }

    # Prune old logs on first file of the day
    if ($logIsNew) {
        $retention = if ($config.debug_retention_days) { $config.debug_retention_days } else { 7 }
        $cutoff = (Get-Date).AddDays(-$retention).ToString('yyyy-MM-dd')
        Get-ChildItem -Path $logDir -Filter 'peon-ping-*.log' -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -replace 'peon-ping-','' -lt $cutoff } |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
} else {
    $peonLog = { }
}
```

#### Bash `_peon_log()` Function (for [play] and [notify] phases)

```bash
# After eval "$_PEON_PYOUT", if logging is active:
if [ -n "${_PEON_LOG_FILE:-}" ]; then
  _peon_log() {
    local phase="$1"; shift
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S.000')
    printf '%s [%s] inv=%s %s\n' "$ts" "$phase" "$_PEON_INV_ID" "$*" >> "$_PEON_LOG_FILE" 2>/dev/null
  }
else
  _peon_log() { :; }
fi
```

The Python block exports these variables when logging is enabled:
```python
if _log_enabled:
    print('_PEON_LOG_FILE=' + q(_log_path))
    print('_PEON_INV_ID=' + q(_inv))
```

#### CLI Commands

**`peon debug on|off|status`** — Modifies `debug` in config.json.

```bash
# peon debug on
python3 -c "
import json
cfg = json.load(open('$CONFIG_PY'))
cfg['debug'] = True
json.dump(cfg, open('$CONFIG_PY', 'w'), indent=2)
"
echo "peon-ping: debug logging enabled — logs at $PEON_DIR/logs/"

# peon debug off
# Same pattern, cfg['debug'] = False

# peon debug status
# Read config.debug, count log files, show total size
```

**`peon logs [--last N] [--session ID] [--clear]`** — Reads log files.

```bash
# peon logs (no args) — tail today's log, last 50 lines
# peon logs --last 100 — last 100 lines across all log files
# peon logs --session abc123 — grep for session=abc123
# peon logs --clear — rm $PEON_DIR/logs/peon-ping-*.log
```

On Windows, `peon.cmd` delegates to `peon.ps1` which handles `debug` and `logs` subcommands
with equivalent PowerShell logic.

## Implementation Phases

### Phase 1: Core Logging in peon.sh (Python Block + Bash)

**Goal**: A Unix user who runs `peon debug on` sees structured log output for every hook
invocation, covering all decision phases.

**Deliverables:**
- `config.json`: Add `"debug": false` and `"debug_retention_days": 7` keys
- `peon.sh` Python block (~3020): Insert `log()` function definition after config load
- `peon.sh` Python block: Add `log()` calls at each phase:
  - After config load: `log('config', loaded=config_path, volume=..., pack=...)`
  - After event parse: `log('hook', event=..., session=..., cwd=...)`
  - After state load: `log('state', sessions=..., rotation_index=...)`
  - At route decision: `log('route', category=..., suppressed=..., reason=...)`
  - At sound pick: `log('sound', file=..., pack=..., candidates=...)`
  - At notification template: `log('notify', desktop=..., template=..., rendered=...)`
  - At trainer check: `log('trainer', active=..., reminder=...)`
  - At output: `log('exit', duration_ms=..., exit=0)`
- `peon.sh` Python block output: Export `_PEON_LOG_FILE` and `_PEON_INV_ID` when logging active
- `peon.sh` bash (after eval): Define `_peon_log()` shell function for `[play]` phase
- `peon.sh` bash `play_sound()`: Add `_peon_log play backend=... pid=... async=...`
- `peon.sh` bash `send_notification()`: Add `_peon_log notify ...` for desktop/mobile
- Daily rotation: Prune on new-day file creation in Python block
- Error paths: Every `except` block that currently silently falls back gets a `log()` call
  explaining the fallback

**Test strategy:**
- **Unit (BATS)**: Shared test fixture — feed known JSON event input, assert log file contains
  expected key=value lines in correct phase order. Fixture includes edge cases: paths with
  spaces, notification templates with emoji and braces, suppressed events (delegate mode,
  debounce), missing pack.
- **Unit (BATS)**: `debug: false` produces no log file and no `logs/` directory
- **Unit (BATS)**: `PEON_DEBUG=1` env var enables logging even when `debug: false`
- **Unit (BATS)**: Rotation test — create 10 dated log files, set retention to 3, invoke hook,
  assert only 3 remain
- **Integration (BATS)**: Run 5 concurrent hook invocations via `&`, assert all produce
  complete entries (each has `[hook]` through `[exit]`) with distinct `inv=` IDs

**Infrastructure:** None — pure file I/O to existing `$PEON_DIR/`.

**Documentation:** None this phase — Phase 3 covers docs.

**Dependencies:** None.

**Definition of done:**
- [ ] `debug: false` (default) adds <1ms to hook execution time
- [ ] `debug: true` produces a log file at `$PEON_DIR/logs/peon-ping-YYYY-MM-DD.log`
- [ ] Log file contains `[hook]`, `[config]`, `[state]`, `[route]`, `[sound]`, `[play]`,
      `[notify]`, `[exit]` phases for a normal Stop event
- [ ] Suppressed events (delegate mode, debounce, paused) log `[route]` with `reason=`
- [ ] Error paths (missing pack, bad config) log `error=` with fallback
- [ ] 5 concurrent invocations produce non-corrupted output with distinct `inv=` IDs
- [ ] Rotation prunes files older than `debug_retention_days`
- [ ] All existing BATS tests continue to pass (logging is invisible when disabled)

### Phase 2: PowerShell Parity in peon.ps1

**Goal**: A Windows user who runs `peon debug on` sees identical log output to Unix, validated
by the same test fixtures.

**Deliverables:**
- `install.ps1` (peon.ps1 section): Insert `$peonLog` scriptblock definition after config load
- `install.ps1` (peon.ps1 section): Add `& $peonLog` calls at each phase, matching Unix phases
- `install.ps1` (peon.ps1 section): Add `[play]` logging around `win-play.ps1` invocation
- `install.ps1` (peon.ps1 section): `[notify]` logging around `win-notify.ps1` invocation
- `install.ps1` (peon.ps1 section): `Add-Content` with try/catch guard that disables logging
  on `IOException`
- `tests/hook-logging.Tests.ps1`: New Pester test file validating log output against shared
  fixtures

**Test strategy:**
- **Unit (Pester)**: Same shared fixture inputs as Phase 1 — feed JSON, assert log output
  matches expected format character-for-character (excluding timestamp/path/inv values)
- **Unit (Pester)**: `debug: false` produces no log file
- **Unit (Pester)**: `PEON_DEBUG=1` env var override works
- **Unit (Pester)**: Rotation prunes correctly
- **Unit (Pester)**: `Add-Content` failure disables logging for remainder of invocation
  (simulated via read-only file)

**Infrastructure:** None.

**Documentation:** None this phase.

**Dependencies:** Phase 1 (shared fixture format must be established first).

**Definition of done:**
- [ ] PowerShell log output matches Unix format for the shared test fixture inputs
- [ ] `debug: false` adds no measurable overhead
- [ ] `Add-Content` IOException disables logging gracefully (no hook failure)
- [ ] Rotation prunes correctly on Windows
- [ ] All existing Pester tests continue to pass
- [ ] CI runs both BATS and Pester test suites against the shared fixture

### Phase 3: CLI Commands, Completions, and Documentation

**Goal**: Users can toggle debug logging and read logs via `peon debug` and `peon logs`
commands on all platforms, with tab completion and documentation.

**Deliverables:**
- `peon.sh` CLI section (~line 924): Add `debug)` and `logs)` case branches
  - `peon debug on` — set `config.debug = true`, print confirmation with log directory path
  - `peon debug off` — set `config.debug = false`, print confirmation
  - `peon debug status` — show debug state, log file count, total size, retention days
  - `peon logs` — tail today's log file (last 50 lines)
  - `peon logs --last N` — last N lines across log files (newest first)
  - `peon logs --session ID` — grep all log files for `session=ID`
  - `peon logs --clear` — delete all log files with confirmation prompt
- `install.ps1` (peon.ps1 CLI section): Add equivalent `debug` and `logs` commands
- `completions.bash`: Add `debug` and `logs` to top-level commands, `on off status` for debug,
  `--last --session --clear` for logs
- `completions.fish`: Add same completions with descriptions
- `README.md`: Add "Debugging" section documenting `peon debug`, `peon logs`, log format, and
  common failure diagnosis patterns
- `README_zh.md`: Translated equivalent of Debugging section
- `docs/public/llms.txt`: Update with debugging commands and log format

**Test strategy:**
- **Unit (BATS)**: `peon debug on` sets `config.debug` to `true` in config file
- **Unit (BATS)**: `peon debug off` sets `config.debug` to `false`
- **Unit (BATS)**: `peon debug status` outputs current state
- **Unit (BATS)**: `peon logs --last 10` outputs correct number of lines
- **Unit (BATS)**: `peon logs --session abc123` filters correctly
- **Unit (BATS)**: `peon logs --clear` removes log files
- **Unit (Pester)**: Equivalent tests for Windows CLI commands

**Infrastructure:** None.

**Documentation:** README.md, README_zh.md, docs/public/llms.txt (all part of this phase).

**Dependencies:** Phase 1 (Unix logging), Phase 2 (Windows logging).

**Definition of done:**
- [ ] `peon debug on` enables logging, `peon debug off` disables it (both platforms)
- [ ] `peon debug status` shows debug state and log statistics
- [ ] `peon logs` displays recent log entries with correct formatting
- [ ] `peon logs --session` filters by session ID
- [ ] `peon logs --clear` removes log files with confirmation
- [ ] Tab completion works in bash, zsh, and fish for all new commands
- [ ] README.md Debugging section explains the 5 common failure patterns and how to diagnose
      each from log output
- [ ] README_zh.md has translated equivalent
- [ ] `docs/public/llms.txt` updated
- [ ] All new CLI commands have BATS and Pester test coverage

## Migration & Rollback

**Migration**: Pure addition. Two new keys (`debug`, `debug_retention_days`) added to
`config.json` template. The `peon update` config merge logic already backfills missing keys
from the template, so existing users get the new keys with defaults on next update. Users
who never update still work — the Python/PowerShell code defaults to `False`/`7` when keys
are absent.

**Backward compatibility**: The existing `PEON_DEBUG=1` env var in `win-play.ps1` continues
to work independently. When both the new config-based logging and the legacy `PEON_DEBUG`
are active, both outputs fire — they are additive, covering different scopes (full pipeline
vs. audio-only).

**Rollback**: Clean git revert. No state migration, no external dependencies, no schema
changes. Log files in `$PEON_DIR/logs/` can be deleted manually or via `peon logs --clear`.

## Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Format drift between Python and PowerShell implementations | Users see inconsistent log output across platforms; tooling built on log format breaks | Medium | Shared test fixtures with identical expected output, validated by both BATS and Pester in CI. Any format change must update the fixture and pass both platforms. |
| Log I/O causes hook timeout under heavy concurrency | Hooks killed by 10-second Claude Code timeout, sounds stop playing | Low | Log writes are <1ms each (append to open handle). Total logging budget is ~5ms for 8-10 calls. If I/O blocks (disk contention), try/catch disables logging for remainder of invocation. |
| Windows `Add-Content` lock contention drops log entries | Sprint operators missing diagnostic data for some concurrent invocations | Medium (sprint dispatch only) | Documented in ADR as acceptable tradeoff. Try/catch disables logging per-invocation on IOException. Recommend `PEON_DEBUG=1` env var per-agent for targeted diagnosis. |
| `datetime` import adds startup cost even when logging disabled | Violates <1ms overhead requirement | Low | `import datetime` is inside the `if _log_enabled:` branch. When disabled, no import occurs. |
| Log files grow large with many concurrent agents | Disk space consumption | Low | Daily rotation with 7-day default retention. At worst case (500 invocations/day × 800 bytes × 7 days), total is ~2.8 MB. `peon logs --clear` provides manual cleanup. |

## Roadmap Connection

This design implements **v2/m4** ("When something breaks, you can see why"), which currently
has no features or projects defined. After this design doc is accepted:

1. Create features under m4 for each phase (or a single feature with 3 projects matching the
   3 implementation phases)
2. The sprint-architect can create cards directly from the phase definitions of done
3. M4's `docs_ref` should be updated to point to this design doc (the milestone already
   references PRD-002)

## Known Asymmetries

### `paused.expected.txt` fixture is Unix-only

The shared test fixture `tests/fixtures/hook-logging/paused.expected.txt` validates log output
when the hook is invoked while peon-ping is paused (`enabled: false`). This fixture applies only
to the Unix (BATS) side.

On Windows, `peon.ps1` exits early when paused — `if (-not $config.enabled) { exit 0 }` fires
before the logging infrastructure is initialized, so no log file is created. The Pester test
validates only that the exit code is 0 in the paused case.

This diverges from `peon.sh`, where the Python block runs past the enabled check and logs the
paused state mid-pipeline (the `[hook] ... paused=true` line appears in the log before the
script exits). The asymmetry is inherent to the implementation: Python evaluates the full
decision pipeline and emits log lines along the way, while PowerShell's early-exit guard
precedes all logging setup.

## Open Questions

None — all resolved during design.

---

## Revision History

| Date | Author | Notes |
|------|--------|-------|
| 2026-03-25 | cameron | Initial design |
