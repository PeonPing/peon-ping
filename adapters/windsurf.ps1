# peon-ping adapter for Windsurf IDE (Windows)
# Translates Windsurf Cascade hook events into peon.ps1 stdin JSON
#
# Setup: Add to ~/.codeium/windsurf/hooks.json:
#   {
#     "hooks": {
#       "post_cascade_response": [
#         { "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\windsurf.ps1 post_cascade_response", "show_output": false }
#       ],
#       "pre_user_prompt": [
#         { "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\windsurf.ps1 pre_user_prompt", "show_output": false }
#       ]
#     }
#   }

param(
    [string]$Event = "post_cascade_response"
)

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Drain stdin (Windsurf sends context we don't need)
try {
    if ([Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $null = $reader.ReadToEnd()
        $reader.Close()
    }
} catch {}

# Map Windsurf hook events to peon.ps1 PascalCase events
$mapped = $null
$parentPid = if ($env:PPID) { $env:PPID } else { $PID }

switch ($Event) {
    "post_cascade_response" {
        $mapped = "Stop"
    }
    "pre_user_prompt" {
        # First prompt → SessionStart (greeting); subsequent → UserPromptSubmit (spam detection)
        $markerFile = Join-Path $PeonDir ".windsurf-session-$parentPid"

        # Clean up old markers (>24h)
        Get-ChildItem -Path $PeonDir -Filter ".windsurf-session-*" -File 2>$null | Where-Object {
            $_.LastWriteTime -lt (Get-Date).AddDays(-1)
        } | Remove-Item -Force 2>$null

        if (-not (Test-Path $markerFile)) {
            New-Item -ItemType File -Path $markerFile -Force | Out-Null
            $mapped = "SessionStart"
        } else {
            $mapped = "UserPromptSubmit"
        }
    }
    "post_write_code" {
        $mapped = "Stop"
    }
    "post_run_command" {
        $mapped = "Stop"
    }
    default {
        # Unknown event — skip
        exit 0
    }
}

$sessionId = "windsurf-$PID"

# Build CESP JSON payload
$payload = @{
    hook_event_name   = $mapped
    notification_type = ""
    cwd               = $PWD.Path
    session_id        = $sessionId
    permission_mode   = ""
} | ConvertTo-Json -Compress

# Pipe to peon.ps1
$payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
