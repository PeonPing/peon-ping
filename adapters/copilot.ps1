# peon-ping adapter for GitHub Copilot (Windows)
# Translates GitHub Copilot hook events into peon.ps1 stdin JSON
#
# Setup: Add to .github/hooks/hooks.json in your repository:
#   {
#     "version": 1,
#     "hooks": {
#       "sessionStart": [
#         { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\copilot.ps1 sessionStart" }
#       ],
#       "userPromptSubmitted": [
#         { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\copilot.ps1 userPromptSubmitted" }
#       ],
#       "postToolUse": [
#         { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\copilot.ps1 postToolUse" }
#       ],
#       "errorOccurred": [
#         { "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\copilot.ps1 errorOccurred" }
#       ]
#     }
#   }

param(
    [string]$Event = "sessionStart"
)

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
} catch {}
if (-not $inputJson) { $inputJson = [PSCustomObject]@{} }

# Extract common fields
$sessionId = if ($inputJson.sessionId) { $inputJson.sessionId } else { "copilot-$PID" }
$cwd = if ($inputJson.cwd) { $inputJson.cwd } else { $PWD.Path }

# Map Copilot hook events to peon.ps1 PascalCase events
$mapped = $null

switch ($Event) {
    "sessionStart" {
        $mapped = "SessionStart"
    }
    "sessionEnd" {
        # Session end — no sound
        exit 0
    }
    "userPromptSubmitted" {
        # First prompt → SessionStart (greeting); subsequent → UserPromptSubmit (spam detection)
        $markerFile = Join-Path $PeonDir ".copilot-session-$sessionId"

        # Clean up old markers (>24h)
        Get-ChildItem -Path $PeonDir -Filter ".copilot-session-*" -File 2>$null | Where-Object {
            $_.LastWriteTime -lt (Get-Date).AddDays(-1)
        } | Remove-Item -Force 2>$null

        if (-not (Test-Path $markerFile)) {
            New-Item -ItemType File -Path $markerFile -Force | Out-Null
            $mapped = "SessionStart"
        } else {
            $mapped = "UserPromptSubmit"
        }
    }
    "preToolUse" {
        # Before tool execution — skip (too noisy)
        exit 0
    }
    "postToolUse" {
        # After tool execution — treat as task completion
        $mapped = "Stop"
    }
    "errorOccurred" {
        # Error occurred during session
        $mapped = "PostToolUseFailure"
    }
    default {
        # Unknown event — skip
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
    $payload["error"] = "errorOccurred"
}

$payloadJson = $payload | ConvertTo-Json -Compress

# Pipe to peon.ps1
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
