# Pester 5 behavioral tests for CLI config-write commands
# Run: Invoke-Pester -Path tests/cli-config-write.Tests.ps1
#
# These tests execute CLI commands (--pause, --resume, --toggle, --volume, etc.)
# against a real config.json and verify the file is updated correctly.
# This complements the structural/grep-style tests in adapters-windows.Tests.ps1.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent

    # Extract the hook script from install.ps1's here-string (between @' and '@)
    $installContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
    $startMarker = "`$hookScript = @'"
    $startIdx = $installContent.IndexOf($startMarker)
    if ($startIdx -lt 0) { throw "Could not find hook script start marker in install.ps1" }
    $startIdx += $startMarker.Length
    # Find the closing '@ that starts at beginning of a line
    $endIdx = $installContent.IndexOf("`n'@", $startIdx)
    if ($endIdx -lt 0) { throw "Could not find hook script end marker in install.ps1" }
    $script:HookScriptContent = $installContent.Substring($startIdx, $endIdx - $startIdx).TrimStart("`r", "`n")

    # Helper: create isolated test environment with extracted hook script + config
    function script:New-TestHookEnv {
        param(
            [hashtable]$ConfigOverrides = @{}
        )
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

        # Write the hook script
        $hookPath = Join-Path $tmpDir "peon.ps1"
        Set-Content -Path $hookPath -Value $script:HookScriptContent -Encoding UTF8

        # Build default config
        $config = @{
            default_pack = "peon"
            volume = 0.5
            enabled = $true
            desktop_notifications = $true
            categories = @{
                "session.start" = $true
                "task.acknowledge" = $false
                "task.complete" = $true
                "task.error" = $true
                "input.required" = $true
                "resource.limit" = $true
                "user.spam" = $true
            }
            annoyed_threshold = 3
            annoyed_window_seconds = 10
            silent_window_seconds = 0
            session_start_cooldown_seconds = 30
            suppress_subagent_complete = $false
            no_rc = $false
            pack_rotation = @()
            pack_rotation_mode = "random"
            path_rules = @()
            session_ttl_days = 7
            use_sound_effects_device = $true
            linux_audio_player = ""
            headphones_only = $false
            meeting_detect = $false
            suppress_sound_when_tab_focused = $false
            notification_position = "top-center"
            notification_dismiss_seconds = 4
            notification_title_override = ""
            notification_title_marker = "●"
            notification_title_ide = $false
            notification_title_script = ""
            project_name_map = @{}
        }

        # Apply overrides
        foreach ($key in $ConfigOverrides.Keys) {
            $config[$key] = $ConfigOverrides[$key]
        }

        $configPath = Join-Path $tmpDir "config.json"
        $config | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8

        return @{
            Dir = $tmpDir
            HookPath = $hookPath
            ConfigPath = $configPath
        }
    }

    function script:Remove-TestHookEnv {
        param([string]$Dir)
        if ($Dir -and (Test-Path $Dir)) {
            Remove-Item -Path $Dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    function script:Invoke-PeonCommand {
        param(
            [string]$HookPath,
            [string]$Command,
            [string]$Arg1 = "",
            [string]$Arg2 = ""
        )
        $argList = @("-NoProfile", "-File", $HookPath, "-Command", $Command)
        if ($Arg1) { $argList += @("-Arg1", $Arg1) }
        if ($Arg2) { $argList += @("-Arg2", $Arg2) }
        $result = & pwsh @argList 2>&1
        $script:LastPeonExitCode = $LASTEXITCODE
        return $result
    }

    function script:Get-TestConfig {
        param([string]$ConfigPath)
        return (Get-Content $ConfigPath -Raw | ConvertFrom-Json)
    }
}

# ============================================================
# --pause: writes enabled=false to config
# ============================================================

Describe "CLI --pause command" {
    BeforeEach {
        $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $true }
    }
    AfterEach {
        Remove-TestHookEnv -Dir $script:env.Dir
    }

    It "writes enabled=false to config.json" {
        $before = Get-TestConfig $script:env.ConfigPath
        $before.enabled | Should -Be $true

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--pause"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $false
    }

    It "is idempotent when already paused" {
        # First pause
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--pause"
        $script:LastPeonExitCode | Should -Be 0
        $cfg1 = Get-TestConfig $script:env.ConfigPath
        $cfg1.enabled | Should -Be $false

        # Second pause (should still be false, no error)
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--pause"
        $script:LastPeonExitCode | Should -Be 0
        $cfg2 = Get-TestConfig $script:env.ConfigPath
        $cfg2.enabled | Should -Be $false
    }

    It "--mute alias also writes enabled=false" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--mute"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $false
    }
}

