# windows-setup.ps1 -- Shared Pester test harness for peon-ping Windows functional tests
#
# Provides reusable helper functions so every test file can create isolated test
# environments, pipe CESP JSON to peon.ps1, and inspect results without
# reimplementing extraction, temp dir setup, or mock infrastructure.
#
# Usage (in any .Tests.ps1 file):
#   BeforeAll { . $PSScriptRoot/windows-setup.ps1 }
#
# Functions:
#   Extract-PeonHookScript   -- extracts peon.ps1 source from install.ps1 here-string
#   New-PeonTestEnvironment  -- creates an isolated temp dir with all required files
#   Invoke-PeonHook          -- pipes CESP JSON to peon.ps1 and captures results
#   New-CespJson             -- builds a CESP JSON payload from parameters
#   Get-PeonState            -- reads and parses .state.json from a test dir
#   Get-PeonConfig           -- reads and parses config.json from a test dir
#   Get-AudioLog             -- reads the mock audio log from a test dir
#   Remove-PeonTestEnvironment -- cleans up a test directory

# ============================================================
# Extract-PeonHookScript
# ============================================================
# Extracts the embedded peon.ps1 from install.ps1's here-string.
# Returns the script content as a string.

function Extract-PeonHookScript {
    [CmdletBinding()]
    param(
        [string]$InstallPath
    )
    if (-not $InstallPath) {
        $InstallPath = Join-Path (Split-Path $PSScriptRoot -Parent) "install.ps1"
    }
    if (-not (Test-Path $InstallPath)) {
        throw "install.ps1 not found at: $InstallPath"
    }

    $content = Get-Content $InstallPath -Raw
    # The hook script is embedded between $hookScript = @' and '@
    if ($content -match "(?s)hookScript = @'(.+?)'@") {
        return $matches[1].TrimStart("`r`n").TrimStart("`n")
    }
    throw "Could not extract peon.ps1 from install.ps1 -- here-string pattern not found"
}

# ============================================================
# New-PeonTestEnvironment
# ============================================================
# Creates a fully isolated temp directory with:
#   - peon.ps1 (extracted from install.ps1)
#   - config.json (with configurable overrides)
#   - .state.json (with configurable overrides)
#   - packs/peon/ with openpeon.json manifest and dummy sound files
#   - packs/sc_kerrigan/ as a second pack for rotation/override tests
#   - scripts/win-play.ps1 (mock that logs calls to .audio-log.txt)
#
# Returns a hashtable with:
#   TestDir   -- path to the temp directory
#   PeonPath  -- path to peon.ps1 in the temp directory

