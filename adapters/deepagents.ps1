# peon-ping adapter for deepagents-cli (Windows)
# Translates deepagents hook events into peon.ps1 stdin JSON
#
# deepagents-cli pipes JSON with an "event" field (dotted names like
# "session.start") and an optional "thread_id".  This adapter remaps
# to Claude Code PascalCase event names and forwards to peon.ps1.
#
# Setup: Add to ~/.deepagents/hooks.json:
#   {
#     "hooks": [
#       {
#         "command": ["powershell", "-NoProfile", "-File", "C:\\Users\\YOU\\.claude\\hooks\\peon-ping\\adapters\\deepagents.ps1"],
#         "events": ["session.start", "session.end", "task.complete", "input.required", "task.error", "tool.error", "user.prompt", "permission.request", "compact"]
#       }
#     ]
#   }
#
# Note: tool.call is intentionally excluded — it fires on every tool
# invocation and would be extremely noisy.

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Read JSON payload from stdin (sent by deepagents hooks.py)
$parsed = $null
try {
    if ([Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
        $reader.Close()
        if ($raw) { $parsed = $raw | ConvertFrom-Json }
    }
} catch { if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [deepagents] ConvertFrom-Json failed: $_" } }
if (-not $parsed) { exit 0 }

$daEvent = $parsed.event
if (-not $daEvent) { exit 0 }

# Map deepagents event to CESP event name
$mapped = $null
$ntype = ""

switch ($daEvent) {
    "session.start" {
        $mapped = "SessionStart"
    }
    "session.end" {
        $mapped = "SessionEnd"
    }
    "task.complete" {
        $mapped = "Stop"
    }
    "input.required" {
        $mapped = "Notification"
        $ntype = "permission_prompt"
    }
    "task.error" {
        $mapped = "Stop"
    }
    "tool.error" {
        $mapped = "Notification"
        $ntype = "postToolUseFailure"
    }
    "user.prompt" {
        $mapped = "UserPromptSubmit"
    }
    "permission.request" {
        $mapped = "PermissionRequest"
    }
    "compact" {
        $mapped = "Notification"
        $ntype = "preCompact"
    }
    "tool.call" {
        # Too noisy - skip
        exit 0
    }
    default {
        exit 0
    }
}

$threadId = $parsed.thread_id
$sessionId = "deepagents-$PID"
if ($threadId) { $sessionId = "deepagents-$threadId" }

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
