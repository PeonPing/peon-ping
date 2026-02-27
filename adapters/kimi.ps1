# peon-ping adapter for Kimi Code CLI (MoonshotAI) (Windows)
# Watches ~/.kimi/sessions/ for Wire Mode events (wire.jsonl)
# and translates them into peon.ps1 CESP events.
#
# Uses System.IO.FileSystemWatcher (native .NET) instead of fswatch/inotifywait.
#
# Usage:
#   powershell -NoProfile -File adapters/kimi.ps1              # foreground
#   powershell -NoProfile -File adapters/kimi.ps1 --install    # background daemon
#   powershell -NoProfile -File adapters/kimi.ps1 --uninstall  # stop daemon
#   powershell -NoProfile -File adapters/kimi.ps1 --status     # check daemon

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status,
    [switch]$Help
)

$ErrorActionPreference = "SilentlyContinue"

# --- Config ---
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$KimiDir = if ($env:KIMI_DIR) { $env:KIMI_DIR }
           else { Join-Path $env:USERPROFILE ".kimi" }

$SessionsDir = if ($env:KIMI_SESSIONS_DIR) { $env:KIMI_SESSIONS_DIR }
               else { Join-Path $KimiDir "sessions" }

$StopCooldown = if ($env:KIMI_STOP_COOLDOWN) { [int]$env:KIMI_STOP_COOLDOWN } else { 10 }
$ClearGraceSeconds = if ($env:KIMI_CLEAR_GRACE) { [int]$env:KIMI_CLEAR_GRACE } else { 5 }

$PidFile = Join-Path $PeonDir ".kimi-adapter.pid"
$LogFile = Join-Path $PeonDir ".kimi-adapter.log"

$PeonScript = Join-Path $PeonDir "peon.ps1"

# --- Help ---
if ($Help) {
    Write-Host "Usage: powershell -NoProfile -File kimi.ps1 [--install|--uninstall|--status]"
    Write-Host ""
    Write-Host "  --install       Start Kimi Code watcher as a background daemon"
    Write-Host "  --uninstall     Stop the background daemon"
    Write-Host "  --status        Check if the daemon is running"
    Write-Host "  (no args)       Run in foreground (Ctrl+C to stop)"
    exit 0
}

# --- Daemon management ---
if ($Uninstall) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($pid) {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                Stop-Process -Id $pid -Force
                Remove-Item $PidFile -Force
                Write-Host "peon-ping Kimi adapter stopped (PID $pid)"
            } else {
                Remove-Item $PidFile -Force
                Write-Host "peon-ping Kimi adapter was not running (stale PID file removed)"
            }
        }
    } else {
        Write-Host "peon-ping Kimi adapter is not running (no PID file)"
    }
    exit 0
}

if ($Status) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Kimi adapter is running (PID $pid)"
            exit 0
        } else {
            Remove-Item $PidFile -Force
            Write-Host "peon-ping Kimi adapter is not running (stale PID file removed)"
            exit 1
        }
    } else {
        Write-Host "peon-ping Kimi adapter is not running"
        exit 1
    }
}

if ($Install) {
    if (Test-Path $PidFile) {
        $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Kimi adapter already running (PID $oldPid)"
            exit 0
        }
        Remove-Item $PidFile -Force
    }

    $scriptPath = $MyInvocation.MyCommand.Path
    $proc = Start-Process -WindowStyle Hidden -FilePath "powershell" `
        -ArgumentList "-NoProfile", "-File", $scriptPath `
        -PassThru -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile
    Set-Content -Path $PidFile -Value $proc.Id
    Write-Host "peon-ping Kimi adapter started (PID $($proc.Id))"
    Write-Host "  Watching: $SessionsDir"
    Write-Host "  Log: $LogFile"
    Write-Host "  Stop: powershell -NoProfile -File $scriptPath -Uninstall"
    exit 0
}

# --- Preflight ---
if (-not (Test-Path $PeonScript)) {
    Write-Host "peon.ps1 not found at $PeonScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SessionsDir)) {
    Write-Host "Kimi sessions directory not found: $SessionsDir" -ForegroundColor Yellow
    Write-Host "Waiting for Kimi Code to create it..."
    while (-not (Test-Path $SessionsDir)) {
        Start-Sleep -Seconds 2
    }
    Write-Host "Sessions directory detected."
}

# --- State tracking ---
$sessionState = @{}      # uuid -> "new" or "active"
$sessionStopTime = @{}   # uuid -> epoch of last Stop emission
$sessionOffset = @{}     # uuid -> byte offset in wire.jsonl
$lastNewSession = $null  # @{ uuid = "..."; timestamp = epoch } for /clear detection

# Record existing session UUIDs and set offsets to end of file
Get-ChildItem -Path $SessionsDir -Recurse -Filter "wire.jsonl" -File 2>$null | ForEach-Object {
    $uuid = $_.Directory.Name
    $sessionState[$uuid] = "active"
    $sessionOffset[$uuid] = $_.Length
}