function New-PeonTestEnvironment {
    [CmdletBinding()]
    param(
        [hashtable]$ConfigOverrides = @{},
        [hashtable]$StateOverrides = @{}
    )

    $testDir = Join-Path $env:TEMP "peon-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    # --- Extract and write peon.ps1 ---
    $peonContent = Extract-PeonHookScript
    $peonPath = Join-Path $testDir "peon.ps1"
    Set-Content -Path $peonPath -Value $peonContent -Encoding UTF8

    # --- Create scripts directory with mock win-play.ps1 ---
    $scriptsDir = Join-Path $testDir "scripts"
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null

    # Mock win-play.ps1: logs calls to .audio-log.txt instead of playing audio
    $mockWinPlay = @'
param(
    [string]$path,
    [double]$vol
)
$logFile = Join-Path (Split-Path $PSScriptRoot -Parent) ".audio-log.txt"
"$path|$vol" | Out-File -FilePath $logFile -Append -Encoding UTF8
'@
    Set-Content -Path (Join-Path $scriptsDir "win-play.ps1") -Value $mockWinPlay -Encoding UTF8

    # --- Create peon pack with manifest and dummy sounds ---
    $peonPackDir = Join-Path (Join-Path $testDir "packs") "peon"
    $peonSoundsDir = Join-Path $peonPackDir "sounds"
    New-Item -ItemType Directory -Path $peonSoundsDir -Force | Out-Null

    $peonManifest = @'
{
  "cesp_version": "1.0",
  "name": "peon",
  "display_name": "Orc Peon",
  "categories": {
    "session.start": {
      "sounds": [
        { "file": "sounds/Hello1.wav", "label": "Ready to work?" },
        { "file": "sounds/Hello2.wav", "label": "Yes?" }
      ]
    },
    "task.acknowledge": {
      "sounds": [
        { "file": "sounds/Ack1.wav", "label": "Work, work." }
      ]
    },
    "task.complete": {
      "sounds": [
        { "file": "sounds/Done1.wav", "label": "Something need doing?" },
        { "file": "sounds/Done2.wav", "label": "Ready to work?" }
      ]
    },
    "task.error": {
      "sounds": [
        { "file": "sounds/Error1.wav", "label": "Me not that kind of orc!" }
      ]
    },
    "input.required": {
      "sounds": [
        { "file": "sounds/Perm1.wav", "label": "Something need doing?" },
        { "file": "sounds/Perm2.wav", "label": "Hmm?" }
      ]
    },
    "resource.limit": {
      "sounds": [
        { "file": "sounds/Limit1.wav", "label": "More work?" }
      ]
    },
    "user.spam": {
      "sounds": [
        { "file": "sounds/Angry1.wav", "label": "Me busy, leave me alone!" }
      ]
    }
  }
}
'@
    Set-Content -Path (Join-Path $peonPackDir "openpeon.json") -Value $peonManifest -Encoding UTF8

    # Create dummy sound files (0-byte WAV placeholders)
    $peonSounds = @("Hello1.wav", "Hello2.wav", "Ack1.wav", "Done1.wav", "Done2.wav",
                     "Error1.wav", "Perm1.wav", "Perm2.wav", "Limit1.wav", "Angry1.wav")
    foreach ($s in $peonSounds) {
        # Write RIFF header so file is non-empty (SoundPlayer requires content)
        [System.IO.File]::WriteAllBytes((Join-Path $peonSoundsDir $s), [byte[]](0x52,0x49,0x46,0x46))
    }

    # --- Create sc_kerrigan pack (second pack for rotation/override tests) ---
    $kerriganDir = Join-Path (Join-Path $testDir "packs") "sc_kerrigan"
    $kerriganSoundsDir = Join-Path $kerriganDir "sounds"
    New-Item -ItemType Directory -Path $kerriganSoundsDir -Force | Out-Null

    $kerriganManifest = @'
{
  "cesp_version": "1.0",
  "name": "sc_kerrigan",
  "display_name": "Sarah Kerrigan (StarCraft)",
  "categories": {
    "session.start": {
      "sounds": [
        { "file": "sounds/Hello1.wav", "label": "What now?" }
      ]
    },
    "task.complete": {
      "sounds": [
        { "file": "sounds/Done1.wav", "label": "I gotcha." }
      ]
    }
  }
}
'@
    Set-Content -Path (Join-Path $kerriganDir "openpeon.json") -Value $kerriganManifest -Encoding UTF8

    foreach ($s in @("Hello1.wav", "Done1.wav")) {
        [System.IO.File]::WriteAllBytes((Join-Path $kerriganSoundsDir $s), [byte[]](0x52,0x49,0x46,0x46))
    }

    # --- Create config.json ---
    $defaultConfig = @{
        active_pack               = "peon"
        volume                    = 0.5
        enabled                   = $true
        categories                = @{
            "session.start"    = $true
            "task.acknowledge" = $false
            "task.complete"    = $true
            "task.error"       = $true
            "input.required"   = $true
            "resource.limit"   = $true
            "user.spam"        = $true
        }
        annoyed_threshold         = 3
        annoyed_window_seconds    = 10
        session_start_cooldown_seconds = 0
    }
    # Apply overrides
    foreach ($key in $ConfigOverrides.Keys) {
        $defaultConfig[$key] = $ConfigOverrides[$key]
    }
    $configJson = $defaultConfig | ConvertTo-Json -Depth 5
    # Ensure decimal volume is written with dot (locale safety)
    $configJson = $configJson -replace '(?<=\d),(?=\d)', '.'
    Set-Content -Path (Join-Path $testDir "config.json") -Value $configJson -Encoding UTF8

    # --- Create .state.json ---
    $defaultState = @{}
    foreach ($key in $StateOverrides.Keys) {
        $defaultState[$key] = $StateOverrides[$key]
    }
    $stateJson = if ($defaultState.Count -eq 0) { "{}" } else { $defaultState | ConvertTo-Json -Depth 5 }
    Set-Content -Path (Join-Path $testDir ".state.json") -Value $stateJson -Encoding UTF8

    # --- Create VERSION file ---
    Set-Content -Path (Join-Path $testDir "VERSION") -Value "1.0.0-test" -Encoding UTF8

    return @{
        TestDir  = $testDir
        PeonPath = $peonPath
    }
}

# ============================================================
# Remove-PeonTestEnvironment
# ============================================================
# Cleans up a test directory created by New-PeonTestEnvironment.

