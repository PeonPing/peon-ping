# peon-ping adapter for Google Antigravity IDE (Windows)
# Watches Antigravity's conversations directory for agent state changes
# and translates them into peon.ps1 CESP events.
#
# Uses System.IO.FileSystemWatcher (native .NET) instead of fswatch/inotifywait.
#
# Usage:
#   powershell -NoProfile -File adapters/antigravity.ps1              # foreground
#   powershell -NoProfile -File adapters/antigravity.ps1 --install    # background daemon
#   powershell -NoProfile -File adapters/antigravity.ps1 --uninstall  # stop daemon
#   powershell -NoProfile -File adapters/antigravity.ps1 --status     # check daemon

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status
)

$ErrorActionPreference = "SilentlyContinue"

# --- Config ---
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$AgDir = if ($env:ANTIGRAVITY_DIR) { $env:ANTIGRAVITY_DIR }
         else { Join-Path $env:USERPROFILE ".gemini\antigravity" }

$ConversationsDir = if ($env:ANTIGRAVITY_CONVERSATIONS_DIR) { $env:ANTIGRAVITY_CONVERSATIONS_DIR }
                    else { Join-Path $AgDir "conversations" }

$IdleSeconds = if ($env:ANTIGRAVITY_IDLE_SECONDS) { [int]$env:ANTIGRAVITY_IDLE_SECONDS } else { 5 }
$StopCooldown = if ($env:ANTIGRAVITY_STOP_COOLDOWN) { [int]$env:ANTIGRAVITY_STOP_COOLDOWN } else { 10 }

$PidFile = Join-Path $PeonDir ".antigravity-adapter.pid"
$LogFile = Join-Path $PeonDir ".antigravity-adapter.log"

$PeonScript = Join-Path $PeonDir "peon.ps1"

# --- Daemon management ---
if ($Uninstall) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($pid) {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                Stop-Process -Id $pid -Force
                Remove-Item $PidFile -Force
                Write-Host "peon-ping Antigravity adapter stopped (PID $pid)"
            } else {
                Remove-Item $PidFile -Force
                Write-Host "peon-ping Antigravity adapter was not running (stale PID file removed)"
            }
        }
    } else {
        Write-Host "peon-ping Antigravity adapter is not running (no PID file)"
    }
    exit 0
}

if ($Status) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Antigravity adapter is running (PID $pid)"
            exit 0
        } else {
            Remove-Item $PidFile -Force
            Write-Host "peon-ping Antigravity adapter is not running (stale PID file removed)"
            exit 1
        }
    } else {
        Write-Host "peon-ping Antigravity adapter is not running"
        exit 1
    }
}

if ($Install) {
    if (Test-Path $PidFile) {
        $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Antigravity adapter already running (PID $oldPid)"
            exit 0
        }
        Remove-Item $PidFile -Force
    }

    $scriptPath = $MyInvocation.MyCommand.Path
    $proc = Start-Process -WindowStyle Hidden -FilePath "powershell" `
        -ArgumentList "-NoProfile", "-File", $scriptPath `
        -PassThru -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile
    Set-Content -Path $PidFile -Value $proc.Id
    Write-Host "peon-ping Antigravity adapter started (PID $($proc.Id))"
    Write-Host "  Watching: $ConversationsDir"
    Write-Host "  Log: $LogFile"
    Write-Host "  Stop: powershell -NoProfile -File $scriptPath -Uninstall"
    exit 0
}

# --- Preflight ---
if (-not (Test-Path $PeonScript)) {
    Write-Host "peon.ps1 not found at $PeonScript" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ConversationsDir)) {
    Write-Host "Antigravity conversations directory not found: $ConversationsDir" -ForegroundColor Yellow
    Write-Host "Waiting for Antigravity to create it..."
    while (-not (Test-Path $ConversationsDir)) {
        Start-Sleep -Seconds 2
    }
    Write-Host "Conversations directory detected."
}

# --- State tracking ---
$guidState = @{}       # guid -> "active" or "idle"
$guidStopTime = @{}    # guid -> epoch of last Stop emission

# Record existing .pb files so we don't fire SessionStart for old sessions
Get-ChildItem -Path $ConversationsDir -Filter "*.pb" -File 2>$null | ForEach-Object {
    $guid = $_.BaseName
    $guidState[$guid] = "idle"
}

# --- Emit a peon.ps1 event ---
function Emit-Event {
    param([string]$EventName, [string]$Guid)
    $sessionId = "antigravity-$($Guid.Substring(0, [Math]::Min(8, $Guid.Length)))"
    $payload = @{
        hook_event_name   = $EventName
        notification_type = ""
        cwd               = $PWD.Path
        session_id        = $sessionId
        permission_mode   = ""
    } | ConvertTo-Json -Compress
    $payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null
}

# --- Handle conversation file change ---
function Handle-ConversationChange {
    param([string]$FilePath)
    $fname = Split-Path $FilePath -Leaf
    if ($fname -notmatch '\.pb$') { return }

    $guid = [System.IO.Path]::GetFileNameWithoutExtension($fname)
    if (-not $guid) { return }

    $prev = $guidState[$guid]

    if (-not $prev) {
        # Brand new conversation = new agent session
        $guidState[$guid] = "active"
        Write-Host "> New agent session: $($guid.Substring(0, [Math]::Min(8, $guid.Length)))"
        Emit-Event "SessionStart" $guid
    } else {
        # Existing session — mark active (idle checker handles Stop)
        $guidState[$guid] = "active"
    }
}

# --- Start watching ---
Write-Host "peon-ping Antigravity adapter" -ForegroundColor Cyan
Write-Host "Watching: $ConversationsDir"
Write-Host "Idle timeout: ${IdleSeconds}s"
Write-Host "Press Ctrl+C to stop."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $ConversationsDir
$watcher.Filter = "*.pb"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

$action = {
    $path = $Event.SourceEventArgs.FullPath
    Handle-ConversationChange $path
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

# Main loop: idle detection
try {
    while ($true) {
        Start-Sleep -Seconds 2
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

        foreach ($guid in @($guidState.Keys)) {
            if ($guidState[$guid] -ne "active") { continue }
            $pbFile = Join-Path $ConversationsDir "$guid.pb"
            if (-not (Test-Path $pbFile)) { continue }

            $mtime = (Get-Item $pbFile).LastWriteTimeUtc
            $mtimeEpoch = [DateTimeOffset]::new($mtime).ToUnixTimeSeconds()

            if ($mtimeEpoch -le ($now - $IdleSeconds)) {
                # Check cooldown
                $lastStop = if ($guidStopTime.ContainsKey($guid)) { $guidStopTime[$guid] } else { 0 }
                if (($now - $lastStop) -lt $StopCooldown) {
                    $guidState[$guid] = "idle"
                    continue
                }

                $guidState[$guid] = "idle"
                $guidStopTime[$guid] = $now
                Write-Host "> Agent completed: $($guid.Substring(0, [Math]::Min(8, $guid.Length)))"
                Emit-Event "Stop" $guid
            }
        }
    }
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Get-EventSubscriber | Unregister-Event
}
