# peon-ping: Warcraft III Peon voice lines for Claude Code hooks (Windows)
# Replaces notify.sh - handles sounds, tab titles, and notifications
param([string]$Command = "")

$ErrorActionPreference = "SilentlyContinue"

# --- Configuration paths ---
$PeonDir = if ($env:CLAUDE_PEON_DIR) { $env:CLAUDE_PEON_DIR } else { "$env:USERPROFILE\.claude\hooks\peon-ping" }
$ConfigFile = "$PeonDir\config.json"
$StateFile = "$PeonDir\.state.json"
$PausedFile = "$PeonDir\.paused"

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

# --- Platform-aware audio playback ---
function Play-Sound {
    param(
        [string]$File,
        [double]$Volume
    )

    # Use SoundPlayer instead of MediaPlayer - more reliable in background
    Start-Process powershell.exe -ArgumentList @(
        '-NoProfile',
        '-WindowStyle', 'Hidden',
        '-Command',
        "`$player = New-Object System.Media.SoundPlayer; `$player.SoundLocation = '$File'; `$player.Play()"
    ) -WindowStyle Hidden
}

# --- Platform-aware notification ---
function Send-Notification {
    param(
        [string]$Message,
        [string]$Title,
        [string]$Color = "red"
    )

    # Map color name to RGB
    $rgbR = 180; $rgbG = 0; $rgbB = 0
    switch ($Color) {
        "blue"   { $rgbR = 30;  $rgbG = 80;  $rgbB = 180 }
        "yellow" { $rgbR = 200; $rgbG = 160; $rgbB = 0   }
        "red"    { $rgbR = 180; $rgbG = 0;   $rgbB = 0   }
    }

    Start-Job -ScriptBlock {
        param($Msg, $R, $G, $B)
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # Claim a popup slot for vertical stacking
        $slotDir = "$env:TEMP\peon-ping-popups"
        if (-not (Test-Path $slotDir)) { New-Item -ItemType Directory -Path $slotDir | Out-Null }

        $slot = 0
        $slotPath = "$slotDir\slot-$slot"
        while (Test-Path $slotPath) {
            $slot++
            $slotPath = "$slotDir\slot-$slot"
        }
        New-Item -ItemType Directory -Path $slotPath | Out-Null

        $yOffset = 40 + ($slot * 90)

        foreach ($screen in [System.Windows.Forms.Screen]::AllScreens) {
            $form = New-Object System.Windows.Forms.Form
            $form.FormBorderStyle = 'None'
            $form.BackColor = [System.Drawing.Color]::FromArgb($R, $G, $B)
            $form.Size = New-Object System.Drawing.Size(500, 80)
            $form.TopMost = $true
            $form.ShowInTaskbar = $false
            $form.StartPosition = 'Manual'
            $form.Location = New-Object System.Drawing.Point(
                ($screen.WorkingArea.X + ($screen.WorkingArea.Width - 500) / 2),
                ($screen.WorkingArea.Y + $yOffset)
            )

            $label = New-Object System.Windows.Forms.Label
            $label.Text = $Msg
            $label.ForeColor = [System.Drawing.Color]::White
            $label.Font = New-Object System.Drawing.Font('Segoe UI', 16, [System.Drawing.FontStyle]::Bold)
            $label.TextAlign = 'MiddleCenter'
            $label.Dock = 'Fill'
            $form.Controls.Add($label)
            $form.Show()
        }

        Start-Sleep -Seconds 4
        [System.Windows.Forms.Application]::Exit()
        Remove-Item -Path $slotPath -Force -Recurse
    } -ArgumentList $Message, $rgbR, $rgbG, $rgbB | Out-Null
}

# --- Terminal focus check ---
function Test-TerminalFocused {
    # Check if Windows Terminal, ConEmu, or other terminal is in focus
    try {
        Add-Type @"
            using System;
            using System.Runtime.InteropServices;
            using System.Text;
            public class WindowHelper {
                [DllImport("user32.dll")]
                public static extern IntPtr GetForegroundWindow();
                [DllImport("user32.dll")]
                public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
                [DllImport("user32.dll")]
                public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
            }
"@ -ErrorAction SilentlyContinue

        $handle = [WindowHelper]::GetForegroundWindow()
        $title = New-Object System.Text.StringBuilder 256
        [WindowHelper]::GetWindowText($handle, $title, 256) | Out-Null
        $titleStr = $title.ToString()

        # Get process name
        $processId = 0
        [WindowHelper]::GetWindowThreadProcessId($handle, [ref]$processId) | Out-Null
        $processName = ""
        if ($processId -gt 0) {
            try {
                $processName = (Get-Process -Id $processId -ErrorAction SilentlyContinue).ProcessName
            } catch {}
        }

        # Check for common terminal titles and process names
        $terminalPatterns = @(
            "Windows Terminal", "PowerShell", "cmd", "ConEmu", "Cmder",
            "Alacritty", "WezTerm", "Hyper", "Terminus", "Fluent Terminal",
            "mintty", "WindowsTerminal", "Code", "Visual Studio Code"
        )

        foreach ($pattern in $terminalPatterns) {
            if ($titleStr -like "*$pattern*" -or $processName -like "*$pattern*") {
                return $true
            }
        }
    } catch {
        # If focus detection fails, assume not focused to show notifications
    }
    return $false
}

