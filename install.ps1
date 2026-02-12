# peon-ping installer for Windows
# Works both via Invoke-Expression and local clone
# Re-running updates core files; sounds are version-controlled in the repo

$ErrorActionPreference = "Stop"

$InstallDir = "$env:USERPROFILE\.claude\hooks\peon-ping"
$Settings = "$env:USERPROFILE\.claude\settings.json"
$RepoBase = "https://raw.githubusercontent.com/tonyyont/peon-ping/main"

# All available sound packs
$Packs = @("peon", "peon_fr", "peon_pl", "peasant", "peasant_fr", "ra2_soviet_engineer", "sc_battlecruiser", "sc_kerrigan")

# --- Detect update vs fresh install ---
$Updating = Test-Path "$InstallDir\peon.ps1"

if ($Updating) {
    Write-Host "=== peon-ping updater ==="
    Write-Host ""
    Write-Host "Existing install found. Updating..."
} else {
    Write-Host "=== peon-ping installer ==="
    Write-Host ""
}

# --- Prerequisites ---
$pythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCmd = "python"
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonCmd = "python3"
} else {
    Write-Error "Error: python is required. Install from python.org or Microsoft Store"
    exit 1
}

if (-not (Test-Path "$env:USERPROFILE\.claude")) {
    Write-Error "Error: ~/.claude/ not found. Is Claude Code installed?"
    exit 1
}

# --- Detect if running from local clone ---
$ScriptDir = ""
if ($PSScriptRoot -and (Test-Path "$PSScriptRoot\peon.ps1")) {
    $ScriptDir = $PSScriptRoot
}

# --- Install/update core files ---
foreach ($pack in $Packs) {
    New-Item -ItemType Directory -Path "$InstallDir\packs\$pack\sounds" -Force | Out-Null
}

if ($ScriptDir) {
    # Local clone - copy files directly (including sounds)
    Write-Host "Installing from local clone..."
    Copy-Item -Path "$ScriptDir\packs\*" -Destination "$InstallDir\packs\" -Recurse -Force
    Copy-Item -Path "$ScriptDir\peon.ps1" -Destination "$InstallDir\" -Force
    Copy-Item -Path "$ScriptDir\VERSION" -Destination "$InstallDir\" -Force
    Copy-Item -Path "$ScriptDir\uninstall.ps1" -Destination "$InstallDir\" -Force
    if (-not $Updating) {
        Copy-Item -Path "$ScriptDir\config.json" -Destination "$InstallDir\" -Force
    }
} else {
    # Download from GitHub
    Write-Host "Downloading from GitHub..."

    $wc = New-Object System.Net.WebClient

    $wc.DownloadFile("$RepoBase/peon.ps1", "$InstallDir\peon.ps1")
    $wc.DownloadFile("$RepoBase/VERSION", "$InstallDir\VERSION")
    $wc.DownloadFile("$RepoBase/uninstall.ps1", "$InstallDir\uninstall.ps1")

    foreach ($pack in $Packs) {
        $wc.DownloadFile("$RepoBase/packs/$pack/manifest.json", "$InstallDir\packs\$pack\manifest.json")
    }

    # Download sound files for each pack
    foreach ($pack in $Packs) {
        $manifest = Get-Content "$InstallDir\packs\$pack\manifest.json" -Raw | ConvertFrom-Json
        $downloaded = @()
        foreach ($cat in $manifest.categories.PSObject.Properties) {
            foreach ($sound in $cat.Value.sounds) {
                $sfile = $sound.file
                if ($sfile -notin $downloaded) {
                    $downloaded += $sfile
                    $wc.DownloadFile("$RepoBase/packs/$pack/sounds/$sfile", "$InstallDir\packs\$pack\sounds\$sfile")
                }
            }
        }
    }

    if (-not $Updating) {
        $wc.DownloadFile("$RepoBase/config.json", "$InstallDir\config.json")
    }
}

# --- Install skill (slash command) ---
$SkillDir = "$env:USERPROFILE\.claude\skills\peon-ping-toggle"
New-Item -ItemType Directory -Path $SkillDir -Force | Out-Null

if ($ScriptDir -and (Test-Path "$ScriptDir\skills\peon-ping-toggle\SKILL.md")) {
    Copy-Item -Path "$ScriptDir\skills\peon-ping-toggle\SKILL.md" -Destination "$SkillDir\" -Force
} elseif (-not $ScriptDir) {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile("$RepoBase/skills/peon-ping-toggle/SKILL.md", "$SkillDir\SKILL.md")
} else {
    Write-Warning "Warning: skills/peon-ping-toggle not found in local clone, skipping skill install"
}

