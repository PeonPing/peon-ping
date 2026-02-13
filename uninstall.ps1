# peon-ping Windows Uninstaller
# Removes peon-ping hooks, skills, CLI command, and installation directory
# Usage: powershell -ExecutionPolicy Bypass -File uninstall.ps1

param(
    [switch]$KeepSounds
)

$ErrorActionPreference = "Stop"

Write-Host "=== peon-ping uninstaller ===" -ForegroundColor Cyan
Write-Host ""

# --- Paths ---
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$InstallDir = Join-Path $ClaudeDir "hooks\peon-ping"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$SkillsDir = Join-Path $ClaudeDir "skills"
$CliBinDir = Join-Path $env:USERPROFILE ".local\bin"
$CliPath = Join-Path $CliBinDir "peon.cmd"

# --- Check if installed ---
if (-not (Test-Path $InstallDir)) {
    Write-Host "peon-ping is not installed at $InstallDir" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# --- Remove hooks from settings.json ---
if (Test-Path $SettingsFile) {
    Write-Host "Removing peon hooks from settings.json..."

    try {
        $settingsObj = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        $eventsChanged = @()

        if ($settingsObj.hooks) {
            $hooksObj = $settingsObj.hooks
            $eventNames = $hooksObj.PSObject.Properties.Name

            foreach ($event in $eventNames) {
                $entries = @($hooksObj.$event)
                $originalCount = $entries.Count

                # Filter out entries that contain peon.ps1, peon.sh, or notify.sh
                $filtered = @($entries | Where-Object {
                    $hasPeon = $false
                    foreach ($h in $_.hooks) {
                        if ($h.command -and ($h.command -match "peon\.ps1" -or $h.command -match "peon\.sh" -or $h.command -match "notify\.sh")) {
                            $hasPeon = $true
                            break
                        }
                    }
                    -not $hasPeon
                })

                if ($filtered.Count -lt $originalCount) {
                    $eventsChanged += $event
                }

                if ($filtered.Count -gt 0) {
                    $hooksObj.$event = $filtered
                } else {
                    $hooksObj.PSObject.Properties.Remove($event)
                }
            }

            $settingsObj.hooks = $hooksObj
            $settingsObj | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile

            if ($eventsChanged.Count -gt 0) {
                Write-Host "  Removed hooks for: $($eventsChanged -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "  No peon hooks found in settings.json" -ForegroundColor DarkGray
            }
        }
    } catch {
        Write-Host "  Warning: Could not update settings.json: $_" -ForegroundColor Yellow
    }
}

# --- Remove skills ---
Write-Host ""
Write-Host "Removing skills..."

$skillsRemoved = 0
foreach ($skillName in @("peon-ping-toggle", "peon-ping-config")) {
    $skillPath = Join-Path $SkillsDir $skillName
    if (Test-Path $skillPath) {
        Remove-Item -Path $skillPath -Recurse -Force
        Write-Host "  /$skillName" -ForegroundColor DarkGray
        $skillsRemoved++
    }
}

if ($skillsRemoved -gt 0) {
    Write-Host "  Removed $skillsRemoved skill(s)" -ForegroundColor Green
} else {
    Write-Host "  No skills found" -ForegroundColor DarkGray
}

# --- Remove CLI command ---
if (Test-Path $CliPath) {
    Write-Host ""
    Write-Host "Removing CLI command..."
    Remove-Item -Path $CliPath -Force
    Write-Host "  Removed peon.cmd" -ForegroundColor Green
}

# --- Remove install directory ---
if (Test-Path $InstallDir) {
    Write-Host ""

    if ($KeepSounds) {
        Write-Host "Removing installation (keeping sound packs)..."
        # Remove everything except packs directory
        Get-ChildItem -Path $InstallDir | Where-Object { $_.Name -ne "packs" } | Remove-Item -Recurse -Force
        Write-Host "  Removed (packs preserved at $InstallDir\packs)" -ForegroundColor Green
    } else {
        $packsDir = Join-Path $InstallDir "packs"
        $packCount = 0
        $soundCount = 0

        if (Test-Path $packsDir) {
            $packs = Get-ChildItem -Path $packsDir -Directory
            $packCount = $packs.Count
            foreach ($pack in $packs) {
                $sounds = Get-ChildItem -Path (Join-Path $pack.FullName "sounds") -File -ErrorAction SilentlyContinue
                $soundCount += $sounds.Count
            }
        }

        Write-Host "Removing installation directory..."
        if ($packCount -gt 0) {
            Write-Host "  This will delete $packCount pack(s) ($soundCount sounds)" -ForegroundColor Yellow
            Write-Host "  Location: $InstallDir" -ForegroundColor DarkGray
            Write-Host ""
            $confirm = Read-Host "  Continue? [Y/n]"

            if ($confirm -match "^[Nn]") {
                Write-Host ""
                Write-Host "Cancelled. To keep sounds, run: .\uninstall.ps1 -KeepSounds" -ForegroundColor Yellow
                exit 0
            }
        }

        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Host "  Removed $InstallDir" -ForegroundColor Green
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== Uninstall complete ===" -ForegroundColor Green
Write-Host "Me go now." -ForegroundColor DarkGray
Write-Host ""

if ($KeepSounds) {
    Write-Host "Your sound packs are still at: $InstallDir\packs" -ForegroundColor Cyan
    Write-Host "To remove them: Remove-Item -Recurse '$InstallDir'" -ForegroundColor DarkGray
    Write-Host ""
}
