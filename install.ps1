# peon-ping Windows Installer
# Native Windows port - plays Warcraft III Peon sounds when Claude Code needs attention
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1
# Made by https://github.com/SpamsRevenge in https://github.com/PeonPing/peon-ping/issues/94

param(
    [string]$Pack = "peon",
    [switch]$All
)

$ErrorActionPreference = "Stop"

Write-Host "=== peon-ping Windows installer ===" -ForegroundColor Cyan
Write-Host ""

# --- Paths ---
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$InstallDir = Join-Path $ClaudeDir "hooks\peon-ping"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$RegistryUrl = "https://peonping.github.io/registry/index.json"

# --- Check Claude Code is installed ---
$Updating = $false
if (Test-Path (Join-Path $InstallDir "peon.ps1")) {
    $Updating = $true
    Write-Host "Existing install found. Updating..." -ForegroundColor Yellow
}

if (-not (Test-Path $ClaudeDir)) {
    Write-Host "Error: $ClaudeDir not found. Is Claude Code installed?" -ForegroundColor Red
    Write-Host "Install Claude Code first, then run this installer." -ForegroundColor Red
    exit 1
}

# --- Fetch registry ---
Write-Host "Fetching pack registry..."
$registry = $null
try {
    $regResponse = Invoke-WebRequest -Uri $RegistryUrl -UseBasicParsing -ErrorAction Stop
    $registry = $regResponse.Content | ConvertFrom-Json
    Write-Host "  Registry: $($registry.packs.Count) packs available" -ForegroundColor Green
} catch {
    Write-Host "  Warning: Could not fetch registry ($($_.Exception.Message))" -ForegroundColor Yellow
    Write-Host "  Cannot install without registry. Check your internet connection." -ForegroundColor Red
    exit 1
}

# --- Decide which packs to download ---
$packsToInstall = @()
if ($All) {
    $packsToInstall = $registry.packs
    Write-Host "  Installing ALL $($packsToInstall.Count) packs..." -ForegroundColor Cyan
} else {
    # Default: install a curated set of popular packs
    $defaultPacks = @("peon", "peasant", "sc_battlecruiser", "sc_kerrigan", "ra2_soviet_engineer", "tf2_engineer", "glados")
    $packsToInstall = $registry.packs | Where-Object { $_.name -in $defaultPacks }
    # Always include the selected pack
    if ($Pack -and $Pack -notin $defaultPacks) {
        $extra = $registry.packs | Where-Object { $_.name -eq $Pack }
        if ($extra) { $packsToInstall += $extra }
    }
    Write-Host "  Installing $($packsToInstall.Count) packs (use -All for all $($registry.packs.Count))..." -ForegroundColor Cyan
}

# --- Create directories ---
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

# --- Download packs ---
Write-Host ""
Write-Host "Downloading sound packs..." -ForegroundColor White
$totalSounds = 0
$failedPacks = 0

foreach ($packInfo in $packsToInstall) {
    $packName = $packInfo.name
    $sourceRepo = $packInfo.source_repo
    $sourceRef = $packInfo.source_ref
    $sourcePath = $packInfo.source_path
    $packBase = "https://raw.githubusercontent.com/$sourceRepo/$sourceRef/$sourcePath"

    $packDir = Join-Path $InstallDir "packs\$packName"
    $soundsDir = Join-Path $packDir "sounds"
    New-Item -ItemType Directory -Path $soundsDir -Force | Out-Null

    # Download manifest
    $manifestPath = Join-Path $packDir "openpeon.json"
    try {
        Invoke-WebRequest -Uri "$packBase/openpeon.json" -OutFile $manifestPath -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  [$packName] Failed to download manifest - skipping" -ForegroundColor Yellow
        $failedPacks++
        continue
    }

    # Parse manifest and download sounds
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $soundFiles = @()
        foreach ($catName in $manifest.categories.PSObject.Properties.Name) {
            $cat = $manifest.categories.$catName
            foreach ($sound in $cat.sounds) {
                $file = Split-Path $sound.file -Leaf
                if ($file -and $soundFiles -notcontains $file) {
                    $soundFiles += $file
                }
            }
        }

        $downloaded = 0
        $skipped = 0
        foreach ($sfile in $soundFiles) {
            $soundPath = Join-Path $soundsDir $sfile
            if (Test-Path $soundPath) {
                $skipped++
                $downloaded++
                continue
            }
            try {
                Invoke-WebRequest -Uri "$packBase/sounds/$sfile" -OutFile $soundPath -UseBasicParsing -ErrorAction Stop
                $downloaded++
            } catch {
                # non-critical, skip this sound
            }
        }
        $totalSounds += $downloaded
        $status = if ($skipped -eq $downloaded -and $downloaded -gt 0) { "(cached)" } else { "" }
        Write-Host "  [$packName] $downloaded/$($soundFiles.Count) sounds $status" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [$packName] Failed to parse manifest" -ForegroundColor Yellow
        $failedPacks++
    }
}