# --- Add PowerShell alias ---
$profilePath = $PROFILE
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$aliasLine = "function peon { & `"$InstallDir\peon.ps1`" @args }"
$profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue

if (-not $profileContent -or $profileContent -notmatch "function peon") {
    Add-Content -Path $profilePath -Value "`n# peon-ping quick controls"
    Add-Content -Path $profilePath -Value $aliasLine
    Write-Host "Added peon function to PowerShell profile"
}

# --- Verify sounds are installed ---
Write-Host ""
foreach ($pack in $Packs) {
    $soundDir = "$InstallDir\packs\$pack\sounds"
    $soundCount = (Get-ChildItem -Path $soundDir -Filter *.* -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in @('.wav','.mp3','.ogg') }).Count
    if ($soundCount -eq 0) {
        Write-Host "[$pack] Warning: No sound files found!"
    } else {
        Write-Host "[$pack] $soundCount sound files installed."
    }
}

# --- Backup existing notify.sh (fresh install only) ---
if (-not $Updating) {
    $notifyScript = "$env:USERPROFILE\.claude\hooks\notify.sh"
    if (Test-Path $notifyScript) {
        Copy-Item -Path $notifyScript -Destination "$notifyScript.backup" -Force
        Write-Host ""
        Write-Host "Backed up notify.sh -> notify.sh.backup"
    }
}

# --- Update settings.json ---
Write-Host ""
Write-Host "Updating Claude Code hooks in settings.json..."

$pythonUpdateScript = @"
import json, os

settings_path = r'$Settings'
hook_cmd = r'$InstallDir\peon.ps1'

# Load existing settings
if os.path.exists(settings_path):
    with open(settings_path, encoding='utf-8') as f:
        settings = json.load(f)
else:
    settings = {}

hooks = settings.setdefault('hooks', {})

peon_hook = {
    'type': 'command',
    'command': f'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{hook_cmd}"',
    'timeout': 10
}

peon_entry = {
    'matcher': '',
    'hooks': [peon_hook]
}

# Events to register
events = ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification', 'PermissionRequest']

for event in events:
    event_hooks = hooks.get(event, [])
    # Remove any existing notify.sh or peon entries
    event_hooks = [
        h for h in event_hooks
        if not any(
            'notify.sh' in hk.get('command', '') or
            'peon.sh' in hk.get('command', '') or
            'peon.ps1' in hk.get('command', '')
            for hk in h.get('hooks', [])
        )
    ]
    event_hooks.append(peon_entry)
    hooks[event] = event_hooks

settings['hooks'] = hooks

with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Hooks registered for: ' + ', '.join(events))
"@

& $pythonCmd -c $pythonUpdateScript

# --- Initialize state (fresh install only) ---
if (-not $Updating) {
    Set-Content -Path "$InstallDir\.state.json" -Value "{}"
}

# --- Test sound ---
Write-Host ""
Write-Host "Testing sound..."

$activePack = & $pythonCmd -c @"
import json, os
try:
    c = json.load(open(r'$InstallDir\config.json', encoding='utf-8'))
    print(c.get('active_pack', 'peon'))
except:
    print('peon')
"@

$packDir = "$InstallDir\packs\$activePack"
$testSound = Get-ChildItem -Path "$packDir\sounds" -Filter *.* -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.wav','.mp3','.ogg') } |
    Select-Object -First 1

if ($testSound) {
    Add-Type -AssemblyName PresentationCore
    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([Uri]::new($testSound.FullName))
    $player.Volume = 0.3
    Start-Sleep -Milliseconds 200
    $player.Play()
    Start-Sleep -Seconds 3
    $player.Close()
    Write-Host "Sound working!"
} else {
    Write-Warning "Warning: No sound files found. Sounds may not play."
}

Write-Host ""
if ($Updating) {
    Write-Host "=== Update complete! ==="
    Write-Host ""
    Write-Host "Updated: peon.ps1, manifest.json"
    Write-Host "Preserved: config.json, state"
} else {
    Write-Host "=== Installation complete! ==="
    Write-Host ""
    Write-Host "Config: $InstallDir\config.json"
    Write-Host "  - Adjust volume, toggle categories, switch packs"
    Write-Host ""
    Write-Host "Uninstall: powershell -ExecutionPolicy Bypass -File '$InstallDir\uninstall.ps1'"
}
Write-Host ""
Write-Host "Quick controls:"
Write-Host "  /peon-ping-toggle  - toggle sounds in Claude Code"
Write-Host "  peon --toggle      - toggle sounds from any terminal"
Write-Host "  peon --status      - check if sounds are paused"
Write-Host ""
Write-Host "Ready to work!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Restart your PowerShell terminal to use the peon command."
