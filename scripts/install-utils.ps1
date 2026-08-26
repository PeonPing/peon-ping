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

# Strip a leading UTF-8 BOM (U+FEFF) from text read off disk.
# Older peon-ping versions wrote JSON with Set-Content -Encoding UTF8, which under
# Windows PowerShell 5.1 means UTF-8 *with* BOM. Stripping on read means the next
# write repairs the file instead of preserving the BOM forever.
function Remove-Utf8Bom {
    param([AllowEmptyString()][AllowNull()][string]$Text)
    if ($null -eq $Text) { return $Text }
    return $Text.TrimStart([char]0xFEFF)
}

# Write text to a file as UTF-8 without a BOM, on every PowerShell version.
# Windows PowerShell 5.1's `Set-Content -Encoding UTF8` emits a BOM (there is no
# utf8NoBOM token before PowerShell 6), and strict JSON readers reject it: a BOM on
# ~/.claude/settings.json makes the Claude Desktop app log a SyntaxError and read
# neither hooks nor permissions, with nothing on screen pointing at the encoding.
# Every file peon-ping writes goes through here so no call site has to remember.
function Write-PeonTextFile {
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Path,
        [Parameter(Position = 1, ValueFromPipeline = $true)][AllowEmptyString()][AllowNull()][string[]]$Content,
        [switch]$NoNewline
    )
    begin { $lines = New-Object System.Collections.Generic.List[string] }
    process {
        if ($null -ne $Content) {
            foreach ($line in $Content) { $lines.Add([string]$line) }
        }
    }
    end {
        # Set-Content joins pipeline items with a newline and terminates the file
        # with one; match that so switching writers is not also a content change.
        $text = ($lines -join [Environment]::NewLine)
        if (-not $NoNewline -and $text.Length -gt 0) { $text += [Environment]::NewLine }
        [System.IO.File]::WriteAllText($Path, $text, (New-Object System.Text.UTF8Encoding $false))
    }
}

# Returns raw config JSON with locale-damaged decimals fixed (e.g. "volume": 0,5 -> 0.5).
# Also repairs missing volume value (e.g. "volume":\n "pack_rotation_mode" from a failed write).
# Use before ConvertFrom-Json so config parses on systems where decimal separator is comma.
function Get-PeonConfigRaw {
    param([string]$Path)
    $raw = Remove-Utf8Bom (Get-Content $Path -Raw)
    $raw = $raw -replace '"volume"\s*:\s*(\d),(\d+)', '"volume": $1.$2'
    $raw = $raw -replace '"volume"\s*:\s*\r?\n(\s*)"', '"volume": 0.5,$1"'
    return $raw
}

# Write a config object to a JSON file with culture-safe serialization.
# Saves and restores CurrentCulture in a try/finally to guarantee no culture leak,
# preventing locale-damaged decimals (e.g. "volume": 0,5 on European locales).
function Set-PeonConfig {
    param($Config, [string]$Path)
    $prevCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
        $Config | ConvertTo-Json -Depth 10 | Write-PeonTextFile $Path
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $prevCulture
    }
}

# Resolve the active pack from config using the default_pack -> active_pack -> "peon" fallback chain.
# Accepts any object with optional default_pack and/or active_pack properties.
function Get-ActivePack($config) {
    if ($config.default_pack) { return $config.default_pack }
    if ($config.active_pack) { return $config.active_pack }
    return "peon"
}
