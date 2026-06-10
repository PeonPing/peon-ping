# peon-ping adapter for OpenAI Codex CLI (Windows)
# Translates Codex events into peon.ps1 stdin JSON.
#
# Codex now ships a stable hook event set (SessionStart, UserPromptSubmit,
# PreToolUse, PostToolUse, Stop) delivered as JSON on stdin with a
# `hook_event_name` field. This adapter maps those to CESP, AND preserves the
# legacy `notify` callback (event name passed as argv, fires on turn-yield)
# as a non-breaking fallback.
#
# Setup (recommended — stable hooks): add Codex hooks pointing at this script,
#   e.g. in ~/.codex/config.toml:
#     [hooks]
#     SessionStart = "powershell -NoProfile -File C:\\Users\\YOU\\.claude\\hooks\\peon-ping\\adapters\\codex.ps1"
#     PostToolUse  = "powershell -NoProfile -File C:\\Users\\YOU\\.claude\\hooks\\peon-ping\\adapters\\codex.ps1"
#     Stop         = "powershell -NoProfile -File C:\\Users\\YOU\\.claude\\hooks\\peon-ping\\adapters\\codex.ps1"
#   (Consult `codex` docs for the exact hooks config for your version.)
#
# Setup (legacy — still supported): notify = ["powershell", "-NoProfile", "-File", "...codex.ps1"]

param(
    [string]$Event = ""
)

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Read stdin JSON only on the stable-hooks path. When an event name is passed
# as argv (the legacy `notify` callback), we must NOT touch stdin: in that mode
# the inherited stdin handle can be redirected-but-open (no EOF), and
# ReadToEnd() would block forever. The argv event alone drives legacy calls.
$inputJson = $null
try {
    if ((-not $Event) -and [Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
        $reader.Close()
        if ($raw) { $inputJson = $raw | ConvertFrom-Json }
    }
} catch { if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [codex] ConvertFrom-Json failed: $_" } }

function Get-Field($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    return $obj.PSObject.Properties[$name].Value
}

# Determine the raw event: argv first (legacy notify), then stdin fields.
$rawEvent = $Event
if (-not $rawEvent) { $rawEvent = "$(Get-Field $inputJson 'hook_event_name')" }
if (-not $rawEvent) { $rawEvent = "$(Get-Field $inputJson 'event')" }
if (-not $rawEvent) { $rawEvent = "$(Get-Field $inputJson 'type')" }
if (-not $rawEvent) { $rawEvent = "agent-turn-complete" }

$eventKey = $rawEvent.ToString().Trim().ToLower().Replace("_", "-")
$notifType = "$(Get-Field $inputJson 'notification_type')".Trim().ToLower()

function Test-ToolFailure {
    if (Get-Field $inputJson 'error') { return $true }
    $tr = Get-Field $inputJson 'tool_response'
    if ($tr) {
        if ((Get-Field $tr 'error') -or (Get-Field $tr 'is_error') -or (Get-Field $tr 'isError')) { return $true }
        $ec = Get-Field $tr 'exit_code'; if ($null -eq $ec) { $ec = Get-Field $tr 'exitCode' }
        if ($null -ne $ec) { try { if ([int]$ec -ne 0) { return $true } } catch {} }
    }
    $ec2 = Get-Field $inputJson 'exit_code'; if ($null -eq $ec2) { $ec2 = Get-Field $inputJson 'exitCode' }
    if ($null -ne $ec2) { try { if ([int]$ec2 -ne 0) { return $true } } catch {} }
    if ("$(Get-Field $inputJson 'success')".ToLower() -eq "false") { return $true }
    return $false
}

$mapped = $null
$ntype = $notifType

if ($eventKey.StartsWith("permission") -or $eventKey.StartsWith("approve") -or
    $eventKey -in @("approval-requested", "approval-needed", "input-required") -or
    $notifType -eq "permission_prompt") {
    $mapped = "Notification"; $ntype = "permission_prompt"
} elseif ($eventKey -in @("start", "session-start", "sessionstart")) {
    $mapped = "SessionStart"
} elseif ($eventKey -in @("sessionend", "session-end")) {
    $mapped = "SessionEnd"
} elseif ($eventKey -in @("userpromptsubmit", "user-prompt-submit")) {
    $mapped = "UserPromptSubmit"
} elseif ($eventKey -eq "idle-prompt") {
    $mapped = "Notification"; $ntype = "idle_prompt"
} elseif ($eventKey -in @("pretooluse", "pre-tool-use")) {
    exit 0   # fires before every tool — too noisy
} elseif ($eventKey -in @("posttooluse", "post-tool-use")) {
    if (Test-ToolFailure) { $mapped = "PostToolUseFailure" } else { exit 0 }
} elseif ($eventKey.StartsWith("error") -or $eventKey.StartsWith("fail")) {
    $mapped = "PostToolUseFailure"
} elseif ($eventKey -in @("stop", "agent-turn-complete", "turn-complete", "complete", "done")) {
    $mapped = "Stop"
} else {
    $mapped = "Stop"   # preserve legacy notify default
}

# Session id (codex- prefix), sanitised.
$rawSid = "$(Get-Field $inputJson 'session_id')"
if (-not $rawSid) { $rawSid = "$(Get-Field $inputJson 'conversation_id')" }
if (-not $rawSid) { $rawSid = "$(Get-Field $inputJson 'thread_id')" }
if (-not $rawSid -and $env:CODEX_SESSION_ID) { $rawSid = $env:CODEX_SESSION_ID }
if (-not $rawSid) { $rawSid = "$PID" }
$safeSid = ($rawSid -replace '[^A-Za-z0-9._:-]', '-').Trim('-')
if (-not $safeSid) { $safeSid = "$PID" }

$cwd = "$(Get-Field $inputJson 'cwd')"
if (-not $cwd) { $cwd = "$(Get-Field $inputJson 'workspace_root')" }
if (-not $cwd) { $cwd = $PWD.Path }

$payload = @{
    hook_event_name   = $mapped
    notification_type = $ntype
    cwd               = $cwd
    session_id        = "codex-$safeSid"
    permission_mode   = "$(Get-Field $inputJson 'permission_mode')"
    source            = "codex"
}

if ($mapped -eq "PostToolUseFailure") {
    $tn = "$(Get-Field $inputJson 'tool_name')"
    if (-not $tn) { $tn = "$(Get-Field $inputJson 'tool')" }
    if (-not $tn) { $tn = "Bash" }
    $payload["tool_name"] = $tn
    $err = "$(Get-Field $inputJson 'error')"
    if (-not $err) { $err = "$(Get-Field $inputJson 'message')" }
    if (-not $err) { $err = "Codex event: $rawEvent" }
    $payload["error"] = $err
}

$payloadJson = $payload | ConvertTo-Json -Compress

# Pipe to peon.ps1
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
