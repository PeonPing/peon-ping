# peon-ping adapter for iFlow CLI (iflow-ai/iflow-cli) (Windows)
# Translates iFlow hook events into peon.ps1 stdin JSON.
#
# iFlow CLI ships a Claude-Code-style hook system: events are piped to the
# hook command as JSON on stdin using PascalCase names. This adapter forwards
# the meaningful lifecycle events with an `iflow-` session prefix, maps a
# failed PostToolUse to PostToolUseFailure, and drops the noisy rest.
#
# Setup: add to ~/.iflow/settings.json (each event below):
#   {
#     "hooks": {
#       "SessionStart":     [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\iflow.ps1" }] }],
#       "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\iflow.ps1" }] }],
#       "Stop":             [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\iflow.ps1" }] }],
#       "Notification":     [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\iflow.ps1" }] }],
#       "PostToolUse":      [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\iflow.ps1" }] }],
#       "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\iflow.ps1" }] }]
#     }
#   }

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Read JSON from stdin
$inputJson = $null
try {
    if ([Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
        $reader.Close()
        if ($raw) { $inputJson = $raw | ConvertFrom-Json }
    }
} catch { if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [iflow] ConvertFrom-Json failed: $_" } }
if (-not $inputJson) { exit 0 }

$hookEvent = "$($inputJson.hook_event_name)".Trim()
if (-not $hookEvent) { exit 0 }

# Pass these CESP PascalCase events straight through.
$passthrough = @("SessionStart", "UserPromptSubmit", "Stop", "Notification", "SessionEnd")

$mapped = $null
if ($passthrough -contains $hookEvent) {
    $mapped = $hookEvent
} elseif ($hookEvent -eq "PostToolUse") {
    # iFlow has no dedicated failure event; surface only failed tool calls.
    $failed = $false
    $ec = $inputJson.exit_code
    if ($null -eq $ec) { $ec = $inputJson.exitCode }
    if ($null -ne $ec) { try { if ([int]$ec -ne 0) { $failed = $true } } catch {} }
    if ("$($inputJson.success)".ToLower() -eq "false") { $failed = $true }
    if ($inputJson.error -or $inputJson.stderr) { $failed = $true }
    if (-not $failed) { exit 0 }
    $mapped = "PostToolUseFailure"
} else {
    exit 0
}

$sid = if ($inputJson.session_id) { $inputJson.session_id } else { "$PID" }
$cwd = if ($inputJson.cwd) { $inputJson.cwd } else { $PWD.Path }

$payload = @{
    hook_event_name   = $mapped
    notification_type = if ($inputJson.notification_type) { $inputJson.notification_type } else { "" }
    cwd               = $cwd
    session_id        = "iflow-$sid"
    permission_mode   = if ($inputJson.permission_mode) { $inputJson.permission_mode } else { "" }
}

if ($mapped -eq "PostToolUseFailure") {
    $payload["tool_name"] = if ($inputJson.tool_name) { $inputJson.tool_name } else { "Bash" }
    $payload["error"]     = if ($inputJson.error) { $inputJson.error }
                            elseif ($inputJson.stderr) { $inputJson.stderr }
                            else { "Tool failed" }
}

$payloadJson = $payload | ConvertTo-Json -Compress

# Pipe to peon.ps1
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
