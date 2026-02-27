# peon-ping adapter for Kiro CLI (Amazon) (Windows)
# Translates Kiro hook events into peon.ps1 stdin JSON
#
# Kiro CLI has a hook system that pipes JSON to hooks via stdin,
# nearly identical to Claude Code. This adapter remaps the few
# differing event names and forwards to peon.ps1.
#
# Setup: Create ~/.kiro/agents/peon-ping.json with:
#   {
#     "hooks": {
#       "agentSpawn": [
#         { "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\kiro.ps1" }
#       ],
#       "userPromptSubmit": [
#         { "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\kiro.ps1" }
#       ],
#       "stop": [
#         { "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\kiro.ps1" }
#       ]
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
} catch {}
if (-not $inputJson) { exit 0 }

$hookEvent = $inputJson.hook_event_name
if (-not $hookEvent) { exit 0 }

# Kiro uses camelCase events; peon.ps1 expects PascalCase (Claude Code format)
$remap = @{
    "agentSpawn"       = "SessionStart"
    "userPromptSubmit" = "UserPromptSubmit"
    "stop"             = "Stop"
}

$mapped = $remap[$hookEvent]
if (-not $mapped) {
    # Unknown or intentionally skipped events (preToolUse, postToolUse)
    exit 0
}

$sid = if ($inputJson.session_id) { $inputJson.session_id } else { "$PID" }
$cwd = if ($inputJson.cwd) { $inputJson.cwd } else { $PWD.Path }

# Build CESP JSON payload
$payload = @{
    hook_event_name   = $mapped
    notification_type = ""
    cwd               = $cwd
    session_id        = "kiro-$sid"
    permission_mode   = if ($inputJson.permission_mode) { $inputJson.permission_mode } else { "" }
} | ConvertTo-Json -Compress

# Pipe to peon.ps1
$payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
