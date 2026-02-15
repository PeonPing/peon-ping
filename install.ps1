# peon-ping Windows Installer
# Native Windows port - plays Warcraft III Peon sounds when Claude Code needs attention
# Usage: powershell -ExecutionPolicy Bypass -File install.ps1
# Originally made by https://github.com/SpamsRevenge in https://github.com/PeonPing/peon-ping/issues/94

param(
    [Parameter()]
    $Packs = @(),
    [switch]$All
)

# When run via Invoke-Expression (one-liner install), $PSScriptRoot is empty.
# Fall back to current directory so Join-Path calls don't receive an empty string.
$ScriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.Path }

$ErrorActionPreference = "Stop"

# --- Input validation (mirrors install.sh safety checks) ---
function Test-SafePackName($n)    { $n -match '^[A-Za-z0-9._-]+$' }
function Test-SafeSourceRepo($n)  { $n -match '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' }
function Test-SafeSourceRef($n)   { $n -match '^[A-Za-z0-9._/-]+$' -and $n -notmatch '\.\.' -and $n[0] -ne '/' }
function Test-SafeSourcePath($n)  { $n -match '^[A-Za-z0-9._/-]+$' -and $n -notmatch '\.\.' -and $n[0] -ne '/' }
function Test-SafeFilename($n)    { $n -match '^[A-Za-z0-9._-]+$' }

# --- Fallback pack list (used when registry is unreachable) ---
$FallbackPacks = @("acolyte_de", "acolyte_ru", "aoe2", "aom_greek", "brewmaster_ru", "dota2_axe", "duke_nukem", "glados", "hd2_helldiver", "molag_bal", "murloc", "ocarina_of_time", "peon", "peon_cz", "peon_de", "peon_es", "peon_fr", "peon_pl", "peon_ru", "peasant", "peasant_cz", "peasant_es", "peasant_fr", "peasant_ru", "ra2_kirov", "ra2_soviet_engineer", "ra_soviet", "rick", "sc_battlecruiser", "sc_firebat", "sc_kerrigan", "sc_medic", "sc_scv", "sc_tank", "sc_terran", "sc_vessel", "sheogorath", "sopranos", "tf2_engineer", "wc2_peasant")
$FallbackRepo = "PeonPing/og-packs"
$FallbackRef = "v1.1.0"

Write-Host "=== peon-ping Windows installer ===" -ForegroundColor Cyan
Write-Host ""


# --- Paths ---
$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$InstallDir = Join-Path $ClaudeDir "hooks\peon-ping"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$RegistryUrl = "https://peonping.github.io/registry/index.json"
$RepoBase = "https://raw.githubusercontent.com/PeonPing/peon-ping/main"

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
    Write-Host "  Warning: Could not fetch registry, using fallback pack list" -ForegroundColor Yellow
    $registry = [PSCustomObject]@{
        packs = $FallbackPacks | ForEach-Object {
            [PSCustomObject]@{ name = $_; source_repo = $FallbackRepo; source_ref = $FallbackRef; source_path = $_ }
        }
    }
}

