# peon-ping adapter for OpenCode (Windows)
# Installs the peon-ping CESP v1.0 TypeScript plugin for OpenCode
#
# OpenCode uses a TypeScript plugin system (not shell hooks), so this
# adapter is an install script rather than a runtime event translator.
#
# Install:
#   powershell -NoProfile -File adapters/opencode.ps1
#
# Uninstall:
#   powershell -NoProfile -File adapters/opencode.ps1 -Uninstall

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

# --- Config ---
$PluginUrl = "https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/opencode/peon-ping.ts"
$RegistryUrl = "https://peonping.github.io/registry/index.json"
$DefaultPack = "peon"

$PluginsDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode\plugins" }
              elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "opencode\plugins" }
              else { Join-Path $env:USERPROFILE ".config\opencode\plugins" }

$PeonConfigDir = if ($env:XDG_CONFIG_HOME) { Join-Path $env:XDG_CONFIG_HOME "opencode\peon-ping" }
                 elseif ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "opencode\peon-ping" }
                 else { Join-Path $env:USERPROFILE ".config\opencode\peon-ping" }

$PacksDir = Join-Path $env:USERPROFILE ".openpeon\packs"

# --- Uninstall ---
if ($Uninstall) {
    Write-Host "> Uninstalling peon-ping from OpenCode..."
    Remove-Item (Join-Path $PluginsDir "peon-ping.ts") -Force -ErrorAction SilentlyContinue
    Remove-Item $PeonConfigDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "> Plugin and config removed."
    Write-Host "> Sound packs in $PacksDir were preserved (shared with other adapters)."
    Write-Host "> To remove packs too: Remove-Item -Recurse $PacksDir"
    exit 0
}

# --- Install ---
Write-Host "> Installing peon-ping for OpenCode..."

# Install plugin
New-Item -ItemType Directory -Path $PluginsDir -Force | Out-Null
$pluginPath = Join-Path $PluginsDir "peon-ping.ts"
Remove-Item $pluginPath -Force -ErrorAction SilentlyContinue

Write-Host "> Downloading peon-ping.ts plugin..."
Invoke-WebRequest -Uri $PluginUrl -OutFile $pluginPath -UseBasicParsing
Write-Host "> Plugin installed to $pluginPath"

# Create default config
New-Item -ItemType Directory -Path $PeonConfigDir -Force | Out-Null
$configPath = Join-Path $PeonConfigDir "config.json"

if (-not (Test-Path $configPath)) {
    $config = @{
        active_pack           = "peon"
        volume                = 0.5
        enabled               = $true
        categories            = @{
            "session.start"    = $true
            "session.end"      = $true
            "task.acknowledge" = $true
            "task.complete"    = $true
            "task.error"       = $true
            "task.progress"    = $true
            "input.required"   = $true
            "resource.limit"   = $true
            "user.spam"        = $true
        }
        spam_threshold        = 3
        spam_window_seconds   = 10
        pack_rotation         = @()
        debounce_ms           = 500
    }
    $prevCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
        $config | ConvertTo-Json -Depth 3 | Set-Content $configPath -Encoding UTF8
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prevCulture
    }
    Write-Host "> Config created at $configPath"
} else {
    Write-Host "> Config already exists, preserved."
}

# Install default sound pack from registry
New-Item -ItemType Directory -Path $PacksDir -Force | Out-Null

$packDir = Join-Path $PacksDir $DefaultPack
if (-not (Test-Path $packDir)) {
    Write-Host "> Installing default sound pack '$DefaultPack' from registry..."
    try {
        $regJson = Invoke-WebRequest -Uri $RegistryUrl -UseBasicParsing -ErrorAction Stop
        $registry = $regJson.Content | ConvertFrom-Json
        $packInfo = $registry.packs | Where-Object { $_.name -eq $DefaultPack } | Select-Object -First 1

        if ($packInfo -and $packInfo.source_repo -and $packInfo.source_ref -and $packInfo.source_path) {
            $tarballUrl = "https://github.com/$($packInfo.source_repo)/archive/refs/tags/$($packInfo.source_ref).tar.gz"
            $tmpDir = Join-Path $env:TEMP "peon-opencode-$(Get-Random)"
            New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
            $tarball = Join-Path $tmpDir "pack.tar.gz"

            Invoke-WebRequest -Uri $tarballUrl -OutFile $tarball -UseBasicParsing -ErrorAction Stop
            tar xzf $tarball -C $tmpDir 2>$null

            $extracted = Get-ChildItem $tmpDir -Directory | Select-Object -First 1
            $packSource = Join-Path $extracted.FullName $packInfo.source_path
            if (Test-Path $packSource) {
                New-Item -ItemType Directory -Path $packDir -Force | Out-Null
                Copy-Item "$packSource\*" $packDir -Recurse -Force
                Write-Host "> Pack '$DefaultPack' installed to $packDir"
            } else {
                Write-Host "! Could not find pack in downloaded archive." -ForegroundColor Yellow
            }
            Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "! Could not find '$DefaultPack' in registry." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "! Could not download pack from registry. Install packs manually later." -ForegroundColor Yellow
    }
} else {
    Write-Host "> Pack '$DefaultPack' already installed."
}

# Done
Write-Host ""
Write-Host "> peon-ping installed for OpenCode!" -ForegroundColor Green
Write-Host ""
Write-Host "  Plugin:  $pluginPath"
Write-Host "  Config:  $configPath"
Write-Host "  Packs:   $PacksDir"
Write-Host ""
Write-Host "> Restart OpenCode to activate. Your Peon awaits."
Write-Host "> Install more packs: https://openpeon.com/packs"
