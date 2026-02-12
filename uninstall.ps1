# peon-ping uninstaller for Windows
# Removes peon hooks and optionally restores notify.sh

$ErrorActionPreference = "Stop"

$InstallDir = "$env:USERPROFILE\.claude\hooks\peon-ping"
$Settings = "$env:USERPROFILE\.claude\settings.json"
$NotifyBackup = "$env:USERPROFILE\.claude\hooks\notify.sh.backup"
$NotifyScript = "$env:USERPROFILE\.claude\hooks\notify.sh"

# --- Find Python executable ---
$pythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) {
    $pythonCmd = "python"
} elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonCmd = "python3"
} else {
    Write-Error "Error: python is required"
    exit 1
}

Write-Host "=== peon-ping uninstaller ==="
Write-Host ""

# --- Remove hook entries from settings.json ---
if (Test-Path $Settings) {
    Write-Host "Removing peon hooks from settings.json..."

    $pythonScript = @"
import json, os

settings_path = r'$Settings'
with open(settings_path, encoding='utf-8') as f:
    settings = json.load(f)

hooks = settings.get('hooks', {})
events_cleaned = []

for event, entries in list(hooks.items()):
    original_count = len(entries)
    entries = [
        h for h in entries
        if not any(
            'peon.ps1' in hk.get('command', '')
            for hk in h.get('hooks', [])
        )
    ]
    if len(entries) < original_count:
        events_cleaned.append(event)
    if entries:
        hooks[event] = entries
    else:
        del hooks[event]

settings['hooks'] = hooks

with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

if events_cleaned:
    print('Removed hooks for: ' + ', '.join(events_cleaned))
else:
    print('No peon hooks found in settings.json')
"@

    & $pythonCmd -c $pythonScript
}

# --- Restore notify.sh backup ---
if (Test-Path $NotifyBackup) {
    Write-Host ""
    $response = Read-Host "Restore original notify.sh from backup? [Y/n]"
    if ($response -ne 'n' -and $response -ne 'N') {
        # Re-register notify.sh for its original events
        $pythonScript = @"
import json

settings_path = r'$Settings'
with open(settings_path, encoding='utf-8') as f:
    settings = json.load(f)

hooks = settings.setdefault('hooks', {})
notify_hook = {
    'matcher': '',
    'hooks': [{
        'type': 'command',
        'command': r'$NotifyScript',
        'timeout': 10
    }]
}

for event in ['SessionStart', 'UserPromptSubmit', 'Stop', 'Notification']:
    event_hooks = hooks.get(event, [])
    # Don't add if already present
    has_notify = any(
        'notify.sh' in hk.get('command', '')
        for h in event_hooks
        for hk in h.get('hooks', [])
    )
    if not has_notify:
        event_hooks.append(notify_hook)
    hooks[event] = event_hooks

settings['hooks'] = hooks
with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2)
    f.write('\n')

print('Restored notify.sh hooks for: SessionStart, UserPromptSubmit, Stop, Notification')
"@

        & $pythonCmd -c $pythonScript
        Copy-Item -Path $NotifyBackup -Destination $NotifyScript -Force
        Remove-Item -Path $NotifyBackup -Force
        Write-Host "notify.sh restored"
    }
}

# --- Remove install directory ---
if (Test-Path $InstallDir) {
    Write-Host ""
    Write-Host "Removing $InstallDir..."
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Host "Removed"
}

# --- Remove PowerShell profile alias ---
$profilePath = $PROFILE
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath -Raw
    if ($content -match "peon-ping") {
        $newContent = $content -replace "(?m)^# peon-ping quick controls\r?\n.*peon.*\r?\n?", ""
        Set-Content -Path $profilePath -Value $newContent -NoNewline
        Write-Host "Removed peon alias from PowerShell profile"
    }
}

Write-Host ""
Write-Host "=== Uninstall complete ===" -ForegroundColor Green
Write-Host "Me go now."
