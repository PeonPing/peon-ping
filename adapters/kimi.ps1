# peon-ping adapter for Kimi Code CLI (MoonshotAI) (Windows)
# Translates Kimi Code hook events into peon.ps1 stdin JSON.
#
# Kimi Code ships a native hook system: `[[hooks]]` entries in
# ~/.kimi-code/config.toml run a shell command and deliver the event as JSON on
# stdin. The payload keys are snake_case (`hook_event_name`, `session_id`,
# `cwd`, `tool_name`, `tool_input`), which is already the shape peon.ps1 reads,
# so this adapter only has to prefix the session id, tag the source, and drop
# the events that would be noise.
#
# Docs: https://moonshotai.github.io/kimi-code/en/customization/hooks
#
# Usage:
#   powershell -NoProfile -File adapters/kimi.ps1 -Install       Register hooks
#   powershell -NoProfile -File adapters/kimi.ps1 -Uninstall     Remove them
#   powershell -NoProfile -File adapters/kimi.ps1 -Status        Report state
#   powershell -NoProfile -File adapters/kimi.ps1 -StopWatcher   Only reap the old daemon
#   powershell -NoProfile -File adapters/kimi.ps1                Hook mode (stdin)
#
# -Install and -Uninstall also reap the watcher daemon this adapter used to be,
# so updating from v2.37.0 or earlier does not leave it running.
#
# Kimi treats a hook exit code of 2 as "block this operation" on UserPromptSubmit,
# PreToolUse and Stop, so every path here exits 0 and peon.ps1's stdout is
# discarded.

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status,
    [switch]$StopWatcher,
    [switch]$Help
)

$ErrorActionPreference = "SilentlyContinue"

# --- Locations ---------------------------------------------------------------

$SelfPath = $MyInvocation.MyCommand.Path

