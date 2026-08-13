# peon-ping adapter for Grok Build (Windows)
# Translates Grok Build hook events into peon.ps1 stdin JSON.
#
# Grok sends camelCase stdin (hookEventName, sessionId, notificationType)
# with snake_case event values (session_start, stop, notification).
#
# Setup: re-run install.ps1 after Grok Build creates ~/.grok, or point
#   Grok's hooks at this script.

$ErrorActionPreference = "SilentlyContinue"

$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

$inputJson = $null
try {
    if ([Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
        $reader.Close()
        if ($raw) { $inputJson = $raw | ConvertFrom-Json }
    }
} catch { if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [grok] ConvertFrom-Json failed: $_" } }

function Get-Field($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    return $obj.PSObject.Properties[$name].Value
}

function First-NonEmpty {
    foreach ($value in $args) {
        if ($null -eq $value) { continue }
        $text = "$value".Trim()
        if ($text) { return $text }
    }
    return ""
}

$rawEvent = First-NonEmpty $env:GROK_HOOK_EVENT (Get-Field $inputJson "hookEventName") (Get-Field $inputJson "hook_event_name") (Get-Field $inputJson "event")
$eventKey = $rawEvent.ToString().Trim().ToLower().Replace("-", "_")
$notifType = (First-NonEmpty (Get-Field $inputJson "notificationType") (Get-Field $inputJson "notification_type") (Get-Field $inputJson "type")).ToLower()
$reason = (First-NonEmpty (Get-Field $inputJson "reason") (Get-Field $inputJson "stopReason") (Get-Field $inputJson "stop_reason")).ToLower()

if ($eventKey -in @(
    "pre_tool_use", "pretooluse",
    "post_tool_use", "posttooluse",
    "post_compact", "postcompact",
    "permission_denied", "permissiondenied"
)) {
    exit 0
}

$mapped = $null
$ntype = ""

if ($eventKey -in @("session_start", "sessionstart")) {
    $mapped = "SessionStart"
} elseif ($eventKey -in @("session_end", "sessionend")) {
    $mapped = "SessionEnd"
} elseif ($eventKey -in @("user_prompt_submit", "userpromptsubmit")) {
    $mapped = "UserPromptSubmit"
} elseif ($eventKey -in @("subagent_start", "subagentstart")) {
    $mapped = "SubagentStart"
} elseif ($eventKey -in @("subagent_stop", "subagentstop", "subagent_end", "subagentend")) {
    $mapped = "SubagentStop"
} elseif ($eventKey -in @("pre_compact", "precompact")) {
    $mapped = "PreCompact"
} elseif ($eventKey -in @("post_tool_use_failure", "posttoolusefailure", "stop_failure", "stopfailure")) {
    $mapped = "PostToolUseFailure"
} elseif ($eventKey -eq "notification") {
    if ($notifType -in @("permission_prompt", "permission", "approval_required")) {
        $mapped = "PermissionRequest"
        $ntype = "permission_prompt"
    } elseif ($notifType -in @("idle_prompt", "idle")) {
        $mapped = "Notification"
        $ntype = "idle_prompt"
    } elseif ($notifType -in @("elicitation_dialog", "elicitation", "question")) {
        $mapped = "Notification"
        $ntype = "elicitation_dialog"
    } else {
        exit 0
    }
} elseif ($eventKey -eq "stop") {
    if ($reason -in @("channel_closed", "shutdown")) {
        $mapped = "SessionEnd"
    } elseif ($reason -and $reason -ne "end_turn") {
        exit 0
    } else {
        $mapped = "Stop"
    }
} else {
    exit 0
}

$rawSid = First-NonEmpty (Get-Field $inputJson "sessionId") (Get-Field $inputJson "session_id") $env:GROK_SESSION_ID "$PID"
$safeSid = ($rawSid -replace '[^A-Za-z0-9._:-]', '-').Trim('-')
if (-not $safeSid) { $safeSid = "$PID" }
$sessionId = if ($safeSid.StartsWith("grok-")) { $safeSid } else { "grok-$safeSid" }

$cwd = First-NonEmpty (Get-Field $inputJson "cwd") (Get-Field $inputJson "workspaceRoot") (Get-Field $inputJson "workspace_root") $env:GROK_WORKSPACE_ROOT $PWD.Path

$payload = @{
    hook_event_name   = $mapped
    notification_type = $ntype
    cwd               = $cwd
    session_id        = $sessionId
    permission_mode   = (First-NonEmpty (Get-Field $inputJson "permissionMode") (Get-Field $inputJson "permission_mode"))
    source            = "grok"
}

$agentId = First-NonEmpty (Get-Field $inputJson "agentId") (Get-Field $inputJson "agent_id") (Get-Field $inputJson "subagentId") (Get-Field $inputJson "subagent_id")
if ($agentId) { $payload["agent_id"] = $agentId }

$agentType = First-NonEmpty (Get-Field $inputJson "agentType") (Get-Field $inputJson "agent_type") (Get-Field $inputJson "subagentType") (Get-Field $inputJson "subagent_type")
if ($agentType) { $payload["agent_type"] = $agentType }

$summary = First-NonEmpty (Get-Field $inputJson "lastAssistantMessage") (Get-Field $inputJson "last_assistant_message") (Get-Field $inputJson "transcript_summary") (Get-Field $inputJson "summary")
if ($summary) {
    $payload["last_assistant_message"] = $summary
    $payload["transcript_summary"] = $summary
}

if ($mapped -eq "PostToolUseFailure") {
    $tn = First-NonEmpty (Get-Field $inputJson "toolName") (Get-Field $inputJson "tool_name") (Get-Field $inputJson "tool")
    $shellTools = @("bash", "run_terminal_command", "shell")
    if ((-not $tn) -or ($tn.ToLower() -in $shellTools) -or ($eventKey -in @("stop_failure", "stopfailure"))) {
        $payload["tool_name"] = "Bash"
    } else {
        $payload["tool_name"] = $tn
    }
    $err = First-NonEmpty (Get-Field $inputJson "errorDetails") (Get-Field $inputJson "error_details") (Get-Field $inputJson "error") (Get-Field $inputJson "message") $summary
    if (-not $err) { $err = "Grok event: $rawEvent" }
    $payload["error"] = $err
}

$payloadJson = $payload | ConvertTo-Json -Compress

# Discard peon.ps1 stdout so a Stop gate can never parse a chime as a decision.
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript >$null 2>$null

exit 0