# --- CLI subcommands ---
switch ($Command) {
    "--pause" {
        New-Item -ItemType File -Path $PausedFile -Force | Out-Null
        Write-Host "peon-ping: sounds paused"
        exit 0
    }
    "--resume" {
        if (Test-Path $PausedFile) { Remove-Item $PausedFile -Force }
        Write-Host "peon-ping: sounds resumed"
        exit 0
    }
    "--toggle" {
        if (Test-Path $PausedFile) {
            Remove-Item $PausedFile -Force
            Write-Host "peon-ping: sounds resumed"
        } else {
            New-Item -ItemType File -Path $PausedFile -Force | Out-Null
            Write-Host "peon-ping: sounds paused"
        }
        exit 0
    }
    "--status" {
        if (Test-Path $PausedFile) {
            Write-Host "peon-ping: paused"
        } else {
            Write-Host "peon-ping: active"
        }
        exit 0
    }
    "--packs" {
        & $pythonCmd -c @"
import json, os, glob
config_path = r'$ConfigFile'
try:
    active = json.load(open(config_path)).get('active_pack', 'peon')
except:
    active = 'peon'
packs_dir = r'$PeonDir\packs'
for m in sorted(glob.glob(os.path.join(packs_dir, '*/manifest.json'))):
    info = json.load(open(m))
    name = info.get('name', os.path.basename(os.path.dirname(m)))
    display = info.get('display_name', name)
    marker = ' *' if name == active else ''
    print(f'  {name:24s} {display}{marker}')
"@
        exit 0
    }
    "--pack" {
        $packArg = $args[0]
        if (-not $packArg) {
            # Cycle to next pack
            & $pythonCmd -c @"
import json, os, glob
config_path = r'$ConfigFile'
try:
    cfg = json.load(open(config_path))
except:
    cfg = {}
active = cfg.get('active_pack', 'peon')
packs_dir = r'$PeonDir\packs'
names = sorted([
    os.path.basename(os.path.dirname(m))
    for m in glob.glob(os.path.join(packs_dir, '*/manifest.json'))
])
if not names:
    print('Error: no packs found', flush=True)
    raise SystemExit(1)
try:
    idx = names.index(active)
    next_pack = names[(idx + 1) % len(names)]
except ValueError:
    next_pack = names[0]
cfg['active_pack'] = next_pack
json.dump(cfg, open(config_path, 'w'), indent=2)
mpath = os.path.join(packs_dir, next_pack, 'manifest.json')
display = json.load(open(mpath)).get('display_name', next_pack)
print(f'peon-ping: switched to {next_pack} ({display})')
"@
        } else {
            & $pythonCmd -c @"
import json, os, glob, sys
config_path = r'$ConfigFile'
pack_arg = '$packArg'
packs_dir = r'$PeonDir\packs'
names = sorted([
    os.path.basename(os.path.dirname(m))
    for m in glob.glob(os.path.join(packs_dir, '*/manifest.json'))
])
if pack_arg not in names:
    print(f'Error: pack "{pack_arg}" not found.', file=sys.stderr)
    print(f'Available packs: {", ".join(names)}', file=sys.stderr)
    sys.exit(1)
try:
    cfg = json.load(open(config_path))
except:
    cfg = {}
cfg['active_pack'] = pack_arg
json.dump(cfg, open(config_path, 'w'), indent=2)
mpath = os.path.join(packs_dir, pack_arg, 'manifest.json')
display = json.load(open(mpath)).get('display_name', pack_arg)
print(f'peon-ping: switched to {pack_arg} ({display})')
"@
        }
        exit 0
    }
    { $_ -in @("--help", "-h") } {
        Write-Host @"
Usage: peon <command>

Commands:
  --pause        Mute sounds
  --resume       Unmute sounds
  --toggle       Toggle mute on/off
  --status       Check if paused or active
  --packs        List available sound packs
  --pack <name>  Switch to a specific pack
  --pack         Cycle to the next pack
  --help         Show this help
"@
        exit 0
    }
    default {
        if ($Command -match "^--") {
            Write-Error "Unknown option: $Command"
            Write-Error "Run 'peon --help' for usage."
            exit 1
        }
    }
}

