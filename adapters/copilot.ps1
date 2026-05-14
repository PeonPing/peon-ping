# peon-ping adapter for GitHub Copilot CLI (Windows)
# Translates GitHub Copilot CLI hook events into peon.ps1 stdin JSON.
#
# This adapter is mainly for users wiring per-repository hooks via
# .github/hooks/hooks.json. For user-level (global) wiring, install.ps1
# now writes ~/.copilot/hooks/peon-ping.json directly with PascalCase
# event names that peon.ps1 reads natively (no adapter required).
#
# Setup (per-repo): see README "GitHub Copilot CLI setup" for the full hook list.

param(
    [string]$Event = "sessionStart"
)

$ErrorActionPreference = "SilentlyContinue"

# Determine peon-ping install directory
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Map Copilot CLI camelCase events to peon.ps1 PascalCase events.
# Notes:
# - postToolUse intentionally has no mapping: peon.ps1 has no PostToolUse
#   handler, and naively forwarding it as Stop floods the 5s debounce
#   window and swallows real Stop events.
# - agentStop is the correct "task done" signal (Copilot CLI only).
# - errorOccurred is a generic Copilot CLI error; mapped to
#   PostToolUseFailure for parity with Claude Code semantics.
$eventMap = @{
    sessionStart        = "SessionStart"
    sessionEnd          = "SessionEnd"
    userPromptSubmitted = "UserPromptSubmit"
    preToolUse          = "PreToolUse"
    postToolUseFailure  = "PostToolUseFailure"
    agentStop           = "Stop"
    subagentStart       = "SubagentStart"
    subagentStop        = "SubagentStop"
    notification        = "Notification"
    permissionRequest   = "PermissionRequest"
    preCompact          = "PreCompact"
    errorOccurred       = "PostToolUseFailure"
}

if (-not $eventMap.ContainsKey($Event)) {
    # Unknown or intentionally skipped (e.g. postToolUse) — exit silently.
    exit 0
}

$mapped = $eventMap[$Event]

# Read JSON from stdin (camelCase from Copilot CLI; may be empty)
$inputJson = $null
try {
    if ([Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
        $reader.Close()
        if ($raw) { $inputJson = $raw | ConvertFrom-Json }
    }
} catch {
    if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [copilot] ConvertFrom-Json failed: $_" }
}
if (-not $inputJson) { $inputJson = [PSCustomObject]@{} }

# Common fields (every event has these)
$sessionId = if ($inputJson.sessionId) { [string]$inputJson.sessionId } else { "copilot-$PID" }
$cwd = if ($inputJson.cwd) { [string]$inputJson.cwd } else { $PWD.Path }

$payload = [ordered]@{
    hook_event_name = $mapped
    session_id      = $sessionId
    cwd             = $cwd
    source          = "copilot"
}

# Event-specific field translation (camelCase -> snake_case)
switch ($mapped) {
    "SessionStart" {
        if ($inputJson.source) { $payload.source = [string]$inputJson.source }
        if ($inputJson.initialPrompt) { $payload.initial_prompt = [string]$inputJson.initialPrompt }
    }
    "SessionEnd" {
        if ($inputJson.reason) { $payload.reason = [string]$inputJson.reason }
    }
    "UserPromptSubmit" {
        if ($inputJson.prompt) { $payload.prompt = [string]$inputJson.prompt }
    }
    "PreToolUse" {
        if ($inputJson.toolName) { $payload.tool_name = [string]$inputJson.toolName }
        if ($null -ne $inputJson.toolArgs) { $payload.tool_input = $inputJson.toolArgs }
    }
    "PostToolUseFailure" {
        $payload.tool_name = if ($inputJson.toolName) { [string]$inputJson.toolName } else { "unknown" }
        if ($null -ne $inputJson.toolArgs) { $payload.tool_input = $inputJson.toolArgs }
        $payload.error = if ($inputJson.error) { [string]$inputJson.error } else { "errorOccurred" }
    }
    "Stop" {
        if ($inputJson.transcriptPath) { $payload.transcript_path = [string]$inputJson.transcriptPath }
        if ($inputJson.stopReason) { $payload.stop_reason = [string]$inputJson.stopReason }
    }
    "SubagentStart" {
        if ($inputJson.transcriptPath) { $payload.transcript_path = [string]$inputJson.transcriptPath }
        if ($inputJson.agentName) { $payload.agent_name = [string]$inputJson.agentName }
    }
    "SubagentStop" {
        if ($inputJson.transcriptPath) { $payload.transcript_path = [string]$inputJson.transcriptPath }
    }
    "Notification" {
        if ($inputJson.notificationType) { $payload.notification_type = [string]$inputJson.notificationType }
        if ($inputJson.message) { $payload.message = [string]$inputJson.message }
    }
    "PermissionRequest" {
        if ($inputJson.toolName) { $payload.tool_name = [string]$inputJson.toolName }
        if ($null -ne $inputJson.toolArgs) { $payload.tool_input = $inputJson.toolArgs }
    }
    "PreCompact" {
        if ($inputJson.trigger) { $payload.trigger = [string]$inputJson.trigger }
    }
}

$payloadJson = $payload | ConvertTo-Json -Compress -Depth 10

# Pipe to peon.ps1
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
