# peon-ping adapter for ECA (Editor Code Assistant, eca.dev) (Windows)
# Translates ECA hook events into peon.ps1 stdin JSON.
#
# ECA is an editor-agnostic LLM-agent integration. Its hooks pipe JSON on
# stdin and fire on sessionStart/sessionEnd/chatStart/chatEnd/preRequest/
# postRequest/subagentPostRequest/preToolCall/postToolCall. This adapter maps
# them to CESP with an `eca-` session prefix derived from the ECA
# db_cache_path. The hook type may arrive as argv and/or a stdin `type` field.
#
# Originally contributed in PeonPing/peon-ping#261; vendored first-party here
# with thanks to the original author.

param(
    [string]$Event = ""
)

$ErrorActionPreference = "SilentlyContinue"

$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Read stdin JSON
$inputJson = $null
try {
    if ([Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
        $reader.Close()
        if ($raw) { $inputJson = $raw | ConvertFrom-Json }
    }
} catch { if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [eca] ConvertFrom-Json failed: $_" } }

function Get-Field($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    return $obj.PSObject.Properties[$name].Value
}

# Hook type: argv first, then a stdin field.
$etype = $Event
if (-not $etype) { $etype = "$(Get-Field $inputJson 'type')" }
if (-not $etype) { $etype = "$(Get-Field $inputJson 'hook_type')" }
if (-not $etype) { $etype = "$(Get-Field $inputJson 'hook_event_name')" }
$etype = "$etype".Trim()

$typeMap = @{
    "sessionStart"        = "SessionStart"
    "sessionEnd"          = "SessionEnd"
    "chatStart"           = "SessionStart"
    "preRequest"          = "UserPromptSubmit"
    "postRequest"         = "Stop"
    "subagentPostRequest" = "Stop"
    "preToolCall"         = "PermissionRequest"
    "postToolCall"        = "Stop"
}
$mapped = $typeMap[$etype]
if (-not $mapped) { exit 0 }

# Stable session id from db_cache_path; else session_id; else PID.
$dbp = "$(Get-Field $inputJson 'db_cache_path')"
if (-not $dbp) { $dbp = "$(Get-Field $inputJson 'session_id')" }
if ($dbp) {
    $sid = ($dbp -replace '[^A-Za-z0-9._:-]', '-').Trim('-')
    if ($sid.Length -gt 60) { $sid = $sid.Substring($sid.Length - 60) }
} else {
    $sid = "$PID"
}
if (-not $sid) { $sid = "$PID" }

$cwd = "$(Get-Field $inputJson 'cwd')"
if (-not $cwd) { $cwd = "$(Get-Field $inputJson 'workspace_root')" }
if (-not $cwd) { $cwd = $PWD.Path }

$payload = @{
    hook_event_name   = $mapped
    notification_type = "$(Get-Field $inputJson 'notification_type')"
    cwd               = $cwd
    session_id        = "eca-$sid"
    permission_mode   = "$(Get-Field $inputJson 'permission_mode')"
} | ConvertTo-Json -Compress

$payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
