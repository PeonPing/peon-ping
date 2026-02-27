# peon-ping adapter for Amp (ampcode.com) (Windows)
# Watches Amp's threads directory for agent state changes
# and translates them into peon.ps1 CESP events.
#
# Uses System.IO.FileSystemWatcher (native .NET) instead of fswatch/inotifywait.
#
# Usage:
#   powershell -NoProfile -File adapters/amp.ps1              # foreground
#   powershell -NoProfile -File adapters/amp.ps1 --install    # background daemon
#   powershell -NoProfile -File adapters/amp.ps1 --uninstall  # stop daemon
#   powershell -NoProfile -File adapters/amp.ps1 --status     # check daemon

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status
)

$ErrorActionPreference = "SilentlyContinue"

# --- Config ---
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

# Try Windows-native path first, fall back to Unix-style
$AmpDataDir = if ($env:AMP_DATA_DIR) { $env:AMP_DATA_DIR }
              elseif (Test-Path (Join-Path $env:LOCALAPPDATA "amp")) { Join-Path $env:LOCALAPPDATA "amp" }
              else { Join-Path $env:USERPROFILE ".local\share\amp" }

$ThreadsDir = if ($env:AMP_THREADS_DIR) { $env:AMP_THREADS_DIR }
              else { Join-Path $AmpDataDir "threads" }

$IdleSeconds = if ($env:AMP_IDLE_SECONDS) { [int]$env:AMP_IDLE_SECONDS } else { 1 }
$StopCooldown = if ($env:AMP_STOP_COOLDOWN) { [int]$env:AMP_STOP_COOLDOWN } else { 10 }

$PidFile = Join-Path $PeonDir ".amp-adapter.pid"
$LogFile = Join-Path $PeonDir ".amp-adapter.log"

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
                Write-Host "peon-ping Amp adapter stopped (PID $pid)"
            } else {
                Remove-Item $PidFile -Force
                Write-Host "peon-ping Amp adapter was not running (stale PID file removed)"
            }
        }
    } else {
        Write-Host "peon-ping Amp adapter is not running (no PID file)"
    }
    exit 0
}

if ($Status) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Amp adapter is running (PID $pid)"
            exit 0
        } else {
            Remove-Item $PidFile -Force
            Write-Host "peon-ping Amp adapter is not running (stale PID file removed)"
            exit 1
        }
    } else {
        Write-Host "peon-ping Amp adapter is not running"
        exit 1
    }
}

if ($Install) {
    # Check if already running
    if (Test-Path $PidFile) {
        $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Amp adapter already running (PID $oldPid)"
            exit 0
        }
        Remove-Item $PidFile -Force
    }

    # Fork to background
    $scriptPath = $MyInvocation.MyCommand.Path
    $proc = Start-Process -WindowStyle Hidden -FilePath "powershell" `
        -ArgumentList "-NoProfile", "-File", $scriptPath `
        -PassThru -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile
    Set-Content -Path $PidFile -Value $proc.Id
    Write-Host "peon-ping Amp adapter started (PID $($proc.Id))"
    Write-Host "  Watching: $ThreadsDir"
    Write-Host "  Log: $LogFile"
    Write-Host "  Stop: powershell -NoProfile -File $scriptPath -Uninstall"
    exit 0
}

# --- Preflight ---
if (-not (Test-Path $PeonScript)) {
    Write-Host "peon.ps1 not found at $PeonScript" -ForegroundColor Red
    exit 1
}

# Wait for threads directory
if (-not (Test-Path $ThreadsDir)) {
    Write-Host "Amp threads directory not found: $ThreadsDir" -ForegroundColor Yellow
    Write-Host "Waiting for Amp to create it..."
    while (-not (Test-Path $ThreadsDir)) {
        Start-Sleep -Seconds 2
    }
    Write-Host "Threads directory detected."
}

# --- State tracking ---
$threadState = @{}       # tid -> "active" or "idle"
$threadStopTime = @{}    # tid -> epoch of last Stop emission

