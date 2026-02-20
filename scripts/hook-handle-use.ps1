#!/usr/bin/env pwsh
# UserPromptSubmit hook for /peon-ping-use command
# Intercepts `/peon-ping-use <pack>` before it reaches the LLM
# CLI fallback: run with pack name as first arg, e.g. hook-handle-use.ps1 peasant

$ErrorActionPreference = 'Stop'

$LogFile = if ($env:CLAUDE_CONFIG_DIR) { "$env:CLAUDE_CONFIG_DIR/hooks/peon-ping/hook-handle-use.log" } else { "$env:USERPROFILE/.claude/hooks/peon-ping/hook-handle-use.log" }
$LogFallback = "$env:TEMP\peon-ping-hook.log"
function Write-Log {
    param($Msg)
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Msg"
    $line | Add-Content -Path $LogFile -ErrorAction SilentlyContinue
    if (-not (Test-Path $LogFile)) { $line | Add-Content -Path $LogFallback -ErrorAction SilentlyContinue }
}

# Helper function to output JSON response (hook mode)
function Write-Response {
    param($Continue, $Message = $null)
    $response = @{ continue = $Continue }
    if ($Message) { $response.user_message = $Message }
    $response | ConvertTo-Json -Compress
}

# CLI mode: pack name as first arg (manual fallback when hook doesn't run)
$packName = $null
$sessionId = "default"
$cliMode = $false

if ($args.Count -ge 1 -and $args[0]) {
    $packName = $args[0].Trim()
    $cliMode = $true
    Write-Log "cli_mode pack=$packName"
}

if (-not $cliMode) {
    # Hook mode: read JSON from stdin (StreamReader with UTF-8 auto-strips BOM on Windows)
    $stream = [Console]::OpenStandardInput()
    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
    $stdinJson = $reader.ReadToEnd()
    $reader.Close()
    Write-Log "invoked stdin_len=$($stdinJson.Length)"

    try {
        $data = $stdinJson | ConvertFrom-Json
    } catch {
        Write-Log "parse_error: $_"
        Write-Response -Continue $true
        exit 0
    }

    $sessionId = if ($data.conversation_id) { $data.conversation_id }
                 elseif ($data.session_id) { $data.session_id }
                 else { "default" }

    $prompt = $data.prompt
    if (-not $prompt) {
        Write-Log "passthrough: no_prompt"
        Write-Response -Continue $true
        exit 0
    }

    if ($prompt -notmatch '^\s*/peon-ping-use\s+(\S+)') {
        Write-Log "passthrough: not_our_cmd prompt_preview=$($prompt.Substring(0, [Math]::Min(80, $prompt.Length)))..."
        Write-Response -Continue $true
        exit 0
    }

    $packName = $matches[1]
    Write-Log "matched pack=$packName sessionId=$sessionId"
}

# Safe charset: letters, numbers, underscore, hyphen (prevents injection and path traversal)
if ($packName -notmatch '^[a-zA-Z0-9_-]+$') {
    Write-Log "reject: invalid pack name charset pack=$packName"
    if ($cliMode) { Write-Host "[X] Invalid pack name (use only letters, numbers, underscores, hyphens)"; exit 1 }
    Write-Response -Continue $false -Message "[X] Invalid pack name (use only letters, numbers, underscores, hyphens)"
    exit 0
}
if ($sessionId -notmatch '^[a-zA-Z0-9_-]+$') {
    Write-Log "sanitize: invalid session_id charset, using default"
    $sessionId = "default"
}

# Locate peon-ping installation
$peonDir = if ($env:CLAUDE_CONFIG_DIR) { 
    "$env:CLAUDE_CONFIG_DIR/hooks/peon-ping" 
} else { 
    "$env:USERPROFILE/.claude/hooks/peon-ping" 
}

if (-not (Test-Path $peonDir)) {
    # Try Cursor location
    $peonDir = "$env:USERPROFILE/.cursor/hooks/peon-ping"
}

if (-not (Test-Path $peonDir)) {
    Write-Log "error: peon-ping not installed"
    if ($cliMode) { Write-Host "[X] peon-ping not installed"; exit 1 }
    Write-Response -Continue $false -Message "[X] peon-ping not installed"
    exit 0
}

$configPath = Join-Path $peonDir "config.json"
$statePath = Join-Path $peonDir ".state.json"
$packsDir = Join-Path $peonDir "packs"

# Validate pack exists
$packPath = Join-Path $packsDir $packName
if (-not (Test-Path $packPath)) {
    Write-Log "error: pack not found pack=$packName"
    # List available packs
    $available = Get-ChildItem -Path $packsDir -Directory -ErrorAction SilentlyContinue | 
                 Select-Object -ExpandProperty Name
    
    if (-not $available) {
        Write-Response -Continue $false -Message "[X] No packs installed"
    } else {
        $packList = $available -join ', '
        Write-Response -Continue $false -Message "[X] Pack '$packName' not found`n`nAvailable packs: $packList"
    }
    exit 0
}

# When sessionId is "default" (Cursor without conversation_id), use session_packs["default"]
# so peon.sh will apply this pack for sessions without explicit assignment

# Update config.json
try {
    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
    } else {
        $config = @{}
    }
    
    # Set rotation mode to agentskill
    $config | Add-Member -NotePropertyName "pack_rotation_mode" -NotePropertyValue "agentskill" -Force
    
    # Ensure pack is in pack_rotation array
    $packRotation = if ($config.pack_rotation) { 
        @($config.pack_rotation) 
    } else { 
        @() 
    }
    
    if ($packRotation -notcontains $packName) {
        $packRotation += $packName
    }
    
    $config | Add-Member -NotePropertyName "pack_rotation" -NotePropertyValue $packRotation -Force
    
    # Write updated config
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -NoNewline
    Add-Content $configPath "`n"
    
} catch {
    Write-Response -Continue $false -Message "[X] Failed to update config: $_"
    exit 0
}

# Update .state.json
try {
    if (Test-Path $statePath) {
        $state = Get-Content $statePath -Raw | ConvertFrom-Json
    } else {
        $state = @{}
    }
    
    # Ensure session_packs exists
    if (-not $state.session_packs) {
        $state | Add-Member -NotePropertyName "session_packs" -NotePropertyValue @{} -Force
    }
    
    # Map this session to the requested pack (new dict format with timestamp)
    $packData = @{
        pack = $packName
        last_used = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    }
    
    $state.session_packs | Add-Member -NotePropertyName $sessionId -NotePropertyValue $packData -Force
    
    # Write updated state
    $state | ConvertTo-Json -Depth 10 | Set-Content $statePath -NoNewline
    Add-Content $statePath "`n"
    
} catch {
    Write-Response -Continue $false -Message "[X] Failed to update state: $_"
    exit 0
}

# Return success message and block LLM invocation
Write-Log "success pack=$packName sessionId=$sessionId"
Write-Response -Continue $false -Message "Voice set to $packName"
exit 0