# --- Decide which packs to download ---
$packsToInstall = @()
if ($Packs -and $Packs.Count -gt 0) {
    # Custom pack list (accepts array or comma-separated string)
    $customPackNames = @()
    if ($Packs -is [array]) {
        $customPackNames = $Packs | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }
    } else {
        $customPackNames = $Packs.ToString() -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    $packsToInstall = $registry.packs | Where-Object { $_.name -in $customPackNames }
    Write-Host "  Installing custom packs: $($customPackNames -join ', ')" -ForegroundColor Cyan
} elseif ($All) {
    $packsToInstall = $registry.packs
    Write-Host "  Installing ALL $($packsToInstall.Count) packs..." -ForegroundColor Cyan
} else {
    # Default: install a curated set of popular packs
    $defaultPacks = @("peon", "peasant", "glados", "sc_kerrigan", "sc_battlecruiser", "ra2_kirov", "dota2_axe", "duke_nukem", "tf2_engineer", "hd2_helldiver")
    $packsToInstall = $registry.packs | Where-Object { $_.name -in $defaultPacks }
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
    if (-not (Test-SafePackName $packName)) {
        Write-Host "  Warning: skipping invalid pack name: $packName" -ForegroundColor Yellow
        $failedPacks++
        continue
    }

    $sourceRepo = $packInfo.source_repo
    $sourceRef = $packInfo.source_ref
    $sourcePath = $packInfo.source_path

    # Validate source metadata; fall back to default repo if invalid
    if (-not $sourceRepo -or -not (Test-SafeSourceRepo $sourceRepo)) { $sourceRepo = "" }
    if (-not $sourceRef -or -not (Test-SafeSourceRef $sourceRef)) { $sourceRef = "" }
    if (-not $sourcePath -or -not (Test-SafeSourcePath $sourcePath)) { $sourcePath = "" }
    if (-not $sourceRepo -or -not $sourceRef -or -not $sourcePath) {
        $sourceRepo = $FallbackRepo
        $sourceRef = $FallbackRef
        $sourcePath = $packName
    }

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
            if (-not (Test-SafeFilename $sfile)) {
                Write-Host "  Warning: skipped unsafe filename in ${packName}: $sfile" -ForegroundColor Yellow
                continue
            }
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
    # Set active pack to first installed pack
    $firstPack = if ($packsToInstall.Count -gt 0) { $packsToInstall[0].name } else { "peon" }

    $config = @{
        active_pack = $firstPack
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
    Set-Content -Path $configPath -Value $config -Encoding UTF8
}

# --- Install state ---
$statePath = Join-Path $InstallDir ".state.json"
if (-not $Updating) {
    Set-Content -Path $statePath -Value "{}" -Encoding UTF8
}

# --- Install helper scripts ---
$scriptsDir = Join-Path $InstallDir "scripts"
New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

$winPlaySource = Join-Path $ScriptDir "scripts\win-play.ps1"
$winPlayTarget = Join-Path $scriptsDir "win-play.ps1"

if (Test-Path $winPlaySource) {
    # Local install: copy from repo
    Copy-Item -Path $winPlaySource -Destination $winPlayTarget -Force
} else {
    # One-liner install: download from GitHub
    try {
        Invoke-WebRequest -Uri "$RepoBase/scripts/win-play.ps1" -OutFile $winPlayTarget -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  Warning: Could not download win-play.ps1" -ForegroundColor Yellow
    }
}

# Install hook-handle-use scripts (for /peon-ping-use command)
$hookHandleUsePs1Source = Join-Path $ScriptDir "scripts\hook-handle-use.ps1"
$hookHandleUsePs1Target = Join-Path $scriptsDir "hook-handle-use.ps1"
$hookHandleUseShSource = Join-Path $ScriptDir "scripts\hook-handle-use.sh"
$hookHandleUseShTarget = Join-Path $scriptsDir "hook-handle-use.sh"

if (Test-Path $hookHandleUsePs1Source) {
    # Local install: copy from repo
    Copy-Item -Path $hookHandleUsePs1Source -Destination $hookHandleUsePs1Target -Force
    Copy-Item -Path $hookHandleUseShSource -Destination $hookHandleUseShTarget -Force
} else {
    # One-liner install: download from GitHub
    try {
        Invoke-WebRequest -Uri "$RepoBase/scripts/hook-handle-use.ps1" -OutFile $hookHandleUsePs1Target -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  Warning: Could not download hook-handle-use.ps1" -ForegroundColor Yellow
    }
    try {
        Invoke-WebRequest -Uri "$RepoBase/scripts/hook-handle-use.sh" -OutFile $hookHandleUseShTarget -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  Warning: Could not download hook-handle-use.sh" -ForegroundColor Yellow
    }
}

# --- Install the main hook script (PowerShell) ---
$hookScript = @'
# peon-ping hook for Claude Code (Windows native)
# Called by Claude Code hooks on SessionStart, Stop, Notification, PermissionRequest, UserPromptSubmit

param(
    [string]$Command = "",
    [string]$Arg1 = ""
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
            Set-Content $ConfigPath -Value $raw -Encoding UTF8
            $state = if ($newState) { "ENABLED" } else { "PAUSED" }
            Write-Host "peon-ping: $state" -ForegroundColor Cyan
            return
        }
        "^--pause$" {
            $raw = Get-Content $ConfigPath -Raw
            $raw = $raw -replace '"enabled"\s*:\s*(true|false)', '"enabled": false'
            Set-Content $ConfigPath -Value $raw -Encoding UTF8
            Write-Host "peon-ping: PAUSED" -ForegroundColor Yellow
            return
        }
        "^--resume$" {
            $raw = Get-Content $ConfigPath -Raw
            $raw = $raw -replace '"enabled"\s*:\s*(true|false)', '"enabled": true'
            Set-Content $ConfigPath -Value $raw -Encoding UTF8
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

            if ($Arg1) {
                $newPack = $Arg1
            } else {
                $idx = [array]::IndexOf($available, $cfg.active_pack)
                $newPack = $available[($idx + 1) % $available.Count]
            }

            $raw = Get-Content $ConfigPath -Raw
            $raw = $raw -replace '"active_pack"\s*:\s*"[^"]*"', "`"active_pack`": `"$newPack`""
            Set-Content $ConfigPath -Value $raw -Encoding UTF8
            Write-Host "peon-ping: switched to '$newPack'" -ForegroundColor Green
            return
        }
        "^--volume$" {
            if ($Arg1) {
                $vol = [math]::Max(0, [math]::Min(1, [double]$Arg1))
                $raw = Get-Content $ConfigPath -Raw
                $raw = $raw -replace '"volume"\s*:\s*[\d.]+', "`"volume`": $vol"
                Set-Content $ConfigPath -Value $raw -Encoding UTF8
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

# Extract session ID (Claude Code: session_id, Cursor: conversation_id)
$sessionId = if ($event.session_id) { $event.session_id } elseif ($event.conversation_id) { $event.conversation_id } else { "default" }

# Helper function to convert PSCustomObject to hashtable (PS 5.1 compat)
function ConvertTo-Hashtable {
    param([Parameter(ValueFromPipeline)]$obj)
    if ($obj -is [hashtable]) { return $obj }
    if ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    if ($obj -is [PSCustomObject]) {
        $ht = @{}
        foreach ($prop in $obj.PSObject.Properties) {
            $ht[$prop.Name] = ConvertTo-Hashtable $prop.Value
        }
        return $ht
    }
    return $obj
}

# Read state
$state = @{}
try {
    if (Test-Path $StatePath) {
        $stateObj = Get-Content $StatePath -Raw | ConvertFrom-Json
        $state = ConvertTo-Hashtable $stateObj
    }
} catch {
    $state = @{}
}

# --- Session cleanup: expire old sessions ---
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$ttlDays = if ($config.session_ttl_days) { $config.session_ttl_days } else { 7 }
$cutoff = $now - ($ttlDays * 86400)
$sessionPacks = if ($state.ContainsKey("session_packs")) { $state["session_packs"] } else { @{} }
$sessionPacksClean = @{}
foreach ($sid in $sessionPacks.Keys) {
    $packData = $sessionPacks[$sid]
    if ($packData -is [hashtable]) {
        # New format with timestamp
        $lastUsed = if ($packData.ContainsKey("last_used")) { $packData["last_used"] } else { 0 }
        if ($lastUsed -gt $cutoff) {
            if ($sid -eq $sessionId) {
                $packData["last_used"] = $now
            }
            $sessionPacksClean[$sid] = $packData
        }
    } elseif ($sid -eq $sessionId) {
        # Old format, upgrade active session
        $sessionPacksClean[$sid] = @{ pack = $packData; last_used = $now }
    } elseif ($packData -is [string]) {
        # Old format for inactive sessions - keep for now (migration path)
        $sessionPacksClean[$sid] = $packData
    }
}
$state["session_packs"] = $sessionPacksClean
$stateDirty = $false
if ($sessionPacksClean.Count -ne $sessionPacks.Count) {
    $stateDirty = $true
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
            # Other notification types (e.g., tool results) map to task.complete
            $category = "task.complete"
        }
    }
    "PermissionRequest" {
        $category = "input.required"
    }
    "UserPromptSubmit" {
        # Detect rapid prompts for "annoyed" easter egg
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
    $state | ConvertTo-Json -Depth 3 | Set-Content $StatePath -Encoding UTF8
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
$rotationMode = $config.pack_rotation_mode
if (-not $rotationMode) { $rotationMode = "random" }

if ($rotationMode -eq "agentskill") {
    # Explicit per-session assignments (from skill)
    $sessionPacks = $state.session_packs
    if (-not $sessionPacks) { $sessionPacks = @{} }
    if ($sessionPacks.ContainsKey($sessionId) -and $sessionPacks[$sessionId]) {
        $packData = $sessionPacks[$sessionId]
        # Handle both old string format and new dict format
        if ($packData -is [hashtable]) {
            $candidate = $packData.pack
        } else {
            $candidate = $packData
        }
        $candidateDir = Join-Path $InstallDir "packs\$candidate"
        if ($candidate -and (Test-Path $candidateDir -PathType Container)) {
            $activePack = $candidate
            # Update timestamp
            $sessionPacks[$sessionId] = @{ pack = $candidate; last_used = [int][double]::Parse((Get-Date -UFormat %s)) }
            $state.session_packs = $sessionPacks
            $stateDirty = $true
        } else {
            # Pack missing, use default and clean up
            $activePack = $config.active_pack
            if (-not $activePack) { $activePack = "peon" }
            $sessionPacks.Remove($sessionId)
            $state.session_packs = $sessionPacks
            $stateDirty = $true
        }
    } else {
        # No assignment: check session_packs["default"] (Cursor users without conversation_id)
        $defaultData = $sessionPacks.default
        if ($defaultData) {
            $candidate = if ($defaultData -is [hashtable]) { $defaultData.pack } else { $defaultData }
            $candidateDir = Join-Path $InstallDir "packs\$candidate"
            if ($candidate -and (Test-Path $candidateDir -PathType Container)) {
                $activePack = $candidate
            } else {
                $activePack = $config.active_pack
                if (-not $activePack) { $activePack = "peon" }
            }
        } else {
            $activePack = $config.active_pack
            if (-not $activePack) { $activePack = "peon" }
        }
    }
} elseif ($config.pack_rotation -and $config.pack_rotation.Count -gt 0) {
    # Automatic rotation
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
    $state | ConvertTo-Json -Depth 3 | Set-Content $StatePath -Encoding UTF8
} catch {}

# --- Play the sound (async) ---
$volume = $config.volume
if (-not $volume) { $volume = 0.5 }

# Use win-play.ps1 script
$winPlayScript = Join-Path $InstallDir "scripts\win-play.ps1"
if (Test-Path $winPlayScript) {
    $null = Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$winPlayScript,"-path",$soundPath,"-vol",$volume
}

exit 0
'@

$hookScriptPath = Join-Path $InstallDir "peon.ps1"
Set-Content -Path $hookScriptPath -Value $hookScript -Encoding UTF8

# --- Install CLI shortcut ---
$peonCli = @"
@echo off
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& '%USERPROFILE%\.claude\hooks\peon-ping\peon.ps1' %*"
"@
$cliBinDir = Join-Path $env:USERPROFILE ".local\bin"
if (-not (Test-Path $cliBinDir)) {
    New-Item -ItemType Directory -Path $cliBinDir -Force | Out-Null
}
$cliBatPath = Join-Path $cliBinDir "peon.cmd"
# Use UTF-8 without BOM to support special characters while avoiding BOM issues
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines($cliBatPath, $peonCli.Split("`n"), $utf8NoBom)

# Also create a bash-compatible script for Git Bash / WSL
# Use the actual Windows path (resolved at install time) to avoid path translation issues
$peonPs1Path = Join-Path $InstallDir "peon.ps1"
$peonShScript = @"
#!/usr/bin/env bash
# peon-ping CLI wrapper for Git Bash / WSL / Unix shells on Windows
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "& '$peonPs1Path' `$*"
"@
$peonShPath = Join-Path $cliBinDir "peon"
[System.IO.File]::WriteAllLines($peonShPath, $peonShScript.Split("`n"), $utf8NoBom)
# Make executable (for Git Bash)
if (Get-Command "icacls" -ErrorAction SilentlyContinue) {
    icacls $peonShPath /grant:r "$env:USERNAME:(RX)" | Out-Null
}

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

# Load settings as PSCustomObject (not hashtable) to preserve all existing
# values — arrays, strings, nested objects — without corruption.
# Previous approach used ConvertTo-Hashtable which mangled string arrays
# (e.g. permissions.allow entries became {Length: N}) and empty arrays
# became empty objects.
$settings = [PSCustomObject]@{}
if (Test-Path $SettingsFile) {
    try {
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json
    } catch {
        $settings = [PSCustomObject]@{}
    }
}

# Ensure hooks property exists
if (-not ($settings | Get-Member -Name "hooks" -MemberType NoteProperty)) {
    $settings | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{})
}

# Build the peon hook entry as PSCustomObject (not hashtable)
$peonHook = [PSCustomObject]@{
    type = "command"
    command = $hookCmd
    timeout = 10
}

$peonEntry = [PSCustomObject]@{
    matcher = ""
    hooks = @($peonHook)
}

$events = @("SessionStart", "UserPromptSubmit", "Stop", "Notification", "PermissionRequest")

foreach ($evt in $events) {
    $eventHooks = @()
    if ($settings.hooks | Get-Member -Name $evt -MemberType NoteProperty) {
        # Remove existing peon entries, keep others
        $eventHooks = @($settings.hooks.$evt | Where-Object {
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

    if ($settings.hooks | Get-Member -Name $evt -MemberType NoteProperty) {
        $settings.hooks.$evt = $eventHooks
    } else {
        $settings.hooks | Add-Member -NotePropertyName $evt -NotePropertyValue $eventHooks
    }
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
Write-Host "  Hooks registered for: $($events -join ', ')" -ForegroundColor Green

# --- Register UserPromptSubmit hook for /peon-ping-use command ---
# (Claude Code uses UserPromptSubmit; Cursor uses beforeSubmitPrompt — see below)
Write-Host "  Registering UserPromptSubmit hook for /peon-ping-use..."

$beforeSubmitHookPath = Join-Path $InstallDir "scripts\hook-handle-use.ps1"
$beforeSubmitCmd = "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$beforeSubmitHookPath`""

# Reload settings to ensure we have the latest
$settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json

$beforeSubmitHook = [PSCustomObject]@{
    type = "command"
    command = $beforeSubmitCmd
    timeout = 5
}

$beforeSubmitEntry = [PSCustomObject]@{
    matcher = ""
    hooks = @($beforeSubmitHook)
}

# Register under UserPromptSubmit (valid Claude Code event)
$eventHooks = @()
if ($settings.hooks | Get-Member -Name "UserPromptSubmit" -MemberType NoteProperty) {
    # Remove existing handle-use entries, keep peon.ps1 entries
    $eventHooks = @($settings.hooks.UserPromptSubmit | Where-Object {
        $dominated = $false
        foreach ($h in $_.hooks) {
            if ($h.command -and $h.command -match "hook-handle-use") {
                $dominated = $true
            }
        }
        -not $dominated
    })
}
$eventHooks += $beforeSubmitEntry

if ($settings.hooks | Get-Member -Name "UserPromptSubmit" -MemberType NoteProperty) {
    $settings.hooks.UserPromptSubmit = $eventHooks
} else {
    $settings.hooks | Add-Member -NotePropertyName "UserPromptSubmit" -NotePropertyValue $eventHooks
}

# Clean up stale beforeSubmitPrompt key if present (was incorrectly registered before)
if ($settings.hooks | Get-Member -Name "beforeSubmitPrompt" -MemberType NoteProperty) {
    $settings.hooks.PSObject.Properties.Remove("beforeSubmitPrompt")
}

$settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
Write-Host "  UserPromptSubmit hook registered for /peon-ping-use" -ForegroundColor Green

# --- Register Cursor hooks if ~/.cursor exists ---
$CursorDir = Join-Path $env:USERPROFILE ".cursor"
$CursorHooksFile = Join-Path $CursorDir "hooks.json"

if (Test-Path $CursorDir) {
    Write-Host ""
    Write-Host "Detected Cursor IDE installation, registering hooks..."
    
    # Load or create Cursor hooks.json
    $cursorData = [PSCustomObject]@{
        version = 1
        hooks = [PSCustomObject]@{}
    }
    
    if (Test-Path $CursorHooksFile) {
        try {
            $content = Get-Content $CursorHooksFile -Raw
            if ($content) {
                $cursorData = $content | ConvertFrom-Json
            }
        } catch {
            # Parse error, use default
        }
    }
    
    # Ensure $cursorData is valid and has required structure
    if (-not $cursorData) {
        $cursorData = [PSCustomObject]@{
            version = 1
            hooks = [PSCustomObject]@{}
        }
    }
    
    if (-not ($cursorData.PSObject.Properties.Name -contains "version")) {
        $cursorData | Add-Member -NotePropertyName "version" -NotePropertyValue 1
    }
    if (-not ($cursorData.PSObject.Properties.Name -contains "hooks")) {
        $cursorData | Add-Member -NotePropertyName "hooks" -NotePropertyValue ([PSCustomObject]@{})
    }
    
    # Create Cursor beforeSubmitPrompt hook (simpler format than Claude Code)
    $cursorBeforeSubmitHook = [PSCustomObject]@{
        command = $beforeSubmitCmd
        timeout = 5
    }
    
    $cursorEventHooks = @()
    if ($cursorData.hooks.PSObject.Properties.Name -contains "beforeSubmitPrompt") {
        # Remove existing handle-use entries, keep others
        $cursorEventHooks = @($cursorData.hooks.beforeSubmitPrompt | Where-Object {
            -not ($_.command -and $_.command -match "hook-handle-use")
        })
    }
    $cursorEventHooks += $cursorBeforeSubmitHook
    
    if ($cursorData.hooks.PSObject.Properties.Name -contains "beforeSubmitPrompt") {
        $cursorData.hooks.beforeSubmitPrompt = $cursorEventHooks
    } else {
        $cursorData.hooks | Add-Member -NotePropertyName "beforeSubmitPrompt" -NotePropertyValue $cursorEventHooks
    }
    
    # Ensure directory exists
    New-Item -ItemType Directory -Path $CursorDir -Force | Out-Null
    
    $cursorData | ConvertTo-Json -Depth 10 | Set-Content $CursorHooksFile -Encoding UTF8
    Write-Host "  Cursor beforeSubmitPrompt hook registered" -ForegroundColor Green
}

# --- Install skills ---
Write-Host ""
Write-Host "Installing skills..."

$skillsSourceDir = Join-Path $ScriptDir "skills"
$skillsTargetDir = Join-Path $ClaudeDir "skills"
New-Item -ItemType Directory -Path $skillsTargetDir -Force | Out-Null

$skillNames = @("peon-ping-toggle", "peon-ping-config", "peon-ping-use")

if (Test-Path $skillsSourceDir) {
    # Local install: copy from repo
    foreach ($skillName in $skillNames) {
        $skillSource = Join-Path $skillsSourceDir $skillName
        if (Test-Path $skillSource) {
            $skillTarget = Join-Path $skillsTargetDir $skillName
            if (Test-Path $skillTarget) {
                Remove-Item -Path $skillTarget -Recurse -Force
            }
            Copy-Item -Path $skillSource -Destination $skillTarget -Recurse -Force
            Write-Host "  /$skillName" -ForegroundColor DarkGray
        }
    }
    Write-Host "  Skills installed" -ForegroundColor Green
} else {
    # One-liner install: download from GitHub
    foreach ($skillName in $skillNames) {
        $skillTarget = Join-Path $skillsTargetDir $skillName
        New-Item -ItemType Directory -Path $skillTarget -Force | Out-Null

        $skillUrl = "$RepoBase/skills/$skillName/SKILL.md"
        $skillFile = Join-Path $skillTarget "SKILL.md"
        try {
            Invoke-WebRequest -Uri $skillUrl -OutFile $skillFile -UseBasicParsing -ErrorAction Stop
            Write-Host "  /$skillName" -ForegroundColor DarkGray
        } catch {
            Write-Host "  Warning: Could not download $skillName" -ForegroundColor Yellow
        }
    }
    Write-Host "  Skills installed" -ForegroundColor Green
}

# --- Install uninstall script ---
$uninstallSource = Join-Path $ScriptDir "uninstall.ps1"
$uninstallTarget = Join-Path $InstallDir "uninstall.ps1"

if (Test-Path $uninstallSource) {
    # Local install: copy from repo
    Copy-Item -Path $uninstallSource -Destination $uninstallTarget -Force
} else {
    # One-liner install: download from GitHub
    $uninstallUrl = "$RepoBase/uninstall.ps1"
    try {
        Invoke-WebRequest -Uri $uninstallUrl -OutFile $uninstallTarget -UseBasicParsing -ErrorAction Stop
    } catch {
        Write-Host "  Warning: Could not download uninstall.ps1" -ForegroundColor Yellow
    }
}

# --- Test sound ---
Write-Host ""
Write-Host "Testing sound..."

$testPack = try {
    (Get-Content $configPath -Raw | ConvertFrom-Json).active_pack
} catch { "peon" }

$testPackDir = Join-Path $InstallDir "packs\$testPack\sounds"
$testSound = Get-ChildItem -Path $testPackDir -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($testSound) {
    $winPlayScript = Join-Path $scriptsDir "win-play.ps1"
    if (Test-Path $winPlayScript) {
        try {
            $proc = Start-Process -WindowStyle Hidden -FilePath "powershell.exe" -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$winPlayScript,"-path",$testSound.FullName,"-vol",0.3 -PassThru
            Start-Sleep -Seconds 3
            Write-Host "  Sound working!" -ForegroundColor Green
        } catch {
            Write-Host "  Warning: Sound playback failed: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Warning: win-play.ps1 not found" -ForegroundColor Yellow
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
    $activePack = try { (Get-Content $configPath -Raw | ConvertFrom-Json).active_pack } catch { "peon" }
    Write-Host "  Active pack: $activePack" -ForegroundColor Cyan
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
    Write-Host "  To install specific packs: .\install.ps1 -Packs peon,glados,peasant" -ForegroundColor DarkGray
    Write-Host "  To install ALL packs: .\install.ps1 -All" -ForegroundColor DarkGray
    Write-Host "  To uninstall: powershell -ExecutionPolicy Bypass -File `"$InstallDir\uninstall.ps1`"" -ForegroundColor DarkGray
}
Write-Host ""```