# Prefer the env var, then this script's own install root (adapters/..), so a
# non-default install keeps working without embedding env vars in the TOML.
$PeonDir = $env:CLAUDE_PEON_DIR
if (-not $PeonDir) {
    $scriptDir = Split-Path -Parent $SelfPath
    if ($scriptDir) { $PeonDir = Split-Path -Parent $scriptDir }
}
if (-not $PeonDir) { $PeonDir = Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"

# Kimi Code lives in ~/.kimi-code. ~/.kimi is the older kimi-cli; prefer the
# former and fall back so an existing kimi-cli install keeps working.
$KimiDir = $env:KIMI_DIR
if (-not $KimiDir) {
    $kimiCode = Join-Path $env:USERPROFILE ".kimi-code"
    $kimiLegacy = Join-Path $env:USERPROFILE ".kimi"
    if (Test-Path (Join-Path $kimiCode "config.toml")) { $KimiDir = $kimiCode }
    elseif (Test-Path (Join-Path $kimiLegacy "config.toml")) { $KimiDir = $kimiLegacy }
    # Neither home holds a config yet. An existing kimi-cli one still beats
    # creating a Kimi Code config that nothing on this machine reads.
    elseif ((-not (Test-Path $kimiCode)) -and (Test-Path $kimiLegacy)) { $KimiDir = $kimiLegacy }
    else { $KimiDir = $kimiCode }
}

$KimiConfig = $env:KIMI_CONFIG
if (-not $KimiConfig) { $KimiConfig = Join-Path $KimiDir "config.toml" }

$BeginMarker = "# peon-ping Kimi hooks begin"
$EndMarker   = "# peon-ping Kimi hooks end"
# Appended to the begin marker when -Install had to terminate the config's last
# line before it could add the block, so -Uninstall knows to take that newline
# back. Without it "a" and "a`n" install to the same bytes. Shared with kimi.sh,
# so either adapter can remove a block the other wrote.
$EofNote = "(newline added at end of file)"

# Leftovers from the watcher daemon this adapter replaced. See
# Stop-LegacyWatcher below.
$LegacyPidFile = Join-Path $PeonDir ".kimi-adapter.pid"
$LegacyLogFile = Join-Path $PeonDir ".kimi-adapter.log"

# Events peon-ping registers, out of the sixteen in Kimi Code's
# HOOK_EVENT_TYPES. PreToolUse/PostToolUse fire on every tool call, PostCompact
# duplicates PreCompact, and Interrupt/Notification have no CESP category, so
# those five stay unregistered. PermissionResult is registered but silent: it
# maps to PreToolUse so the tab title stops saying "needs approval" once the
# prompt is answered.
$HookEvents = @(
    "SessionStart",
    "SessionEnd",
    "UserPromptSubmit",
    "Stop",
    "StopFailure",
    "PermissionRequest",
    "PermissionResult",
    "PostToolUseFailure",
    "SubagentStart",
    "SubagentStop",
    "PreCompact"
)

# The older kimi-cli (~/.kimi) has hooks from 1.28.0 on, but its schema has
# thirteen events and none of these. It validates `event` against that list
# and refuses to load a config.toml naming any other, so registering them
# would stop kimi-cli from starting at all. Only Kimi Code's own home is known
# to take the full list; every other config gets the events both accept.
# Kimi Code can also be moved off ~/.kimi-code with KIMI_CODE_HOME.
$KimiCodeOnlyEvents = @("PermissionRequest", "PermissionResult")

function Get-FullPath([string]$path) {
    try { return [System.IO.Path]::GetFullPath($path).TrimEnd('\', '/') } catch { return $path }
}

$KimiConfigDir = Split-Path -Parent $KimiConfig
$isKimiCode = (Split-Path -Leaf $KimiConfigDir) -eq ".kimi-code"
if (-not $isKimiCode -and $env:KIMI_CODE_HOME) {
    # -eq is case-insensitive, as the file system is.
    $isKimiCode = (Get-FullPath $KimiConfigDir) -eq (Get-FullPath $env:KIMI_CODE_HOME)
}
if ($isKimiCode) {
    $KimiTarget = "Kimi Code"
    $RegisterEvents = $HookEvents
} else {
    $KimiTarget = "kimi-cli"
    $RegisterEvents = @($HookEvents | Where-Object { $KimiCodeOnlyEvents -notcontains $_ })
}

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Write-Warn([string]$message) {
    # stderr: uninstall.ps1 discards the adapter's stdout.
    [Console]::Error.WriteLine("! $message")
}

function Get-Field($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    $prop = $obj.PSObject.Properties[$name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-ErrorText($value) {
    # PostToolUseFailure carries `error` as an object -- Kimi 0.41 sends
    # { code, message, retryable } -- so pull the message out rather than
    # stringifying the whole thing into "@{code=...; message=...}". The text
    # reaches a notification and a tab title, so collapse its whitespace.
    if ($null -eq $value) { return "" }
    $text = ""
    if ($value -is [string]) {
        $text = $value
    } else {
        $message = Get-Field $value 'message'
        if ($message) { $text = "$message" }
        elseif ($value -isnot [System.Management.Automation.PSCustomObject]) { $text = "$value" }
    }
    return ($text -replace '\s+', ' ').Trim()
}

# --- Legacy watcher ------------------------------------------------------------

function Split-CommandLine([string]$commandLine) {
    # Windows hands a process one command-line string, not an argv array; split
    # it the way the C runtime does, so argument boundaries are the real ones
    # rather than wherever a space happens to fall.
    if (-not ('PeonPing.KimiNative' -as [type])) {
        Add-Type -Namespace PeonPing -Name KimiNative -MemberDefinition @'
[DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr CommandLineToArgvW(string lpCmdLine, out int pNumArgs);
[DllImport("kernel32.dll")]
public static extern IntPtr LocalFree(IntPtr hMem);
'@
    }
    $argc = 0
    $argvPtr = [PeonPing.KimiNative]::CommandLineToArgvW($commandLine, [ref]$argc)
    if ($argvPtr -eq [IntPtr]::Zero) { return ,@() }
    try {
        $argv = New-Object string[] $argc
        for ($i = 0; $i -lt $argc; $i++) {
            $argPtr = [System.Runtime.InteropServices.Marshal]::ReadIntPtr($argvPtr, $i * [IntPtr]::Size)
            $argv[$i] = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($argPtr)
        }
        return ,$argv
    } finally {
        [PeonPing.KimiNative]::LocalFree($argvPtr) | Out-Null
    }
}

function Test-WatcherScript([string]$path) {
    # Whether $path names this install's adapter. The watcher was launched with
    # $MyInvocation.MyCommand.Path, which is always absolute, so a relative path
    # is not it.
    if (-not $path -or -not [System.IO.Path]::IsPathRooted($path)) { return $false }
    $full = Get-FullPath $path
    foreach ($candidate in @((Join-Path $PeonDir "adapters\kimi.ps1"), $SelfPath)) {
        if ($candidate -and $full -eq (Get-FullPath $candidate)) { return $true }
    }
    return $false
}

function Test-LegacyWatcher($proc) {
    # The watcher was started as
    #   Start-Process powershell -ArgumentList "-NoProfile", "-File", "<adapter>"
    # so its argv is exactly (powershell, -NoProfile, -File, <adapter>), and
    # <adapter> has to be this install's. A process that merely is PowerShell, or
    # mentions kimi.ps1 -- another session, another install, this adapter run as
    # a hook or with a switch -- does not qualify.
    # The executable, unlike argv[0], is not the parent's choice. The watcher
    # always ran under Windows PowerShell, and a process whose executable or
    # command line cannot be read (another user's, an elevated one) cannot be
    # verified, so it is left alone.
    if (-not $proc.ExecutablePath -or (Split-Path -Leaf $proc.ExecutablePath) -ne "powershell.exe") { return $false }
    if (-not $proc.CommandLine) { return $false }
    $argv = Split-CommandLine $proc.CommandLine
    if ($argv.Count -ne 4) { return $false }
    if ((Split-Path -Leaf $argv[0]) -notmatch '^powershell(\.exe)?$') { return $false }
    if ($argv[1] -ne "-NoProfile" -or $argv[2] -ne "-File") { return $false }
    return (Test-WatcherScript $argv[3])
}

function Stop-LegacyWatcher {
    # Up to v2.37.0 this adapter was a filesystem watcher daemon holding a
    # pidfile. An update only replaces the script on disk, so that process
    # survives it and keeps piping its own events to peon.ps1 -- every sound
    # twice once the hooks are live. Reap it before registering them.
    if (Test-Path -LiteralPath $LegacyPidFile) {
        $stopped = $false
        $pidText = (Get-Content -LiteralPath $LegacyPidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
        $legacyPid = 0
        if ([int]::TryParse("$pidText".Trim(), [ref]$legacyPid) -and $legacyPid -gt 0 -and $legacyPid -ne $PID) {
            $proc = Get-CimInstance Win32_Process -Filter "ProcessId = $legacyPid" -ErrorAction SilentlyContinue
            if ($proc) {
                # A pid outlives the process that wrote it, so only stop the
                # watcher itself, never whatever inherited the number.
                if (Test-LegacyWatcher $proc) {
                    Get-CimInstance Win32_Process -Filter "ParentProcessId = $legacyPid" -ErrorAction SilentlyContinue |
                        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                    Stop-Process -Id $legacyPid -Force -ErrorAction SilentlyContinue
                    $stopped = $true
                } elseif ("$($proc.CommandLine)" -match '(?i)kimi\.ps1') {
                    Write-Warn "PID $legacyPid may be the old Kimi watcher, but its command line could not be verified; left it running."
                    Write-Warn "If it is, stop it with: Stop-Process -Id $legacyPid"
                }
            }
        }
        Remove-Item -LiteralPath $LegacyPidFile -Force -ErrorAction SilentlyContinue
        if ($stopped) {
            Write-Host "Stopped the old Kimi watcher daemon (native hooks replace it)"
        }
    }
    Remove-Item -LiteralPath $LegacyLogFile -Force -ErrorAction SilentlyContinue
}

# --- Config editing ------------------------------------------------------------
#
# The config is handled as bytes, never decoded and re-encoded: only the
# managed block is ours, and everything around it -- non-ASCII text in any
# encoding, a BOM, whitespace-only lines inside multiline strings, CRs, a
# missing final newline -- has to come back exactly as it was. The markers are
# ASCII, so finding them in the bytes is enough.

function Exit-ConfigError([string]$message) {
    # $ErrorActionPreference is SilentlyContinue for hook mode, which would let a
    # failed read or write fall through to a success message and exit 0 --
    # uninstall.ps1 would then delete the adapter the hooks still point at.
    [Console]::Error.WriteLine("x $message")
    exit 1
}

function Read-ConfigBytes([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return ,([byte[]]@()) }
    try {
        return ,([System.IO.File]::ReadAllBytes($path))
    } catch {
        Exit-ConfigError "Could not read ${path}: $($_.Exception.InnerException.Message)"
    }
}

function Get-ConfigLines([byte[]]$bytes) {
    # Lines as awk sees them in kimi.sh: split on LF, the LF dropped, a CR kept.
    $lines = New-Object System.Collections.Generic.List[object]
    $start = 0
    while ($start -lt $bytes.Length) {
        $lf = [Array]::IndexOf($bytes, [byte]10, $start)
        $stop = if ($lf -ge 0) { $lf } else { $bytes.Length }
        $lines.Add([PSCustomObject]@{
            Start = $start
            Next  = if ($lf -ge 0) { $lf + 1 } else { $bytes.Length }
            Text  = $Utf8NoBom.GetString($bytes, $start, $stop - $start)
        })
        $start = $stop + 1
    }
    return ,$lines
}

function Find-KimiBlock([byte[]]$bytes) {
    # Locate the managed block: State is "none", "open" (a begin marker with no
    # end marker after it) or "found". For a found block, KeepBytes is where the
    # bytes ahead of it end -- before the blank separator line -Install writes,
    # if it is there -- and TailStart where the bytes after its end marker begin.
    $lines = Get-ConfigLines $bytes
    $begin = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($begin -lt 0) {
            if ($lines[$i].Text.StartsWith($BeginMarker)) { $begin = $i }
            continue
        }
        if ($lines[$i].Text.StartsWith($EndMarker)) {
            $beginText = $lines[$begin].Text
            $sep = $begin -gt 0 -and ($lines[$begin - 1].Text -eq "" -or $lines[$begin - 1].Text -eq "`r")
            return [PSCustomObject]@{
                State     = "found"
                KeepBytes = if ($sep) { $lines[$begin - 1].Start } else { $lines[$begin].Start }
                TailStart = $lines[$i].Next
                Eof       = $beginText.Contains($EofNote)
                Crlf      = $beginText.EndsWith("`r")
            }
        }
    }
    return [PSCustomObject]@{ State = $(if ($begin -ge 0) { "open" } else { "none" }) }
}

function Join-Bytes([byte[]]$bytes, [int]$length, [byte[]]$tail) {
    $out = New-Object byte[] ($length + $tail.Length)
    [Array]::Copy($bytes, 0, $out, 0, $length)
    [Array]::Copy($tail, 0, $out, $length, $tail.Length)
    return ,$out
}

function Remove-KimiBlock([byte[]]$bytes) {
    # Return the config with the managed block removed, along with the separator
    # and EOF newline -Install added for it, and every other byte untouched.
    # $null for an unterminated block, rather than guess where it ends.
    $block = Find-KimiBlock $bytes
    if ($block.State -eq "none") { return ,$bytes }
    if ($block.State -eq "open") { return $null }

    $tailLength = $bytes.Length - $block.TailStart
    $tail = New-Object byte[] $tailLength
    [Array]::Copy($bytes, $block.TailStart, $tail, 0, $tailLength)

    # Only take the EOF newline back if the block is still last in the file:
    # anything appended after it needs that newline to stay on its own line.
    $keep = $block.KeepBytes
    if ($block.Eof -and $keep -gt 0 -and $tailLength -eq 0) {
        $keep -= $(if ($block.Crlf) { 2 } else { 1 })
    }
    return ,(Join-Bytes $bytes $keep $tail)
}

function Write-ConfigBytes([string]$path, [byte[]]$bytes) {
    # WriteAllBytes truncates and writes through the existing file instead of
    # replacing it, so its ACL, attributes and any symlink survive.
    try {
        [System.IO.File]::WriteAllBytes($path, $bytes)
    } catch {
        Exit-ConfigError "Could not write ${path}: $($_.Exception.InnerException.Message)"
    }
}

function Test-HasBlock([string]$path) {
    # Through Read-ConfigBytes, so an unreadable config fails loudly instead of
    # passing for one without a block.
    $bytes = Read-ConfigBytes $path
    return $Utf8NoBom.GetString($bytes).Contains($BeginMarker)
}

function Get-UnmanagedHookCount([string]$path) {
    # Count lines outside the managed block that run this adapter. Kimi Code's
    # kimi-cli migration copies [[hooks]] from ~/.kimi/config.toml into its own
    # config by re-serializing them, which drops our markers, so a block from a
    # kimi-cli install can come back unmarked next to the one -Install writes.
    # Only the marked block is ours to edit; these are reported, not touched.
    # Kept in sync with count_unmanaged_hooks in kimi.sh.
    $n = 0
    $skip = $false
    foreach ($line in [System.IO.File]::ReadAllLines($path, $Utf8NoBom)) {
        if ($line.StartsWith($BeginMarker)) { $skip = $true; continue }
        if ($line.StartsWith($EndMarker))   { $skip = $false; continue }
        if ($skip -or $line -match '^\s*#') { continue }
        if ($line -match 'adapters[\\/]+kimi\.(sh|ps1)') { $n++ }
    }
    return $n
}

function Show-UnmanagedHooks {
    if (-not (Test-Path -LiteralPath $KimiConfig)) { return }
    $n = Get-UnmanagedHookCount $KimiConfig
    if ($n -le 0) { return }
    Write-Warn "$KimiConfig has $n hook command(s) outside the peon-ping block that run the Kimi adapter."
    Write-Warn "Kimi Code's migration from kimi-cli copies hooks without the block markers, so these"
    Write-Warn "were likely carried over from ~/.kimi. Alongside the block they can make events fire"
    Write-Warn "twice, and uninstalling peon-ping leaves them behind. Remove those [[hooks]] entries by hand."
}

function ConvertTo-TomlString([string]$value) {
    # A literal string takes a Windows path verbatim; a basic string would read
    # every backslash as an escape. Only a path containing a single quote --
    # which a literal string cannot express -- falls back to a basic string.
    if ($value.Contains("'")) {
        $escaped = $value.Replace('\', '\\').Replace('"', '\"')
        return '"' + $escaped + '"'
    }
    return "'" + $value + "'"
}

# --- Management modes --------------------------------------------------------

if ($Help) {
    Write-Host "Usage: powershell -NoProfile -File kimi.ps1 [-Install|-Uninstall|-Status|-StopWatcher]"
    Write-Host ""
    Write-Host "  -Install       Register peon-ping hooks in $KimiConfig"
    Write-Host "  -Uninstall     Remove them"
    Write-Host "  -Status        Report whether they are registered"
    Write-Host "  -StopWatcher   Only stop the watcher daemon this adapter used to be"
    Write-Host "  (no args)      Hook mode: read one Kimi event as JSON on stdin and forward it"
    exit 0
}

if ($Status) {
    if (Test-HasBlock $KimiConfig) {
        $count = 0
        $inBlock = $false
        foreach ($line in [System.IO.File]::ReadAllLines($KimiConfig, $Utf8NoBom)) {
            if ($line.StartsWith($BeginMarker)) { $inBlock = $true; continue }
            if ($line.StartsWith($EndMarker))   { $inBlock = $false; continue }
            if ($inBlock -and $line.StartsWith("event = ")) { $count++ }
        }
        Write-Host "peon-ping hooks registered in $KimiConfig ($count events)"
        Show-UnmanagedHooks
        exit 0
    }
    Write-Host "peon-ping hooks not registered in $KimiConfig"
    Show-UnmanagedHooks
    exit 1
}

if ($StopWatcher) {
    # For uninstall.ps1, which handles each config itself but still has to reap
    # a daemon left by an install that never registered hooks.
    Stop-LegacyWatcher
    exit 0
}

if ($Uninstall) {
    Stop-LegacyWatcher
    if (-not (Test-Path -LiteralPath $KimiConfig)) {
        Write-Host "Nothing to remove ($KimiConfig does not exist)."
        exit 0
    }
    if (-not (Test-HasBlock $KimiConfig)) {
        Write-Host "Nothing to remove (no peon-ping block found)."
        Show-UnmanagedHooks
        exit 0
    }
    $stripped = Remove-KimiBlock (Read-ConfigBytes $KimiConfig)
    if ($null -eq $stripped) {
        [Console]::Error.WriteLine("x $KimiConfig has `"$BeginMarker`" without `"$EndMarker`"; fix it by hand.")
        exit 1
    }
    Write-ConfigBytes $KimiConfig $stripped
    Write-Host "Removed peon-ping hooks from $KimiConfig"
    Show-UnmanagedHooks
    exit 0
}

if ($Install) {
    if (-not (Test-Path $PeonScript)) {
        # $ErrorActionPreference is SilentlyContinue for hook mode, which would
        # swallow Write-Error, so report the failure on the host stream.
        Write-Host "peon.ps1 not found at $PeonScript" -ForegroundColor Red
        exit 1
    }
    Stop-LegacyWatcher
    if (-not (Test-Path $KimiDir)) { New-Item -ItemType Directory -Path $KimiDir -Force | Out-Null }

    $adapterPath = $SelfPath
    if (-not $adapterPath) { $adapterPath = Join-Path $PeonDir "adapters\kimi.ps1" }

    # Rewriting from scratch keeps -Install idempotent.
    $stripped = Remove-KimiBlock (Read-ConfigBytes $KimiConfig)
    if ($null -eq $stripped) {
        [Console]::Error.WriteLine("x $KimiConfig has `"$BeginMarker`" without `"$EndMarker`"; fix it by hand.")
        exit 1
    }

    # Match the config's line endings so a CRLF file stays CRLF. Kimi writes it
    # from Node, so a fresh one is LF even on Windows.
    $nl = "`n"
    if ([System.Text.Encoding]::ASCII.GetString($stripped) -match "`r(`n|$)") { $nl = "`r`n" }

    # Kimi spawns the hook with Node's `shell: true`, which on Windows means
    # `cmd.exe /d /s /c "<command>"`. cmd splits on spaces, so the adapter path
    # has to carry its own quotes or an install under "C:\Users\First Last\..."
    # never starts.
    $command = "powershell -NoProfile -NonInteractive -File `"$adapterPath`""

    $block = New-Object System.Text.StringBuilder
    $beginLine = $BeginMarker
    # Separate the block from existing content with one blank line, but do not
    # open an empty config with one. A last line without a newline has to be
    # terminated first; $EofNote records that for -Uninstall.
    if ($stripped.Length -gt 0) {
        if ($stripped[$stripped.Length - 1] -ne 10) {
            [void]$block.Append($nl)
            $beginLine = "$BeginMarker $EofNote"
        }
        [void]$block.Append($nl)
    }
    [void]$block.Append("$beginLine$nl")
    [void]$block.Append("# install_dir = $PeonDir$nl")
    foreach ($ev in $RegisterEvents) {
        [void]$block.Append("$nl[[hooks]]$nl")
        [void]$block.Append("event = `"$ev`"$nl")
        [void]$block.Append("command = $(ConvertTo-TomlString $command)$nl")
        [void]$block.Append("timeout = 10$nl")
    }
    [void]$block.Append("$nl$EndMarker$nl")

    $blockBytes = $Utf8NoBom.GetBytes($block.ToString())
    Write-ConfigBytes $KimiConfig (Join-Bytes $stripped $stripped.Length $blockBytes)

    Write-Host "peon-ping hooks registered for $KimiTarget"
    Write-Host "  config:  $KimiConfig"
    Write-Host "  adapter: $adapterPath"
    Write-Host "  events:  $($RegisterEvents -join ' ')"
    if ($RegisterEvents.Count -lt $HookEvents.Count) {
        Write-Warn "Left out $($KimiCodeOnlyEvents -join ' '): only Kimi Code (~/.kimi-code) has them,"
        Write-Warn "and the older kimi-cli refuses to start with a config that names them."
        Write-Warn "Approval prompts stay silent until you move to Kimi Code."
    }
    Show-UnmanagedHooks
    Write-Host ""
    if ($KimiTarget -eq "Kimi Code") {
        Write-Host "Run 'kimi doctor' to validate, then restart Kimi Code."
    } else {
        Write-Host "Restart kimi-cli (1.28.0 or later; earlier versions have no hooks)."
    }
    exit 0
}

# --- Hook mode ---------------------------------------------------------------

if (-not (Test-Path $PeonScript)) { exit 0 }
if (-not [Console]::IsInputRedirected) { exit 0 }

$inputJson = $null
try {
    $stream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    $raw = $reader.ReadToEnd()
    $reader.Close()
    if ($raw) { $inputJson = $raw | ConvertFrom-Json }
} catch {
    if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [kimi] ConvertFrom-Json failed: $_" }
}
if ($null -eq $inputJson) { exit 0 }

$event = "$(Get-Field $inputJson 'hook_event_name')".Trim()
if (-not $event) { exit 0 }

# The five events -Install leaves out. Dropped here too, in case someone wired
# them by hand.
$drop = @(
    "PreToolUse", "PostToolUse", "PostCompact", "Interrupt", "Notification"
)
$pass = @(
    "SessionStart", "SessionEnd", "UserPromptSubmit", "Stop",
    "PermissionRequest", "PostToolUseFailure", "SubagentStart",
    "SubagentStop", "PreCompact"
)

$mapped = $null
if ($drop -contains $event) {
    exit 0
} elseif ($pass -contains $event) {
    $mapped = $event
} elseif ($event -eq "StopFailure") {
    # The turn itself failed. peon.ps1 has no separate category, so borrow the
    # tool-failure path, which sounds task.error.
    $mapped = "PostToolUseFailure"
} elseif ($event -eq "PermissionResult") {
    # Silent in peon.ps1: only clears the "needs approval" tab title.
    $mapped = "PreToolUse"
} else {
    exit 0
}

# Kimi ids look like "session_<uuid>"; peon.ps1 infers the IDE from the
# session_id prefix, so it has to start with "kimi-".
$rawSid = "$(Get-Field $inputJson 'session_id')"
$rawSid = $rawSid -replace '^session[_-]', ''
$safeSid = ($rawSid -replace '[^A-Za-z0-9._:-]', '-').Trim('-')
if (-not $safeSid) { $safeSid = "$PID" }

$cwd = "$(Get-Field $inputJson 'cwd')"
if (-not $cwd) { $cwd = $PWD.Path }

$payload = @{
    hook_event_name   = $mapped
    notification_type = ""
    cwd               = $cwd
    session_id        = "kimi-$safeSid"
    permission_mode   = "$(Get-Field $inputJson 'permission_mode')"
    source            = "kimi"
}

$toolName = "$(Get-Field $inputJson 'tool_name')"
if ($toolName) { $payload["tool_name"] = $toolName.Substring(0, [Math]::Min(64, $toolName.Length)) }

if ($mapped -eq "PostToolUseFailure") {
    # peon.ps1 only sounds task.error for a Bash failure carrying error text.
    # StopFailure has no tool at all and is attributed to Bash the way codex.ps1
    # does it.
    if (-not $payload["tool_name"]) { $payload["tool_name"] = "Bash" }
    $err = Get-ErrorText (Get-Field $inputJson 'error')
    if (-not $err) { $err = Get-ErrorText (Get-Field $inputJson 'message') }
    if (-not $err) {
        if ($event -eq "StopFailure") { $err = "turn failed" }
        else { $err = "$($payload['tool_name']) failed" }
    }
    $payload["error"] = $err.Substring(0, [Math]::Min(180, $err.Length))
}

$title = "$(Get-Field $inputJson 'session_title')"
if ($title) { $payload["transcript_summary"] = $title.Substring(0, [Math]::Min(120, $title.Length)) }

$payloadJson = $payload | ConvertTo-Json -Compress

# Windows PowerShell 5.1 pipes to a native process in $OutputEncoding, which
# defaults to ASCII and turns a Chinese cwd or session title into "??".
# peon.ps1 reads its stdin as UTF-8, so send exactly that, without a BOM.
$OutputEncoding = $Utf8NoBom

# stdout is swallowed: Kimi parses a hook's stdout as a decision document.
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null | Out-Null

exit 0