# ============================================================
# --resume: writes enabled=true to config
# ============================================================

Describe "CLI --resume command" {
    BeforeEach {
        $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $false }
    }
    AfterEach {
        Remove-TestHookEnv -Dir $script:env.Dir
    }

    It "writes enabled=true to config.json" {
        $before = Get-TestConfig $script:env.ConfigPath
        $before.enabled | Should -Be $false

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--resume"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $true
    }

    It "is idempotent when already enabled" {
        # Resume from disabled
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--resume"
        $script:LastPeonExitCode | Should -Be 0
        $cfg1 = Get-TestConfig $script:env.ConfigPath
        $cfg1.enabled | Should -Be $true

        # Resume again
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--resume"
        $script:LastPeonExitCode | Should -Be 0
        $cfg2 = Get-TestConfig $script:env.ConfigPath
        $cfg2.enabled | Should -Be $true
    }

    It "--unmute alias also writes enabled=true" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--unmute"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $true
    }
}

# ============================================================
# --toggle: flips enabled state
# ============================================================

Describe "CLI --toggle command" {
    AfterEach {
        Remove-TestHookEnv -Dir $script:env.Dir
    }

    It "toggles enabled=true to enabled=false" {
        $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $true }

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--toggle"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $false
    }

    It "toggles enabled=false to enabled=true" {
        $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $false }

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--toggle"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $true
    }

    It "double toggle returns to original state" {
        $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $true }

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--toggle"
        $script:LastPeonExitCode | Should -Be 0
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--toggle"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $true
    }
}

# ============================================================
# --volume: writes volume value to config
# ============================================================

Describe "CLI --volume command" {
    BeforeEach {
        $script:env = New-TestHookEnv -ConfigOverrides @{ volume = 0.5 }
    }
    AfterEach {
        Remove-TestHookEnv -Dir $script:env.Dir
    }

    It "sets volume to specified value" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--volume" -Arg1 "0.8"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.volume | Should -Be 0.8
    }

    It "clamps volume to 1.0 maximum" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--volume" -Arg1 "1.5"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.volume | Should -Be 1.0
    }

    It "clamps volume to 0.0 minimum" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--volume" -Arg1 "-0.5"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.volume | Should -Be 0.0
    }

    It "preserves other config keys when changing volume" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--volume" -Arg1 "0.3"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.volume | Should -Be 0.3
        $after.enabled | Should -Be $true
        $after.default_pack | Should -Be "peon"
    }

    It "produces valid JSON when volume is the last key (no trailing comma)" {
        # Write a minimal config where volume is the last key — no trailing comma
        $manualJson = '{ "enabled": true, "default_pack": "peon", "volume": 0.5 }'
        Set-Content -Path $script:env.ConfigPath -Value $manualJson -Encoding UTF8

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--volume" -Arg1 "0.7"
        $script:LastPeonExitCode | Should -Be 0

        # Must parse as valid JSON (would fail on trailing comma: "volume": 0.7,})
        $raw = Get-Content $script:env.ConfigPath -Raw
        $raw | Should -Not -Match '"volume":\s*[\d.]+,\s*\}'
        $after = $raw | ConvertFrom-Json
        $after.volume | Should -Be 0.7
        $after.enabled | Should -Be $true
    }
}

# ============================================================
# Skip-write / idempotency: config stays valid even on no-op writes
# ============================================================

Describe "CLI skip-write and idempotency" {
    BeforeEach {
        $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $false }
    }
    AfterEach {
        Remove-TestHookEnv -Dir $script:env.Dir
    }

    It "--pause does not corrupt config when already paused" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--pause"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $false
        $after.default_pack | Should -Be "peon"
        $after.volume | Should -Be 0.5
    }

    It "--resume does not corrupt config when already enabled" {
        $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $true }

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--resume"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $true
        $after.default_pack | Should -Be "peon"
    }

    It "config remains valid JSON after multiple writes" {
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--resume"
        $script:LastPeonExitCode | Should -Be 0
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--pause"
        $script:LastPeonExitCode | Should -Be 0
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--toggle"
        $script:LastPeonExitCode | Should -Be 0
        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--toggle"
        $script:LastPeonExitCode | Should -Be 0

        $raw = Get-Content $script:env.ConfigPath -Raw
        { $raw | ConvertFrom-Json } | Should -Not -Throw
    }
}

# ============================================================
# Config file integrity: non-target keys are preserved
# ============================================================