Write-Host ""
Write-Host "  Total: $totalSounds sounds across $($packsToInstall.Count - $failedPacks) packs" -ForegroundColor Green

# --- Install config ---
$configPath = Join-Path $InstallDir "config.json"
if (-not $Updating) {
    $config = @{
        active_pack = $Pack
        volume = 0.5
        enabled = $true
        desktop_notifications = $true
        categories = @{
            "session.start" = $true
            "task.acknowledge" = $true
            "task.complete" = $true
            "task.error" = $true
            "input.required" = $true
            "resource.limit" = $true
            "user.spam" = $true
        }
        annoyed_threshold = 3
        annoyed_window_seconds = 10
        silent_window_seconds = 0
        pack_rotation = @()
        pack_rotation_mode = "random"
    } | ConvertTo-Json -Depth 3
    Set-Content -Path $configPath -Value $config
}

# --- Install state ---
$statePath = Join-Path $InstallDir ".state.json"
if (-not $Updating) {
    Set-Content -Path $statePath -Value "{}"
}

# --- Install the main hook script (PowerShell) ---
$hookScript = @'
# peon-ping hook for Claude Code (Windows native)
# Called by Claude Code hooks on SessionStart, Stop, Notification, PermissionRequest, UserPromptSubmit

param(
    [string]$Command = ""
)