# --- Read input from stdin ---
$input = [Console]::In.ReadToEnd()
if (-not $input) { exit 0 }

# Check if paused
$paused = Test-Path $PausedFile

# --- Single Python call: config, event parsing, agent detection, category routing, sound picking ---
$pythonScript = @"
import sys, json, os, re, random, time
import io

# Set stdout to UTF-8
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

config_path = r'$ConfigFile'
state_file = r'$StateFile'
peon_dir = r'$PeonDir'
paused = '$($paused.ToString().ToLower())' == 'true'
agent_modes = {'delegate'}
state_dirty = False

# --- Load config ---
try:
    cfg = json.load(open(config_path, encoding='utf-8'))
except:
    cfg = {}

if str(cfg.get('enabled', True)).lower() == 'false':
    print('PEON_EXIT=true')
    sys.exit(0)

volume = cfg.get('volume', 0.5)
active_pack = cfg.get('active_pack', 'peon')
pack_rotation = cfg.get('pack_rotation', [])
annoyed_threshold = int(cfg.get('annoyed_threshold', 3))
annoyed_window = float(cfg.get('annoyed_window_seconds', 10))
cats = cfg.get('categories', {})
cat_enabled = {}
for c in ['greeting','acknowledge','complete','error','permission','resource_limit','annoyed']:
    cat_enabled[c] = str(cats.get(c, True)).lower() == 'true'

# --- Parse event JSON from stdin ---
try:
    event_data = json.loads(sys.stdin.read())
except:
    print('PEON_EXIT=true')
    sys.exit(0)

event = event_data.get('hook_event_name', '')
ntype = event_data.get('notification_type', '')
cwd = event_data.get('cwd', '')
session_id = event_data.get('session_id', '')
perm_mode = event_data.get('permission_mode', '')

# --- Load state ---
try:
    state = json.load(open(state_file, encoding='utf-8'))
except:
    state = {}

# --- Agent detection ---
agent_sessions = set(state.get('agent_sessions', []))
if perm_mode and perm_mode in agent_modes:
    agent_sessions.add(session_id)
    state['agent_sessions'] = list(agent_sessions)
    state_dirty = True
    print('PEON_EXIT=true')
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    with open(state_file, 'w', encoding='utf-8') as f:
        json.dump(state, f)
    sys.exit(0)
elif session_id in agent_sessions:
    print('PEON_EXIT=true')
    sys.exit(0)

# --- Pack rotation: pin a random pack per session ---
if pack_rotation:
    session_packs = state.get('session_packs', {})
    if session_id in session_packs and session_packs[session_id] in pack_rotation:
        active_pack = session_packs[session_id]
    else:
        active_pack = random.choice(pack_rotation)
        session_packs[session_id] = active_pack
        state['session_packs'] = session_packs
        state_dirty = True

# --- Project name ---
project = cwd.split('\\')[-1] if cwd else 'claude'
if not project:
    project = 'claude'
project = re.sub(r'[^a-zA-Z0-9 ._-]', '', project)

# --- Event routing ---
category = ''
status = ''
marker = ''
notify = ''
notify_color = ''
msg = ''

if event == 'SessionStart':
    category = 'greeting'
    status = 'ready'
elif event == 'UserPromptSubmit':
    status = 'working'
    if cat_enabled.get('annoyed', True):
        all_ts = state.get('prompt_timestamps', {})
        if isinstance(all_ts, list):
            all_ts = {}
        now = time.time()
        ts = [t for t in all_ts.get(session_id, []) if now - t < annoyed_window]
        ts.append(now)
        all_ts[session_id] = ts
        state['prompt_timestamps'] = all_ts
        state_dirty = True
        if len(ts) >= annoyed_threshold:
            category = 'annoyed'
elif event == 'Stop':
    category = 'complete'
    status = 'done'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'blue'
    msg = project + '  \u2014  Task complete'
elif event == 'Notification':
    if ntype == 'permission_prompt':
        category = 'permission'
        status = 'needs approval'
        marker = '\u25cf '
        notify = '1'
        notify_color = 'red'
        msg = project + '  \u2014  Permission needed'
    elif ntype == 'idle_prompt':
        status = 'done'
        marker = '\u25cf '
        notify = '1'
        notify_color = 'yellow'
        msg = project + '  \u2014  Waiting for input'
    else:
        print('PEON_EXIT=true')
        sys.exit(0)
elif event == 'PermissionRequest':
    category = 'permission'
    status = 'needs approval'
    marker = '\u25cf '
    notify = '1'
    notify_color = 'red'
    msg = project + '  \u2014  Permission needed'