function Remove-PeonTestEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestDir
    )
    if ($TestDir -and (Test-Path $TestDir)) {
        Remove-Item -Path $TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ============================================================
# New-CespJson
# ============================================================
# Builds a CESP JSON payload from parameters.
# Returns a JSON string suitable for piping to peon.ps1.

function New-CespJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$HookEventName,

        [string]$SessionId = "test-session-001",
        [string]$NotificationType = "",
        [string]$Cwd = "",
        [string]$PermissionMode = ""
    )

    $payload = @{
        hook_event_name = $HookEventName
        session_id      = $SessionId
    }
    if ($NotificationType) {
        $payload["notification_type"] = $NotificationType
    }
    if ($Cwd) {
        $payload["cwd"] = $Cwd
    }
    if ($PermissionMode) {
        $payload["permission_mode"] = $PermissionMode
    }
    return ($payload | ConvertTo-Json -Compress)
}

# ============================================================
# Invoke-PeonHook
# ============================================================
# Pipes CESP JSON to peon.ps1 and returns results.
# Returns a hashtable with:
#   ExitCode  -- process exit code
#   Stdout    -- captured stdout
#   Stderr    -- captured stderr
#   AudioLog  -- contents of .audio-log.txt (what the mock win-play.ps1 logged)

function Invoke-PeonHook {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestDir,

        [Parameter(Mandatory=$true)]
        [string]$JsonPayload,

        [int]$TimeoutSeconds = 15
    )

    $peonPath = Join-Path $TestDir "peon.ps1"
    if (-not (Test-Path $peonPath)) {
        throw "peon.ps1 not found in test directory: $TestDir"
    }

    # Clear previous audio log
    $audioLogPath = Join-Path $TestDir ".audio-log.txt"
    if (Test-Path $audioLogPath) {
        Remove-Item $audioLogPath -Force
    }

    # Run peon.ps1 with JSON piped via stdin using -File flag.
    # -File correctly supports stdin redirection and $MyInvocation.MyCommand.Path resolution.
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -NoLogo -File `"$peonPath`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.Environment["CLAUDE_PEON_DIR"] = $TestDir
    $psi.Environment["PEON_TEST"] = "1"

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi

    try {
        $proc.Start() | Out-Null
        $proc.StandardInput.Write($JsonPayload)
        $proc.StandardInput.Close()

        # Read output asynchronously to avoid deadlocks
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            $proc.Kill()
            throw "peon.ps1 timed out after ${TimeoutSeconds}s"
        }

        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result
        $exitCode = $proc.ExitCode
    } finally {
        $proc.Dispose()
    }

    # Wait briefly for detached audio process to write its log.
    # peon.ps1 delegates audio to win-play.ps1 via Start-Process (async/detached),
    # so the log file may not exist yet when peon.ps1 exits.
    $waitMs = 0
    while ($waitMs -lt 3000 -and -not (Test-Path $audioLogPath)) {
        Start-Sleep -Milliseconds 100
        $waitMs += 100
    }
    # Give extra time for file to be flushed
    if (Test-Path $audioLogPath) {
        Start-Sleep -Milliseconds 200
    }

    # Read audio log
    $audioLog = @()
    if (Test-Path $audioLogPath) {
        $audioLog = @(Get-Content $audioLogPath -Encoding UTF8 | Where-Object { $_ -ne "" })
    }

    return @{
        ExitCode = $exitCode
        Stdout   = $stdout
        Stderr   = $stderr
        AudioLog = $audioLog
    }
}

# ============================================================
# Get-PeonState
# ============================================================
# Reads and parses .state.json from the test directory.

function Get-PeonState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestDir
    )
    $statePath = Join-Path $TestDir ".state.json"
    if (-not (Test-Path $statePath)) {
        return @{}
    }
    return (Get-Content $statePath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

# ============================================================
# Get-PeonConfig
# ============================================================
# Reads and parses config.json from the test directory.

function Get-PeonConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestDir
    )
    $configPath = Join-Path $TestDir "config.json"
    if (-not (Test-Path $configPath)) {
        return @{}
    }
    return (Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

# ============================================================
# Get-AudioLog
# ============================================================
# Reads the mock audio log to verify what sound was "played".
# Returns an array of strings in the format "path|volume".

function Get-AudioLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TestDir
    )
    $audioLogPath = Join-Path $TestDir ".audio-log.txt"
    if (-not (Test-Path $audioLogPath)) {
        return @()
    }
    return @(Get-Content $audioLogPath -Encoding UTF8 | Where-Object { $_ -ne "" })
}