# Record existing threads so we don't fire SessionStart for old ones
Get-ChildItem -Path $ThreadsDir -Filter "T-*.json" -File 2>$null | ForEach-Object {
    $tid = $_.BaseName
    $threadState[$tid] = "idle"
}

# --- Emit a peon.ps1 event ---
function Emit-Event {
    param([string]$EventName, [string]$ThreadId)
    $sessionId = "amp-$($ThreadId.Substring(2, [Math]::Min(8, $ThreadId.Length - 2)))"
    $payload = @{
        hook_event_name   = $EventName
        notification_type = ""
        cwd               = $PWD.Path
        session_id        = $sessionId
        permission_mode   = ""
    } | ConvertTo-Json -Compress
    $payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null
}

# --- Check if thread is waiting for user input ---
function Test-ThreadWaiting {
    param([string]$FilePath)
    try {
        $data = Get-Content $FilePath -Raw | ConvertFrom-Json
        $msgs = $data.messages
        if (-not $msgs -or $msgs.Count -eq 0) { return $false }
        $last = $msgs[$msgs.Count - 1]
        if ($last.role -ne "assistant") { return $false }
        $content = $last.content
        if (-not $content) { return $false }
        $types = @($content | ForEach-Object { $_.type })
        if ($types -contains "tool_use") { return $false }
        if ($types -contains "text") { return $true }
        return $false
    } catch {
        return $false
    }
}

# --- Handle thread file change ---
function Handle-ThreadChange {
    param([string]$FilePath)
    $fname = Split-Path $FilePath -Leaf
    if ($fname -notmatch '^T-.*\.json$') { return }
    if ($fname -match '\.amptmp$') { return }

    $tid = [System.IO.Path]::GetFileNameWithoutExtension($fname)
    if (-not $tid) { return }

    $prev = $threadState[$tid]

    if (-not $prev) {
        # Brand new thread = new agent session
        $threadState[$tid] = "active"
        Write-Host "> New Amp session: $($tid.Substring(2, [Math]::Min(10, $tid.Length - 2)))"
        Emit-Event "SessionStart" $tid
    } else {
        # Existing thread — mark active (idle checker handles Stop)
        $threadState[$tid] = "active"
    }
}

# --- Start watching ---
Write-Host "peon-ping Amp adapter" -ForegroundColor Cyan
Write-Host "Watching: $ThreadsDir"
Write-Host "Idle timeout: ${IdleSeconds}s"
Write-Host "Press Ctrl+C to stop."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $ThreadsDir
$watcher.Filter = "T-*.json"
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

# Register file change events
$action = {
    $path = $Event.SourceEventArgs.FullPath
    Handle-ThreadChange $path
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

# Main loop: idle detection
try {
    while ($true) {
        Start-Sleep -Seconds 1
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

        foreach ($tid in @($threadState.Keys)) {
            if ($threadState[$tid] -ne "active") { continue }
            $threadFile = Join-Path $ThreadsDir "$tid.json"
            if (-not (Test-Path $threadFile)) { continue }

            $mtime = (Get-Item $threadFile).LastWriteTimeUtc
            $mtimeEpoch = [DateTimeOffset]::new($mtime).ToUnixTimeSeconds()

            if ($mtimeEpoch -le ($now - $IdleSeconds)) {
                # Check cooldown
                $lastStop = if ($threadStopTime.ContainsKey($tid)) { $threadStopTime[$tid] } else { 0 }
                if (($now - $lastStop) -lt $StopCooldown) {
                    $threadState[$tid] = "idle"
                    continue
                }

                # Check if agent finished
                if (Test-ThreadWaiting $threadFile) {
                    $threadState[$tid] = "idle"
                    $threadStopTime[$tid] = $now
                    Write-Host "> Agent waiting for input: $($tid.Substring(2, [Math]::Min(10, $tid.Length - 2)))"
                    Emit-Event "Stop" $tid
                }
            }
        }
    }
} finally {
    # Cleanup
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Get-EventSubscriber | Unregister-Event
}
