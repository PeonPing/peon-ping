# peon-ping adapter for OpenClaw gateway agents (Windows)
# Translates OpenClaw events into peon.ps1 stdin JSON
#
# Setup: Add play.ps1 to your OpenClaw skill, or call this adapter directly:
#   powershell -NoProfile -File adapters/openclaw.ps1 task.complete
#
# Core events:
#   session.start    -- Agent session started
#   task.complete    -- Agent finished a task
#   task.error       -- Agent encountered an error
#   input.required   -- Agent needs user input
#   task.acknowledge -- Agent acknowledged a task
#   resource.limit   -- Rate limit / token quota / fallback triggered
#
# Extended events:
#   user.spam        -- Too many rapid prompts
#   session.end      -- Agent session closed / disconnected
#   task.progress    -- Long-running task still in progress
#
# Or use Claude Code hook event names:
#   SessionStart, Stop, Notification, UserPromptSubmit

param(
    [string]$Event = "task.complete"
)

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

if (-not (Test-Path $PeonDir)) {
    $PeonDir = Join-Path $env:USERPROFILE ".openpeon"
}

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) {
    Write-Host "peon-ping not installed. Run: powershell -File install.ps1" -ForegroundColor Red
    exit 1
}

# Map OpenClaw event names to peon.ps1 hook events
$mapped = $null
$ntype = ""

switch -Wildcard ($Event) {
    # Core CESP categories
    { $_ -in "session.start", "greeting", "ready", "heartbeat.first" } {
        $mapped = "SessionStart"
    }
    { $_ -in "task.complete", "complete", "done", "deployed", "merged" } {
        $mapped = "Stop"
    }
    { $_ -in "task.acknowledge", "acknowledge", "ack", "building", "working" } {
        $mapped = "UserPromptSubmit"
    }
    { $_ -in "task.error", "error", "fail", "crash", "build.failed" } {
        $mapped = "PostToolUseFailure"
    }
    { $_ -in "input.required", "permission", "input", "waiting", "blocked", "approval" } {
        $mapped = "Notification"
        $ntype = "permission_prompt"
    }
    { $_ -in "resource.limit", "ratelimit", "rate.limit", "quota", "fallback", "throttled", "token.limit" } {
        $mapped = "Notification"
        $ntype = "resource_limit"
    }

    # Extended CESP categories
    { $_ -in "user.spam", "annoyed", "spam" } {
        $mapped = "UserPromptSubmit"
    }
    { $_ -in "session.end", "disconnect", "shutdown", "goodbye" } {
        $mapped = "Stop"
    }
    { $_ -in "task.progress", "progress", "running", "backfill", "syncing" } {
        $mapped = "Notification"
        $ntype = "progress"
    }

    # Also accept raw Claude Code hook event names
    { $_ -in "SessionStart", "Stop", "Notification", "UserPromptSubmit", "PermissionRequest", "PostToolUseFailure", "SubagentStart", "SessionEnd" } {
        $mapped = $Event
    }

    default {
        $mapped = "Stop"
    }
}

$sessionId = "openclaw-$PID"
if ($env:OPENCLAW_SESSION_ID) { $sessionId = "openclaw-$($env:OPENCLAW_SESSION_ID)" }

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
