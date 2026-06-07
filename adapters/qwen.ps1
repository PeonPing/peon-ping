# peon-ping adapter for Qwen Code CLI (QwenLM/qwen-code) (Windows)
# Translates Qwen Code hook events into peon.ps1 stdin JSON.
#
# Qwen Code ships a Claude-Code-style hook system: events are piped to the
# hook command as JSON on stdin, and the event vocabulary already matches
# peon.ps1's PascalCase CESP names. This adapter re-tags the session id with
# a `qwen-` prefix, drops noisy per-tool-call events, and forwards the rest.
#
# Setup: add to ~/.qwen/settings.json (each event below):
#   {
#     "hooks": {
#       "SessionStart":       [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\qwen.ps1" }] }],
#       "UserPromptSubmit":   [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\qwen.ps1" }] }],
#       "Stop":               [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\qwen.ps1" }] }],
#       "Notification":       [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\qwen.ps1" }] }],
#       "PostToolUseFailure": [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\qwen.ps1" }] }],
#       "SessionEnd":         [{ "hooks": [{ "type": "command", "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\qwen.ps1" }] }]
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
} catch { if ($env:PEON_DEBUG -eq "1") { Write-Warning "peon-ping: [qwen] ConvertFrom-Json failed: $_" } }
if (-not $inputJson) { exit 0 }

$hookEvent = "$($inputJson.hook_event_name)".Trim()
if (-not $hookEvent) { exit 0 }

# Qwen emits PascalCase CESP events; forward an allowlist as-is and drop the
# noisy success-path tool events plus subagent/compaction chatter.
$allow = @(
    "SessionStart", "UserPromptSubmit", "Stop", "Notification",
    "PostToolUseFailure", "PermissionRequest", "SessionEnd"
)
if ($allow -notcontains $hookEvent) { exit 0 }

$sid = if ($inputJson.session_id) { $inputJson.session_id } else { "$PID" }
$cwd = if ($inputJson.cwd) { $inputJson.cwd } else { $PWD.Path }

# Build CESP JSON payload
$payload = @{
    hook_event_name   = $hookEvent
    notification_type = if ($inputJson.notification_type) { $inputJson.notification_type } else { "" }
    cwd               = $cwd
    session_id        = "qwen-$sid"
    permission_mode   = if ($inputJson.permission_mode) { $inputJson.permission_mode } else { "" }
}

if ($hookEvent -eq "PostToolUseFailure") {
    $payload["tool_name"] = if ($inputJson.tool_name) { $inputJson.tool_name } else { "Bash" }
    $payload["error"]     = if ($inputJson.error) { $inputJson.error }
                            elseif ($inputJson.stderr) { $inputJson.stderr }
                            else { "Tool failed" }
}

$payloadJson = $payload | ConvertTo-Json -Compress

# Pipe to peon.ps1
$payloadJson | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
