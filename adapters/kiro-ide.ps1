# peon-ping adapter for Kiro IDE (Amazon) (Windows)
# Translates Kiro IDE agent-hook events into peon.ps1 stdin JSON.
#
# Kiro IDE is DISTINCT from the Kiro CLI (see adapters/kiro.ps1). The IDE's
# Agent Hooks are `.kiro/hooks/*.kiro.hook` JSON files; the `then.runCommand`
# action runs a command with NO stdin JSON — the event name is passed as argv.
#
# Setup: create one `.kiro/hooks/peon-ping-<event>.kiro.hook` per event, with
#   "then": { "type": "runCommand",
#     "command": "powershell -NoProfile -File %USERPROFILE%\\.claude\\hooks\\peon-ping\\adapters\\kiro-ide.ps1 agentStop" }
# Repeat with when.type = promptSubmit / preToolUse and a matching argv.

param(
    [string]$Event = "agentStop"
)

$ErrorActionPreference = "SilentlyContinue"

$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$PeonScript = Join-Path $PeonDir "peon.ps1"
if (-not (Test-Path $PeonScript)) { exit 0 }

# Map Kiro IDE when.type values (argv) to CESP. postToolUse / file* /
# userTriggered carry no peon-relevant signal, so they exit silently.
$mapped = $null
switch ($Event) {
    { $_ -in "agentStop", "stop" }                { $mapped = "Stop" }
    { $_ -in "promptSubmit", "userPromptSubmit" } { $mapped = "UserPromptSubmit" }
    { $_ -in "preToolUse", "on_tool_permission" } { $mapped = "PermissionRequest" }
    { $_ -in "sessionStart", "agentSpawn", "start" } { $mapped = "SessionStart" }
    default { exit 0 }
}

# Distinct kiro-ide- prefix from the CLI adapter's kiro-.
$sid = if ($env:KIRO_IDE_SESSION_ID) { $env:KIRO_IDE_SESSION_ID } else { "$PID" }

$payload = @{
    hook_event_name   = $mapped
    notification_type = ""
    cwd               = $PWD.Path
    session_id        = "kiro-ide-$sid"
    permission_mode   = ""
} | ConvertTo-Json -Compress

$payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null

exit 0