Describe "CLI config write preserves non-target keys" {
    AfterEach {
        Remove-TestHookEnv -Dir $script:env.Dir
    }

    It "--pause preserves all non-enabled config keys" {
        $script:env = New-TestHookEnv -ConfigOverrides @{
            enabled = $true
            volume = 0.7
            default_pack = "glados"
            annoyed_threshold = 5
        }

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--pause"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $false
        $after.volume | Should -Be 0.7
        $after.default_pack | Should -Be "glados"
        $after.annoyed_threshold | Should -Be 5
    }

    It "--toggle preserves all non-enabled config keys" {
        $script:env = New-TestHookEnv -ConfigOverrides @{
            enabled = $true
            volume = 0.3
            default_pack = "peasant"
        }

        Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--toggle"
        $script:LastPeonExitCode | Should -Be 0

        $after = Get-TestConfig $script:env.ConfigPath
        $after.enabled | Should -Be $false
        $after.volume | Should -Be 0.3
        $after.default_pack | Should -Be "peasant"
    }
}

# ============================================================
# Error handling: missing config file
# ============================================================

Describe "CLI error handling for missing config" {
    BeforeEach {
        $script:env = New-TestHookEnv
        Remove-Item $script:env.ConfigPath -Force
    }
    AfterEach {
        Remove-TestHookEnv -Dir $script:env.Dir
    }

    It "--pause exits with error when config is missing" {
        $output = Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--pause" 2>&1
        $outputStr = $output -join "`n"
        $outputStr | Should -Match "not configured|not found"
    }

    It "--resume exits with error when config is missing" {
        $output = Invoke-PeonCommand -HookPath $script:env.HookPath -Command "--resume" 2>&1
        $outputStr = $output -join "`n"
        $outputStr | Should -Match "not configured|not found"
    }
}

# ============================================================
# Encoding: every file peon-ping writes must be UTF-8 with no BOM
#
# Windows PowerShell 5.1's `Set-Content -Encoding UTF8` writes a BOM, and a BOM
# on ~/.claude/settings.json makes the Claude Desktop app log a SyntaxError and
# read neither hooks nor permissions. These tests check the bytes on disk under
# the shell that actually reproduces it (powershell.exe, 5.1), because a source
# grep stops holding the moment someone adds a new writer.
# ============================================================

# Resolved at discovery time: -Skip: is evaluated before BeforeAll runs.
$script:WinPS = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
$script:SkipNoWinPS = -not $script:WinPS

