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
#   powershell -NoProfile -File adapters/kimi.ps1 -Install     Register hooks
#   powershell -NoProfile -File adapters/kimi.ps1 -Uninstall   Remove them
#   powershell -NoProfile -File adapters/kimi.ps1 -Status      Report state
#   powershell -NoProfile -File adapters/kimi.ps1              Hook mode (stdin)
#
# Kimi treats a hook exit code of 2 as "block this operation" on UserPromptSubmit,
# PreToolUse and Stop, so every path here exits 0 and peon.ps1's stdout is
# discarded.

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status,
    [switch]$Help
)

$ErrorActionPreference = "SilentlyContinue"

# --- Locations ---------------------------------------------------------------

# Prefer the env var, then this script's own install root (adapters/..), so a
# non-default install keeps working without embedding env vars in the TOML.
$PeonDir = $env:CLAUDE_PEON_DIR
if (-not $PeonDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
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
    else { $KimiDir = $kimiCode }
}

$KimiConfig = $env:KIMI_CONFIG
if (-not $KimiConfig) { $KimiConfig = Join-Path $KimiDir "config.toml" }

$BeginMarker = "# peon-ping Kimi hooks begin"
$EndMarker   = "# peon-ping Kimi hooks end"

# Events peon-ping registers, out of the sixteen in Kimi's HOOK_EVENT_TYPES.
# PreToolUse/PostToolUse fire on every tool call, PostCompact duplicates
# PreCompact, and Interrupt/Notification have no CESP category, so those five
# stay unregistered. PermissionResult is registered but silent: it maps to
# PreToolUse so the tab title stops saying "needs approval" once the prompt is
# answered.
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

function Get-StrippedConfig([string]$path) {
    # Return the config's lines with any previously installed block removed,
    # marker lines included.
    if (-not (Test-Path $path)) { return @() }
    $kept = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in (Get-Content -LiteralPath $path)) {
        if ($line.StartsWith($BeginMarker)) {
            # -Install writes exactly one blank separator line ahead of the
            # marker, so take that one back with the block -- and only that one,
            # or -Uninstall would eat a blank line the config already had.
            if ($kept.Count -gt 0 -and [string]::IsNullOrWhiteSpace($kept[$kept.Count - 1])) {
                $kept.RemoveAt($kept.Count - 1)
            }
            $skip = $true
            continue
        }
        if ($line.StartsWith($EndMarker))   { $skip = $false; continue }
        if (-not $skip) { $kept.Add($line) }
    }
    return $kept.ToArray()
}

function Get-ConfigNewline([string]$path) {
    # Kimi writes config.toml from Node, so the file may well be LF even on
    # Windows. Rewriting it wholesale in CRLF would touch every line, so keep
    # whatever the file already uses.
    if (Test-Path $path) {
        $raw = [System.IO.File]::ReadAllText($path)
        if ($raw.Contains("`r`n")) { return "`r`n" }
        if ($raw.Contains("`n"))   { return "`n" }
    }
    return [Environment]::NewLine
}

function Write-ConfigLines([string]$path, [string[]]$lines, [string]$newline) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    # No lines means the config held nothing but our block: leave it empty
    # rather than writing a lone newline into it.
    $text = if ($lines.Count -gt 0) { ($lines -join $newline) + $newline } else { "" }
    [System.IO.File]::WriteAllText($path, $text, $utf8NoBom)
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
    Write-Host "Usage: powershell -NoProfile -File kimi.ps1 [-Install|-Uninstall|-Status]"
    Write-Host ""
    Write-Host "  -Install     Register peon-ping hooks in $KimiConfig"
    Write-Host "  -Uninstall   Remove them"
    Write-Host "  -Status      Report whether they are registered"
    Write-Host "  (no args)    Hook mode: read one Kimi event as JSON on stdin and forward it"
    exit 0
}

if ($Status) {
    if ((Test-Path $KimiConfig) -and (Select-String -LiteralPath $KimiConfig -SimpleMatch $BeginMarker -Quiet)) {
        $count = 0
        $inBlock = $false
        foreach ($line in (Get-Content -LiteralPath $KimiConfig)) {
            if ($line.StartsWith($BeginMarker)) { $inBlock = $true; continue }
            if ($line.StartsWith($EndMarker))   { $inBlock = $false; continue }
            if ($inBlock -and $line.StartsWith("event = ")) { $count++ }
        }
        Write-Host "peon-ping hooks registered in $KimiConfig ($count events)"
        exit 0
    }
    Write-Host "peon-ping hooks not registered in $KimiConfig"
    exit 1
}

if ($Uninstall) {
    if (-not (Test-Path $KimiConfig)) {
        Write-Host "Nothing to remove ($KimiConfig does not exist)."
        exit 0
    }
    if (-not (Select-String -LiteralPath $KimiConfig -SimpleMatch $BeginMarker -Quiet)) {
        Write-Host "Nothing to remove (no peon-ping block found)."
        exit 0
    }
    $nl = Get-ConfigNewline $KimiConfig
    Write-ConfigLines $KimiConfig (Get-StrippedConfig $KimiConfig) $nl
    Write-Host "Removed peon-ping hooks from $KimiConfig"
    exit 0
}

if ($Install) {
    if (-not (Test-Path $PeonScript)) {
        # $ErrorActionPreference is SilentlyContinue for hook mode, which would
        # swallow Write-Error, so report the failure on the host stream.
        Write-Host "peon.ps1 not found at $PeonScript" -ForegroundColor Red
        exit 1
    }
    if (-not (Test-Path $KimiDir)) { New-Item -ItemType Directory -Path $KimiDir -Force | Out-Null }

    $adapterPath = $MyInvocation.MyCommand.Path
    if (-not $adapterPath) { $adapterPath = Join-Path $PeonDir "adapters\kimi.ps1" }

    $nl = Get-ConfigNewline $KimiConfig

    # Rewriting from scratch keeps -Install idempotent.
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in (Get-StrippedConfig $KimiConfig)) { $lines.Add($line) }

    # Kimi spawns the hook with Node's `shell: true`, which on Windows means
    # `cmd.exe /d /s /c "<command>"`. cmd splits on spaces, so the adapter path
    # has to carry its own quotes or an install under "C:\Users\First Last\..."
    # never starts.
    $command = "powershell -NoProfile -NonInteractive -File `"$adapterPath`""

    $lines.Add("")
    $lines.Add($BeginMarker)
    $lines.Add("# install_dir = $PeonDir")
    foreach ($ev in $HookEvents) {
        $lines.Add("")
        $lines.Add("[[hooks]]")
        $lines.Add("event = `"$ev`"")
        $lines.Add("command = $(ConvertTo-TomlString $command)")
        $lines.Add("timeout = 10")
    }
    $lines.Add("")
    $lines.Add($EndMarker)

    Write-ConfigLines $KimiConfig $lines.ToArray() $nl

    Write-Host "peon-ping hooks registered for Kimi Code"
    Write-Host "  config:  $KimiConfig"
    Write-Host "  adapter: $adapterPath"
    Write-Host "  events:  $($HookEvents -join ' ')"
    Write-Host ""
    Write-Host "Run 'kimi doctor' to validate, then restart Kimi Code."
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

# stdout is swallowed: Kimi parses a hook's stdout as a decision document.
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null | Out-Null

exit 0