# --- CLI commands ---
if ($Command) {
    $InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $ConfigPath = Join-Path $InstallDir "config.json"

    # Ensure config exists
    if (-not (Test-Path $ConfigPath)) {
        Write-Host "Error: peon-ping not configured. Config not found at $ConfigPath" -ForegroundColor Red
        exit 1
    }

    switch -Regex ($Command) {
        "^--toggle$" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $newState = -not $cfg.enabled
            $raw = Get-Content $ConfigPath -Raw
            $raw = $raw -replace '"enabled"\s*:\s*(true|false)', "`"enabled`": $($newState.ToString().ToLower())"
            Set-Content $ConfigPath -Value $raw
            $state = if ($newState) { "ENABLED" } else { "PAUSED" }
            Write-Host "peon-ping: $state" -ForegroundColor Cyan
            return
        }
        "^--pause$" {
            $raw = Get-Content $ConfigPath -Raw
            $raw = $raw -replace '"enabled"\s*:\s*(true|false)', '"enabled": false'
            Set-Content $ConfigPath -Value $raw
            Write-Host "peon-ping: PAUSED" -ForegroundColor Yellow
            return
        }
        "^--resume$" {
            $raw = Get-Content $ConfigPath -Raw
            $raw = $raw -replace '"enabled"\s*:\s*(true|false)', '"enabled": true'
            Set-Content $ConfigPath -Value $raw
            Write-Host "peon-ping: ENABLED" -ForegroundColor Green
            return
        }
        "^--status$" {
            try {
                $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
                $state = if ($cfg.enabled) { "ENABLED" } else { "PAUSED" }
                Write-Host "peon-ping: $state | pack: $($cfg.active_pack) | volume: $($cfg.volume)" -ForegroundColor Cyan
            } catch {
                Write-Host "Error reading config: $_" -ForegroundColor Red
                exit 1
            }
            return
        }
        "^--packs$" {
            $packsDir = Join-Path $InstallDir "packs"
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            Write-Host "Available packs:" -ForegroundColor Cyan
            Get-ChildItem -Path $packsDir -Directory | Sort-Object Name | ForEach-Object {
                $soundCount = (Get-ChildItem -Path (Join-Path $_.FullName "sounds") -File -ErrorAction SilentlyContinue | Measure-Object).Count
                if ($soundCount -gt 0) {
                    $marker = if ($_.Name -eq $cfg.active_pack) { " <-- active" } else { "" }
                    Write-Host "  $($_.Name) ($soundCount sounds)$marker"
                }
            }
            return
        }
        "^--pack$" {
            $cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
            $packsDir = Join-Path $InstallDir "packs"
            $available = Get-ChildItem -Path $packsDir -Directory | Where-Object {
                (Get-ChildItem -Path (Join-Path $_.FullName "sounds") -File -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
            } | ForEach-Object { $_.Name } | Sort-Object

            if ($args.Count -gt 0 -and $args[0]) {
                $newPack = $args[0]
            } else {
                $idx = [array]::IndexOf($available, $cfg.active_pack)
                $newPack = $available[($idx + 1) % $available.Count]
            }

            $raw = Get-Content $ConfigPath -Raw
            $raw = $raw -replace '"active_pack"\s*:\s*"[^"]*"', "`"active_pack`": `"$newPack`""
            Set-Content $ConfigPath -Value $raw
            Write-Host "peon-ping: switched to '$newPack'" -ForegroundColor Green
            return
        }
        "^--volume$" {
            if ($args.Count -gt 0) {
                $vol = [math]::Max(0, [math]::Min(1, [double]$args[0]))
                $raw = Get-Content $ConfigPath -Raw
                $raw = $raw -replace '"volume"\s*:\s*[\d.]+', "`"volume`": $vol"
                Set-Content $ConfigPath -Value $raw
                Write-Host "peon-ping: volume set to $vol" -ForegroundColor Green
            } else {
                Write-Host "Usage: peon --volume 0.5" -ForegroundColor Yellow
            }
            return
        }
        "^--help$" {
            Write-Host "peon-ping commands:" -ForegroundColor Cyan
            Write-Host "  --toggle       Toggle enabled/paused"
            Write-Host "  --pause        Pause sounds"
            Write-Host "  --resume       Resume sounds"
            Write-Host "  --status       Show current status"
            Write-Host "  --packs        List available sound packs"
            Write-Host "  --pack [name]  Switch pack (or cycle)"
            Write-Host "  --volume N     Set volume (0.0-1.0)"
            Write-Host "  --help         Show this help"
            return
        }
    }
    return
}

# --- Hook mode (called by Claude Code via stdin JSON) ---
$InstallDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ConfigPath = Join-Path $InstallDir "config.json"
$StatePath = Join-Path $InstallDir ".state.json"

# Read config
try {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
} catch {
    exit 0
}

if (-not $config.enabled) { exit 0 }

# Read hook input from stdin
$hookInput = ""
try {
    if (-not [Console]::IsInputRedirected) { exit 0 }
    $hookInput = [Console]::In.ReadToEnd()
} catch {
    exit 0
}

if (-not $hookInput) { exit 0 }

try {
    $event = $hookInput | ConvertFrom-Json
} catch {
    exit 0
}

$hookEvent = $event.hook_event_name
if (-not $hookEvent) { exit 0 }

# Read state
$state = @{}
try {
    if (Test-Path $StatePath) {
        $state = Get-Content $StatePath -Raw | ConvertFrom-Json -AsHashtable
    }
} catch {
    $state = @{}
}

# --- Map Claude Code hook event -> CESP manifest category ---
$category = $null
$ntype = $event.notification_type

switch ($hookEvent) {
    "SessionStart" {
        $category = "session.start"
    }
    "Stop" {
        $category = "task.complete"
        # Debounce rapid Stop events (5s cooldown)
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $lastStop = if ($state.ContainsKey("last_stop_time")) { $state["last_stop_time"] } else { 0 }
        if (($now - $lastStop) -lt 5) {
            $category = $null
        }
        $state["last_stop_time"] = $now
    }
    "Notification" {
        if ($ntype -eq "permission_prompt") {
            # PermissionRequest event handles the sound, skip here
            $category = $null
        } elseif ($ntype -eq "idle_prompt") {
            # Stop event already played the sound
            $category = $null
        } else {
            $category = $null
        }
    }
    "PermissionRequest" {
        $category = "input.required"
    }
    "UserPromptSubmit" {
        # Detect rapid prompts for "annoyed" easter egg
        $sessionId = if ($event.session_id) { $event.session_id } else { "default" }
        $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $annoyedThreshold = if ($config.annoyed_threshold) { $config.annoyed_threshold } else { 3 }
        $annoyedWindow = if ($config.annoyed_window_seconds) { $config.annoyed_window_seconds } else { 10 }

        $allPrompts = if ($state.ContainsKey("prompt_timestamps")) { $state["prompt_timestamps"] } else { @{} }
        $recentPrompts = @()
        if ($allPrompts.ContainsKey($sessionId)) {
            $recentPrompts = @($allPrompts[$sessionId] | Where-Object { ($now - $_) -lt $annoyedWindow })
        }
        $recentPrompts += $now
        $allPrompts[$sessionId] = $recentPrompts
        $state["prompt_timestamps"] = $allPrompts

        if ($recentPrompts.Count -ge $annoyedThreshold) {
            $category = "user.spam"
        }
    }
}

# Save state
try {
    $state | ConvertTo-Json -Depth 3 | Set-Content $StatePath
} catch {}

if (-not $category) { exit 0 }

# Check if category is enabled
try {
    $catEnabled = $config.categories.$category
    if ($catEnabled -eq $false) { exit 0 }
} catch {}

# --- Pick a sound ---
$activePack = $config.active_pack
if (-not $activePack) { $activePack = "peon" }

# Support pack rotation
if ($config.pack_rotation -and $config.pack_rotation.Count -gt 0) {
    $activePack = $config.pack_rotation | Get-Random
}

$packDir = Join-Path $InstallDir "packs\$activePack"
$manifestPath = Join-Path $packDir "openpeon.json"
if (-not (Test-Path $manifestPath)) { exit 0 }

try {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
} catch { exit 0 }

# Get sounds for this category
$catSounds = $null
try {
    $catSounds = $manifest.categories.$category.sounds
} catch {}
if (-not $catSounds -or $catSounds.Count -eq 0) { exit 0 }

# Anti-repeat: avoid last played sound
$lastKey = "last_$category"
$lastPlayed = ""
if ($state.ContainsKey($lastKey)) {
    $lastPlayed = $state[$lastKey]
}

$candidates = @($catSounds | Where-Object { (Split-Path $_.file -Leaf) -ne $lastPlayed })
if ($candidates.Count -eq 0) { $candidates = @($catSounds) }

$chosen = $candidates | Get-Random
$soundFile = Split-Path $chosen.file -Leaf
$soundPath = Join-Path $packDir "sounds\$soundFile"

if (-not (Test-Path $soundPath)) { exit 0 }

# Save last played
$state[$lastKey] = $soundFile
try {
    $state | ConvertTo-Json -Depth 3 | Set-Content $StatePath
} catch {}

# --- Play the sound (async) ---
$volume = $config.volume
if (-not $volume) { $volume = 0.5 }

# Use Start-Job for async playback to avoid blocking Claude Code
$null = Start-Job -ArgumentList $soundPath, $volume -ScriptBlock {
    param($path, $vol)
    try {
        Add-Type -AssemblyName PresentationCore
        $player = New-Object System.Windows.Media.MediaPlayer
        $fullPath = (Resolve-Path $path).Path
        $player.Open([Uri]::new("file:///$($fullPath -replace '\\','/')"))
        $player.Volume = $vol
        Start-Sleep -Milliseconds 150
        $player.Play()
        # Wait for playback to start
        $timeout = 50
        while ($timeout -gt 0 -and $player.Position.TotalMilliseconds -eq 0) {
            Start-Sleep -Milliseconds 100
            $timeout--
        }
        if ($player.NaturalDuration.HasTimeSpan) {
            $remaining = $player.NaturalDuration.TimeSpan.TotalMilliseconds - $player.Position.TotalMilliseconds
            if ($remaining -gt 0 -and $remaining -lt 5000) {
                Start-Sleep -Milliseconds ([int]$remaining + 100)
            }
        } else {
            Start-Sleep -Seconds 2
        }
        $player.Close()
    } catch {
        # Fallback: use SoundPlayer for WAV files (async)
        try {
            if ($path -match "\.wav$") {
                $sp = New-Object System.Media.SoundPlayer $path
                $sp.Play()  # Play() is async, PlaySync() blocks
                Start-Sleep -Seconds 2
                $sp.Dispose()
            }
        } catch {}
    }
}

exit 0
'@

$hookScriptPath = Join-Path $InstallDir "peon.ps1"
Set-Content -Path $hookScriptPath -Value $hookScript

# --- Install CLI shortcut ---
$peonCli = @"
@echo off
setlocal
set "cmd=%~1"
if "%cmd%"=="" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\hooks\peon-ping\peon.ps1" --help
) else (
    shift
    powershell -NoProfile -ExecutionPolicy Bypass -File "%USERPROFILE%\.claude\hooks\peon-ping\peon.ps1" %cmd% %1 %2 %3
)
"@
$cliBinDir = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $cliBinDir)) {
    New-Item -ItemType Directory -Path $cliBinDir -Force | Out-Null
}
$cliBatPath = Join-Path $cliBinDir "peon.cmd"
Set-Content -Path $cliBatPath -Value $peonCli

# Add to PATH if not already there
$userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$cliBinDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$userPath;$cliBinDir", "User")
    Write-Host ""
    Write-Host "  Added $cliBinDir to PATH" -ForegroundColor Green
}

# --- Update Claude Code settings.json with hooks ---
Write-Host ""
Write-Host "Registering Claude Code hooks..."

$hookCmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$hookScriptPath`""

# Load or create settings
$settings = @{}
if (Test-Path $SettingsFile) {
    try {
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json -AsHashtable
    } catch {
        $settings = @{}
    }
}

if (-not $settings.ContainsKey("hooks")) {
    $settings["hooks"] = @{}
}

$peonHook = @{
    type = "command"
    command = $hookCmd
    timeout = 10
}

$peonEntry = @{
    matcher = ""
    hooks = @($peonHook)
}

$events = @("SessionStart", "UserPromptSubmit", "Stop", "Notification", "PermissionRequest")

foreach ($evt in $events) {
    $eventHooks = @()
    if ($settings["hooks"].ContainsKey($evt)) {
        # Remove existing peon entries
        $eventHooks = @($settings["hooks"][$evt] | Where-Object {
            $dominated = $false
            foreach ($h in $_.hooks) {
                if ($h.command -and ($h.command -match "peon" -or $h.command -match "notify\.sh")) {
                    $dominated = $true
                }
            }
            -not $dominated
        })
    }
    $eventHooks += $peonEntry
    $settings["hooks"][$evt] = $eventHooks
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile
Write-Host "  Hooks registered for: $($events -join ', ')" -ForegroundColor Green

# --- Install skills ---
Write-Host ""
Write-Host "Installing skills..."

$skillsSourceDir = Join-Path $PSScriptRoot "skills"
$skillsTargetDir = Join-Path $ClaudeDir "skills"

if (Test-Path $skillsSourceDir) {
    New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null

    Get-ChildItem -Path $skillsSourceDir -Directory | ForEach-Object {
        $skillName = $_.Name
        $skillTarget = Join-Path $skillsTargetDir $skillName

        # Remove old version if exists
        if (Test-Path $skillTarget) {
            Remove-Item -Path $skillTarget -Recurse -Force
        }

        # Copy skill
        Copy-Item -Path $_.FullName -Destination $skillTarget -Recurse -Force
        Write-Host "  /$skillName" -ForegroundColor DarkGray
    }

    Write-Host "  Skills installed" -ForegroundColor Green
} else {
    Write-Host "  Skills directory not found, skipping" -ForegroundColor Yellow
}

# --- Test sound ---
Write-Host ""
Write-Host "Testing sound..."

$testPack = if (-not $Updating) { $Pack } else {
    try {
        (Get-Content $configPath -Raw | ConvertFrom-Json).active_pack
    } catch { "peon" }
}

$testPackDir = Join-Path $InstallDir "packs\$testPack\sounds"
$testSound = Get-ChildItem -Path $testPackDir -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($testSound) {
    try {
        Add-Type -AssemblyName PresentationCore
        $player = New-Object System.Windows.Media.MediaPlayer
        $fullPath = $testSound.FullName
        $player.Open([Uri]::new("file:///$($fullPath -replace '\\','/')"))
        $player.Volume = 0.3
        Start-Sleep -Milliseconds 200
        $player.Play()
        Start-Sleep -Seconds 3
        $player.Close()
        Write-Host "  Sound working!" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Sound playback failed: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Warning: No sound files found for pack '$testPack'" -ForegroundColor Yellow
}

# --- Done ---
Write-Host ""
if ($Updating) {
    Write-Host "=== peon-ping updated! ===" -ForegroundColor Green
} else {
    Write-Host "=== peon-ping installed! ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Active pack: $Pack" -ForegroundColor Cyan
    Write-Host "  Volume: 0.5" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Commands (open a new terminal first):" -ForegroundColor White
    Write-Host "    peon --status     Show status"
    Write-Host "    peon --packs      List sound packs"
    Write-Host "    peon --pack NAME  Switch pack"
    Write-Host "    peon --volume N   Set volume (0.0-1.0)"
    Write-Host "    peon --pause      Mute sounds"
    Write-Host "    peon --resume     Unmute sounds"
    Write-Host "    peon --toggle     Toggle on/off"
    Write-Host ""
    Write-Host "  Start Claude Code and you'll hear: `"Ready to work?`"" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  To install ALL packs: .\install.ps1 -All" -ForegroundColor DarkGray
    Write-Host "  To uninstall: powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`"" -ForegroundColor DarkGray
}
Write-Host ""```
