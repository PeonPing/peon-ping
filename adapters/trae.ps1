# peon-ping adapter for Trae IDE (trae.ai, ByteDance) (Windows)
# Watches Trae's session directory for agent state changes and translates
# them into peon.ps1 CESP events using System.IO.FileSystemWatcher (native .NET).
#
# Trae is a VS Code-derived, AI-first IDE that exposes MCP and VS Code
# extensions but no synchronous JSON-piping shell-hook API, so peon-ping
# follows the same filesystem-watcher approach used for Amp and Antigravity.
# Trae's on-disk session layout is not publicly documented, so the watched
# directory and file filter are overridable via environment variables:
#   TRAE_DATA_DIR       (default: %USERPROFILE%\.trae)
#   TRAE_SESSIONS_DIR   (default: $TRAE_DATA_DIR\sessions)
#   TRAE_SESSION_GLOB   (default: *.json)
#
# Usage:
#   powershell -NoProfile -File adapters/trae.ps1              # foreground
#   powershell -NoProfile -File adapters/trae.ps1 -Install     # background daemon
#   powershell -NoProfile -File adapters/trae.ps1 -Uninstall   # stop daemon
#   powershell -NoProfile -File adapters/trae.ps1 -Status      # check daemon

param(
    [switch]$Install,
    [switch]$Uninstall,
    [switch]$Status
)

$ErrorActionPreference = "SilentlyContinue"

# --- Config ---
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR }
           else { Join-Path $env:USERPROFILE ".claude\hooks\peon-ping" }

$TraeDir = if ($env:TRAE_DATA_DIR) { $env:TRAE_DATA_DIR }
           else { Join-Path $env:USERPROFILE ".trae" }

$SessionsDir = if ($env:TRAE_SESSIONS_DIR) { $env:TRAE_SESSIONS_DIR }
               else { Join-Path $TraeDir "sessions" }

$SessionGlob = if ($env:TRAE_SESSION_GLOB) { $env:TRAE_SESSION_GLOB } else { "*.json" }
$IdleSeconds = if ($env:TRAE_IDLE_SECONDS) { [int]$env:TRAE_IDLE_SECONDS } else { 3 }
$StopCooldown = if ($env:TRAE_STOP_COOLDOWN) { [int]$env:TRAE_STOP_COOLDOWN } else { 10 }

$PidFile = Join-Path $PeonDir ".trae-adapter.pid"
$LogFile = Join-Path $PeonDir ".trae-adapter.log"

$PeonScript = Join-Path $PeonDir "peon.ps1"

# --- Daemon management ---
if ($Uninstall) {
    if (Test-Path $PidFile) {
        $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        if ($oldPid) {
            $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
            if ($proc) {
                Stop-Process -Id $oldPid -Force
                Remove-Item $PidFile -Force
                Write-Host "peon-ping Trae adapter stopped (PID $oldPid)"
            } else {
                Remove-Item $PidFile -Force
                Write-Host "peon-ping Trae adapter was not running (stale PID file removed)"
            }
        }
    } else {
        Write-Host "peon-ping Trae adapter is not running (no PID file)"
    }
    exit 0
}

if ($Status) {
    if (Test-Path $PidFile) {
        $curPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $curPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Trae adapter is running (PID $curPid)"
            exit 0
        } else {
            Remove-Item $PidFile -Force
            Write-Host "peon-ping Trae adapter is not running (stale PID file removed)"
            exit 1
        }
    } else {
        Write-Host "peon-ping Trae adapter is not running"
        exit 1
    }
}

if ($Install) {
    if (Test-Path $PidFile) {
        $oldPid = Get-Content $PidFile -ErrorAction SilentlyContinue
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "peon-ping Trae adapter already running (PID $oldPid)"
            exit 0
        }
        Remove-Item $PidFile -Force
    }

    $scriptPath = $MyInvocation.MyCommand.Path
    $proc = Start-Process -WindowStyle Hidden -FilePath "powershell" `
        -ArgumentList "-NoProfile", "-File", $scriptPath `
        -PassThru -RedirectStandardOutput $LogFile -RedirectStandardError $LogFile
    Set-Content -Path $PidFile -Value $proc.Id
    Write-Host "peon-ping Trae adapter started (PID $($proc.Id))"
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
    Write-Host "Trae sessions directory not found: $SessionsDir" -ForegroundColor Yellow
    Write-Host "Set TRAE_SESSIONS_DIR to your Trae session storage path."
    Write-Host "Waiting for Trae to create it..."
    while (-not (Test-Path $SessionsDir)) {
        Start-Sleep -Seconds 2
    }
    Write-Host "Sessions directory detected."
}

# --- State tracking ---
$sessionState = @{}      # sid -> "active" or "idle"
$sessionStopTime = @{}   # sid -> epoch of last Stop emission

# Record existing session files so we don't fire SessionStart for old sessions
Get-ChildItem -Path $SessionsDir -Filter $SessionGlob -File 2>$null | ForEach-Object {
    $sessionState[$_.BaseName] = "idle"
}

# --- Emit a peon.ps1 event ---
function Emit-Event {
    param([string]$EventName, [string]$SessionId)
    $payload = @{
        hook_event_name   = $EventName
        notification_type = ""
        cwd               = $PWD.Path
        session_id        = "trae-$SessionId"
        permission_mode   = ""
    } | ConvertTo-Json -Compress
    $payload | powershell -NoProfile -NonInteractive -File $PeonScript 2>$null
}

# --- Handle session file change ---
function Handle-SessionChange {
    param([string]$FilePath)
    $sid = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    if (-not $sid) { return }

    $prev = $sessionState[$sid]
    if (-not $prev) {
        $sessionState[$sid] = "active"
        Write-Host "> New Trae session: $sid"
        Emit-Event "SessionStart" $sid
    } else {
        $sessionState[$sid] = "active"
    }
}

# --- Start watching ---
Write-Host "peon-ping Trae adapter" -ForegroundColor Cyan
Write-Host "Watching: $SessionsDir ($SessionGlob)"
Write-Host "Idle timeout: ${IdleSeconds}s"
Write-Host "Press Ctrl+C to stop."

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $SessionsDir
$watcher.Filter = $SessionGlob
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

$action = {
    $path = $Event.SourceEventArgs.FullPath
    Handle-SessionChange $path
}

Register-ObjectEvent $watcher "Changed" -Action $action | Out-Null
Register-ObjectEvent $watcher "Created" -Action $action | Out-Null

# Main loop: idle detection
try {
    while ($true) {
        Start-Sleep -Seconds 1
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

        foreach ($sid in @($sessionState.Keys)) {
            if ($sessionState[$sid] -ne "active") { continue }
            $sfile = Get-ChildItem -Path $SessionsDir -Filter "$sid.*" -File 2>$null | Select-Object -First 1
            if (-not $sfile) { continue }

            $mtimeEpoch = [DateTimeOffset]::new($sfile.LastWriteTimeUtc).ToUnixTimeSeconds()
            if ($mtimeEpoch -le ($now - $IdleSeconds)) {
                $lastStop = if ($sessionStopTime.ContainsKey($sid)) { $sessionStopTime[$sid] } else { 0 }
                if (($now - $lastStop) -lt $StopCooldown) {
                    $sessionState[$sid] = "idle"
                    continue
                }
                $sessionState[$sid] = "idle"
                $sessionStopTime[$sid] = $now
                Write-Host "> Agent completed: $sid"
                Emit-Event "Stop" $sid
            }
        }
    }
} finally {
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Get-EventSubscriber | Unregister-Event
}