else:
    print('PEON_EXIT=true')
    sys.exit(0)

# --- Check if category is enabled ---
if category and not cat_enabled.get(category, True):
    category = ''

# --- Pick sound (skip if no category or paused) ---
sound_file = ''
if category and not paused:
    pack_dir = os.path.join(peon_dir, 'packs', active_pack)
    try:
        manifest = json.load(open(os.path.join(pack_dir, 'manifest.json'), encoding='utf-8'))
        sounds = manifest.get('categories', {}).get(category, {}).get('sounds', [])
        if sounds:
            last_played = state.get('last_played', {})
            last_file = last_played.get(category, '')
            candidates = sounds if len(sounds) <= 1 else [s for s in sounds if s['file'] != last_file]
            pick = random.choice(candidates)
            last_played[category] = pick['file']
            state['last_played'] = last_played
            state_dirty = True
            sound_file = os.path.join(pack_dir, 'sounds', pick['file'])
    except:
        pass

# --- Write state once ---
if state_dirty:
    os.makedirs(os.path.dirname(state_file) or '.', exist_ok=True)
    with open(state_file, 'w', encoding='utf-8') as f:
        json.dump(state, f)

# --- Output JSON for PowerShell ---
output = {
    'exit': False,
    'event': event,
    'volume': volume,
    'project': project,
    'status': status,
    'marker': marker,
    'notify': notify,
    'notify_color': notify_color,
    'msg': msg,
    'sound_file': sound_file
}
print(json.dumps(output, ensure_ascii=False))
"@

$result = $input | & $pythonCmd -c $pythonScript 2>$null
if (-not $result) { exit 0 }

$output = $result | ConvertFrom-Json

# If Python signalled early exit
if ($output.exit) { exit 0 }

# --- Check for updates (SessionStart only, once per day, non-blocking) ---
if ($output.event -eq "SessionStart") {
    Start-Job -ScriptBlock {
        param($Dir)
        $checkFile = "$Dir\.last_update_check"
        $now = [int][double]::Parse((Get-Date -UFormat %s))
        $lastCheck = 0
        if (Test-Path $checkFile) {
            $lastCheck = [int](Get-Content $checkFile -ErrorAction SilentlyContinue)
        }
        $elapsed = $now - $lastCheck
        if ($elapsed -gt 86400) {
            Set-Content -Path $checkFile -Value $now
            $localVersion = ""
            if (Test-Path "$Dir\VERSION") {
                $localVersion = (Get-Content "$Dir\VERSION" -Raw).Trim()
            }
            try {
                $remoteVersion = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/tonyyont/peon-ping/main/VERSION" -TimeoutSec 5 -ErrorAction Stop).Content.Trim()
                if ($remoteVersion -and $localVersion -and $remoteVersion -ne $localVersion) {
                    Set-Content -Path "$Dir\.update_available" -Value $remoteVersion
                } else {
                    Remove-Item "$Dir\.update_available" -Force -ErrorAction SilentlyContinue
                }
            } catch {}
        }
    } -ArgumentList $PeonDir | Out-Null
}

# --- Show update notice ---
if ($output.event -eq "SessionStart" -and (Test-Path "$PeonDir\.update_available")) {
    $newVer = (Get-Content "$PeonDir\.update_available" -Raw -ErrorAction SilentlyContinue).Trim()
    $curVer = ""
    if (Test-Path "$PeonDir\VERSION") {
        $curVer = (Get-Content "$PeonDir\VERSION" -Raw -ErrorAction SilentlyContinue).Trim()
    }
    if ($newVer) {
        Write-Host "peon-ping update available: $curVer -> $newVer - run: powershell -c `"irm https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.ps1 | iex`"" -ForegroundColor Yellow
    }
}

# --- Show pause status ---
if ($output.event -eq "SessionStart" -and $paused) {
    Write-Host "peon-ping: sounds paused - run 'peon --resume' or '/peon-ping-toggle' to unpause" -ForegroundColor Yellow
}

# --- Build tab title ---
$title = "$($output.marker)$($output.project): $($output.status)"

# --- Set tab title via ANSI escape ---
if ($title) {
    Write-Host "`e]0;$title`a" -NoNewline
}

# --- Play sound ---
if ($output.sound_file -and (Test-Path $output.sound_file)) {
    Play-Sound -File $output.sound_file -Volume $output.volume
}

# --- Smart notification: only when terminal is NOT frontmost ---
if ($output.notify -and -not $paused) {
    if (-not (Test-TerminalFocused)) {
        Send-Notification -Message $output.msg -Title $title -Color $output.notify_color
    }
}

# Wait for background jobs to complete
Get-Job | Wait-Job -Timeout 5 | Out-Null
Get-Job | Remove-Job -Force
exit 0
