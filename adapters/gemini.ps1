# peon-ping adapter for Gemini CLI (Windows)
# Translates Gemini CLI hook events into peon.ps1 stdin JSON
#
# Setup: Add to ~/.gemini/settings.json:
#   {
#     "hooks": {
#       "SessionStart": [{ "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1 SessionStart" }],
#       "AfterAgent":   [{ "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1 AfterAgent" }],
#       "AfterTool":    [{ "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1 AfterTool" }],
#       "Notification":  [{ "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\gemini.ps1 Notification" }]
#     }
#   }

param(
    [string]$EventType = "SessionStart"
)

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) {
    Write-Output "{}"
    exit 0
}

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
} catch {}
if (-not $inputJson) { $inputJson = [PSCustomObject]@{} }

# Extract common fields
$sessionId = if ($inputJson.session_id) { $inputJson.session_id } else { "gemini-$PID" }
$cwd = if ($inputJson.cwd) { $inputJson.cwd } else { $PWD.Path }

# Map Gemini event to CESP event name
$mapped = $null

switch ($EventType) {
    "SessionStart" {
        $mapped = "SessionStart"
    }
    "AfterAgent" {
        $mapped = "Stop"
    }
    "Notification" {
        $mapped = "Notification"
    }
    "AfterTool" {
        $exitCode = 0
        if ($inputJson.exit_code -ne $null) { $exitCode = [int]$inputJson.exit_code }
        if ($exitCode -ne 0) {
            $mapped = "PostToolUseFailure"
        } else {
            $mapped = "Stop"
        }
    }
    default {
        # Unknown event — return empty JSON
        Write-Output "{}"
        exit 0
    }
}

# Build CESP JSON payload
$payload = @{
    hook_event_name   = $mapped
    notification_type = ""
    cwd               = $cwd
    session_id        = $sessionId
    permission_mode   = ""
}

if ($mapped -eq "PostToolUseFailure") {
    $payload["tool_name"] = "Bash"
    $payload["error"] = if ($inputJson.stderr) { $inputJson.stderr } else { "Tool failed" }
}

$payloadJson = $payload | ConvertTo-Json -Compress

# Pipe to peon.ps1 (suppress its stdout)
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null | Out-Null

# Always return valid empty JSON to Gemini CLI
Write-Output "{}"

exit 0