# --- Resolve CWD from workspace hash ---
function Resolve-KimiCwd {
    param([string]$WorkspaceHash)
    $kimiConfig = Join-Path $KimiDir "kimi.json"
    if (-not (Test-Path $kimiConfig)) { return $PWD.Path }
    try {
        $data = Get-Content $kimiConfig -Raw | ConvertFrom-Json
        foreach ($wd in $data.work_dirs) {
            $path = $wd.path
            $md5 = [System.Security.Cryptography.MD5]::Create()
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($path)
            $hash = ($md5.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join ""
            if ($hash -eq $WorkspaceHash) {
                return $path
            }
        }
    } catch {}
    return $PWD.Path
}

# --- Emit a peon.ps1 event ---
function Emit-Event {
    param([string]$EventName, [string]$SessionId, [string]$Cwd)
    $payload = @{
        hook_event_name   = $EventName
        notification_type = ""
        cwd               = $Cwd
        session_id        = $SessionId
        permission_mode   = ""
    } | ConvertTo-Json -Compress
    $payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null
}

# --- Process a single wire.jsonl line ---
function Process-WireLine {
    param([string]$Line, [string]$Uuid, [string]$Cwd)
    try {
        $data = $Line | ConvertFrom-Json
        $msg = $data.message
        if (-not $msg) { return $null }
        $eventType = $msg.type

        # Map wire events to peon.ps1 event names
        $mapped = switch ($eventType) {
            "TurnEnd"         { "Stop" }
            "CompactionBegin" { "PreCompact" }
            "TurnBegin"       { "TurnBegin" }
            "SubagentEvent"   {
                $nested = $msg.payload.message
                if ($nested -and $nested.type -eq "TurnBegin") { "SubagentStart" }
                else { $null }
            }
            default { $null }
        }

        if (-not $mapped) { return $null }

        return @{
            event      = $mapped
            session_id = "kimi-$($Uuid.Substring(0, [Math]::Min(8, $Uuid.Length)))"
            cwd        = $Cwd
        }
    } catch {
        return $null
    }
}

# --- Handle a wire.jsonl file change ---
function Handle-WireChange {
    param([string]$FilePath)
    $fname = Split-Path $FilePath -Leaf
    if ($fname -ne "wire.jsonl") { return }

    # Extract workspace_hash and session_uuid from path
    $sessionDir = Split-Path $FilePath -Parent
    $uuid = Split-Path $sessionDir -Leaf
    if (-not $uuid) { return }
    $workspaceDir = Split-Path $sessionDir -Parent
    $workspaceHash = Split-Path $workspaceDir -Leaf

    $cwd = Resolve-KimiCwd $workspaceHash

    # Read new lines
    $prevOffset = if ($sessionOffset.ContainsKey($uuid)) { $sessionOffset[$uuid] } else { 0 }
    $fileSize = (Get-Item $FilePath).Length
    if ($fileSize -le $prevOffset) { return }

    try {
        $fs = [System.IO.FileStream]::new($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $fs.Seek($prevOffset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $reader = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
        $newContent = $reader.ReadToEnd()
        $reader.Close()
        $fs.Close()
    } catch {
        return
    }

    $sessionOffset[$uuid] = $fileSize

    # Process each new line
    foreach ($line in $newContent -split "`n") {
        $line = $line.Trim()
        if (-not $line) { continue }

        $parsed = Process-WireLine $line $uuid $cwd
        if (-not $parsed) { continue }

        $event = $parsed.event
        $sessionId = $parsed.session_id
        $eventCwd = $parsed.cwd

        $prev = $sessionState[$uuid]

        switch ($event) {
            "TurnBegin" {
                if (-not $prev) {
                    # Brand new session
                    $sessionState[$uuid] = "active"
                    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                    $script:lastNewSession = @{ uuid = $uuid; timestamp = $now }
                    Write-Host "> New Kimi session: $($uuid.Substring(0, [Math]::Min(8, $uuid.Length)))"
                    Emit-Event "SessionStart" $sessionId $eventCwd
                } else {
                    # Subsequent turn
                    $sessionState[$uuid] = "active"
                    Emit-Event "UserPromptSubmit" $sessionId $eventCwd
                }
            }
            "Stop" {
                $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                $lastStop = if ($sessionStopTime.ContainsKey($uuid)) { $sessionStopTime[$uuid] } else { 0 }
                if (($now - $lastStop) -lt $StopCooldown) { continue }

                # Suppress Stop for old session when /clear just created a new one
                if ($script:lastNewSession -and $script:lastNewSession.uuid -ne $uuid) {
                    if (($now - $script:lastNewSession.timestamp) -lt $ClearGraceSeconds) {
                        Write-Host "> Suppressed Stop for $($uuid.Substring(0, [Math]::Min(8, $uuid.Length))) (/clear detected)"
                        continue
                    }
                }

                $sessionStopTime[$uuid] = $now
                $sessionState[$uuid] = "active"
                Write-Host "> Agent finished turn: $($uuid.Substring(0, [Math]::Min(8, $uuid.Length)))"
                Emit-Event "Stop" $sessionId $eventCwd
            }
            "PreCompact" {
                Write-Host "> Context compaction: $($uuid.Substring(0, [Math]::Min(8, $uuid.Length)))"
                Emit-Event "PreCompact" $sessionId $eventCwd
            }
            "SubagentStart" {
                Write-Host "> Sub-agent started: $($uuid.Substring(0, [Math]::Min(8, $uuid.Length)))"
                Emit-Event "SubagentStart" $sessionId $eventCwd
            }
        }
    }
}

# --- Start watching ---
Write-Host "peon-ping Kimi Code adapter" -ForegroundColor Cyan
Write-Host "Watching: $SessionsDir"
Write-Host "Press Ctrl+C to stop."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SessionsDir
$watcher.Filter = "wire.jsonl"
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

$action = {
    $path = $Event.SourceEventArgs.FullPath
    Handle-WireChange $path
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

# Main loop: keep alive
try {
    while ($true) {
        Start-Sleep -Seconds 1
    }
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Get-EventSubscriber | Unregister-Event
}
