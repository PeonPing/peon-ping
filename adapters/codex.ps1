# peon-ping adapter for OpenAI Codex CLI (Windows)
# Translates Codex notify events into peon.ps1 stdin JSON
#
# Setup: Add to ~/.codex/config.toml:
#   notify = ["powershell", "-NoProfile", "-File", "C:\\Users\\YOU\\.claude\\hooks\\peon-ping\\adapters\\codex.ps1"]
#
# Or with CLAUDE_PEON_DIR override:
#   $env:CLAUDE_PEON_DIR = "C:\path\to\peon-ping"

param(
    [string]$Event = "agent-turn-complete"
)

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Map Codex event to CESP event name
$mapped = $null
$ntype = ""

switch -Wildcard ($Event) {
    { $_ -in "agent-turn-complete", "complete", "done" } {
        $mapped = "Stop"
    }
    { $_ -in "start", "session-start" } {
        $mapped = "SessionStart"
    }
    { $_ -in "error" -or $_ -like "fail*" } {
        $mapped = "Stop"
    }
    { $_ -like "permission*" -or $_ -like "approve*" } {
        $mapped = "Notification"
        $ntype = "permission_prompt"
    }
    default {
        $mapped = "Stop"
    }
}

$sessionId = "codex-$PID"
if ($env:CODEX_SESSION_ID) { $sessionId = "codex-$($env:CODEX_SESSION_ID)" }

# Build CESP JSON payload
$payload = @{
    hook_event_name   = $mapped
    notification_type = $ntype
    cwd               = $PWD.Path
    session_id        = $sessionId
    permission_mode   = ""
} | ConvertTo-Json -Compress

# Pipe to peon.ps1
$payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
