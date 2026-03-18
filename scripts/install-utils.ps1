# peon-ping installer utilities
# Dot-sourceable validation functions shared between install.ps1 and Pester tests.
# This file MUST have no side effects when dot-sourced (no Write-Host, no variable
# assignments outside functions, no execution-policy changes).

# --- Input validation (mirrors install.sh safety checks) ---
function Test-SafePackName($n)    { $n -match '^[A-Za-z0-9._-]+$' }
function Test-SafeSourceRepo($n)  { $n -match '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$' }
function Test-SafeSourceRef($n)   { $n -match '^[A-Za-z0-9._/-]+$' -and $n -notmatch '\.\.' -and $n[0] -ne '/' }
function Test-SafeSourcePath($n)  { $n -match '^[A-Za-z0-9._/-]+$' -and $n -notmatch '\.\.' -and $n[0] -ne '/' }
function Test-SafeFilename($n)    { $n -match '^[A-Za-z0-9._-]+$' }

# Returns raw config JSON with locale-damaged decimals fixed (e.g. "volume": 0,5 -> 0.5).
# Also repairs missing volume value (e.g. "volume":\n "pack_rotation_mode" from a failed write).
# Use before ConvertFrom-Json so config parses on systems where decimal separator is comma.
function Get-PeonConfigRaw {
    param([string]$Path)
    $raw = Get-Content $Path -Raw
    $raw = $raw -replace '"volume"\s*:\s*(\d),(\d+)', '"volume": $1.$2'
    $raw = $raw -replace '"volume"\s*:\s*\r?\n(\s*)"', '"volume": 0.5,$1"'
    return $raw
}

# Resolve the active pack from config using the default_pack -> active_pack -> "peon" fallback chain.
# Accepts any object with optional default_pack and/or active_pack properties.
function Get-ActivePack($config) {
    if ($config.default_pack) { return $config.default_pack }
    if ($config.active_pack) { return $config.active_pack }
    return "peon"
}