Describe "UTF-8 encoding without BOM" {
    BeforeAll {
        # Re-resolved for the run phase; the discovery-time copy above only feeds -Skip:.
        $script:WinPS = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source

        function script:New-EncodingTestDir {
            $dir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-bom-$([guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            return $dir
        }

        # Run a script under Windows PowerShell 5.1, where -Encoding UTF8 means
        # "UTF-8 with BOM". Via -File so paths with spaces need no quoting dance.
        function script:Invoke-WindowsPowerShellScript {
            param([string]$Dir, [string]$Body)
            $scriptPath = Join-Path $Dir "run-$([guid]::NewGuid().ToString('N').Substring(0,6)).ps1"
            [System.IO.File]::WriteAllText($scriptPath, $Body, (New-Object System.Text.UTF8Encoding $false))
            & $script:WinPS -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $scriptPath 2>&1
        }

        function script:Test-HasUtf8Bom {
            param([string]$Path)
            $bytes = [System.IO.File]::ReadAllBytes($Path)
            return ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        }

        function script:Write-BomFile {
            param([string]$Path, [string]$Text)
            [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $true))
        }
    }

    Context "install-time writers (scripts/install-utils.ps1)" {
        BeforeEach { $script:dir = New-EncodingTestDir }
        AfterEach { Remove-Item -Path $script:dir -Recurse -Force -ErrorAction SilentlyContinue }

        It "Set-PeonConfig writes config.json with no BOM under Windows PowerShell 5.1" -Skip:$script:SkipNoWinPS {
            $target = Join-Path $script:dir "config.json"
            $utils = Join-Path $script:RepoRoot "scripts\install-utils.ps1"
            Invoke-WindowsPowerShellScript -Dir $script:dir -Body @"
. '$utils'
Set-PeonConfig ([PSCustomObject]@{ default_pack = 'peon'; volume = 0.5; enabled = `$true }) '$target'
"@
            Test-Path $target | Should -Be $true
            Test-HasUtf8Bom $target | Should -Be $false
        }

        It "the settings.json writer used by install.ps1 leaves no BOM under Windows PowerShell 5.1" -Skip:$script:SkipNoWinPS {
            # Exactly the expression install.ps1 uses to register hooks:
            #   $settings | ConvertTo-Json -Depth 10 | Write-PeonTextFile $SettingsFile
            $target = Join-Path $script:dir "settings.json"
            $utils = Join-Path $script:RepoRoot "scripts\install-utils.ps1"
            Invoke-WindowsPowerShellScript -Dir $script:dir -Body @"
. '$utils'
`$settings = [PSCustomObject]@{ hooks = [PSCustomObject]@{ SessionStart = @() } }
`$settings | ConvertTo-Json -Depth 10 | Write-PeonTextFile '$target'
"@
            Test-Path $target | Should -Be $true
            Test-HasUtf8Bom $target | Should -Be $false
            (Get-Content $target -Raw | ConvertFrom-Json).hooks | Should -Not -BeNullOrEmpty
        }

        It "Write-PeonTextFile overwrites an existing BOM'd file without a BOM" -Skip:$script:SkipNoWinPS {
            # Upgrade path: a settings.json left BOM'd by an older peon-ping must
            # come back clean, not keep its BOM forever.
            $target = Join-Path $script:dir "settings.json"
            Write-BomFile -Path $target -Text '{ "hooks": {} }'
            Test-HasUtf8Bom $target | Should -Be $true

            $utils = Join-Path $script:RepoRoot "scripts\install-utils.ps1"
            Invoke-WindowsPowerShellScript -Dir $script:dir -Body @"
. '$utils'
`$settings = Remove-Utf8Bom (Get-Content '$target' -Raw) | ConvertFrom-Json
`$settings | ConvertTo-Json -Depth 10 | Write-PeonTextFile '$target'
"@
            Test-HasUtf8Bom $target | Should -Be $false
        }

        It "Remove-Utf8Bom strips a leading BOM and leaves clean text alone" {
            . (Join-Path $script:RepoRoot "scripts\install-utils.ps1")
            (Remove-Utf8Bom ([char]0xFEFF + '{}')) | Should -Be '{}'
            (Remove-Utf8Bom '{}') | Should -Be '{}'
            (Remove-Utf8Bom $null) | Should -BeNullOrEmpty
        }
    }

    Context "runtime writers (the generated peon.ps1)" {
        BeforeEach { $script:env = New-TestHookEnv -ConfigOverrides @{ enabled = $true } }
        AfterEach { Remove-TestHookEnv -Dir $script:env.Dir }

        It "--pause leaves config.json with no BOM under Windows PowerShell 5.1" -Skip:$script:SkipNoWinPS {
            & $script:WinPS -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script:env.HookPath -Command "--pause" 2>&1 | Out-Null

            Test-HasUtf8Bom $script:env.ConfigPath | Should -Be $false
            (Get-Content $script:env.ConfigPath -Raw | ConvertFrom-Json).enabled | Should -Be $false
        }

        It "--volume repairs a config.json that already carries a BOM" -Skip:$script:SkipNoWinPS {
            # The runtime hook re-wrote config.json on every peon command, so a
            # user already in the broken state stays broken until a write repairs it.
            $original = Get-Content $script:env.ConfigPath -Raw
            Write-BomFile -Path $script:env.ConfigPath -Text $original
            Test-HasUtf8Bom $script:env.ConfigPath | Should -Be $true

            & $script:WinPS -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $script:env.HookPath -Command "--volume" -Arg1 "0.3" 2>&1 | Out-Null

            Test-HasUtf8Bom $script:env.ConfigPath | Should -Be $false
            (Get-Content $script:env.ConfigPath -Raw | ConvertFrom-Json).volume | Should -Be 0.3
        }
    }

    Context "source guard" {
        # Secondary net only. The byte assertions above are what actually holds;
        # this just makes an accidental reintroduction fail loudly and early.
        It "no PowerShell writer uses Set-Content -Encoding UTF8" {
            $offenders = @(
                Get-ChildItem -Path $script:RepoRoot -Filter "*.ps1" -Recurse |
                    Where-Object { $_.FullName -notmatch '[\\/]tests[\\/]' } |
                    Where-Object { (Get-Content $_.FullName -Raw) -match '(?m)^[^#\r\n]*Set-Content[^\r\n]*-Encoding\s+UTF8' } |
                    ForEach-Object { $_.FullName.Substring($script:RepoRoot.Length + 1) }
            )
            $offenders -join ", " | Should -BeExactly ""
        }
    }
}
