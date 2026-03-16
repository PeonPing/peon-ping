# Pester 5 tests for hook-handle-use.ps1 and win-play.ps1 security boundaries
# Run: Invoke-Pester -Path tests/peon-security.Tests.ps1
#
# These tests validate:
# - Pack name input validation (path traversal, shell injection)
# - Session ID sanitization
# - Config and state mutation correctness
# - Hook mode vs CLI mode behavior
# - win-play.ps1 WAV/MP3 branching
# - Volume clamping at boundaries
# - Player priority chain (ffplay -> mpv -> vlc -> silent exit)

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:ScriptsDir = Join-Path $script:RepoRoot "scripts"
    $script:HookHandleUse = Join-Path $script:ScriptsDir "hook-handle-use.ps1"
    $script:WinPlay = Join-Path $script:ScriptsDir "win-play.ps1"

    # PS 5.1 compatible helper: create isolated peon-ping directory structure
    function script:New-PeonTestEnv {
        $id = [guid]::NewGuid().ToString('N').Substring(0,8)
        $base = Join-Path ([System.IO.Path]::GetTempPath()) "peon-sec-$id"
        New-Item -ItemType Directory -Path $base -Force | Out-Null

        $claudeDir = Join-Path $base ".claude"
        $hooksDir = Join-Path $claudeDir "hooks"
        $peonDir = Join-Path $hooksDir "peon-ping"
        $packsDir = Join-Path $peonDir "packs"
        New-Item -ItemType Directory -Path $peonDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $packsDir "peon") -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $packsDir "peasant") -Force | Out-Null

        # Minimal config.json
        $configPath = Join-Path $peonDir "config.json"
        @{ pack_rotation_mode = "random"; pack_rotation = @(); volume = 0.7 } |
            ConvertTo-Json -Depth 5 | Set-Content $configPath -NoNewline

        # Minimal .state.json
        $statePath = Join-Path $peonDir ".state.json"
        @{ session_packs = @{} } |
            ConvertTo-Json -Depth 5 | Set-Content $statePath -NoNewline

        return @{
            Base     = $base
            Claude   = $claudeDir
            PeonDir  = $peonDir
            Config   = $configPath
            State    = $statePath
            PacksDir = $packsDir
        }
    }

    function script:Remove-PeonTestEnv {
        param($Env)
        if ($Env -and $Env.Base -and (Test-Path $Env.Base)) {
            Remove-Item -Recurse -Force $Env.Base -ErrorAction SilentlyContinue
        }
    }

    # Helper: run hook-handle-use.ps1 in CLI mode via a temp wrapper script
    # Using a wrapper script avoids exit-code and escaping issues with -Command
    function script:Invoke-HookCli {
        param([string]$PackName, [string]$ConfigDir)
        $id = [guid]::NewGuid().ToString('N').Substring(0,8)
        $wrapper = Join-Path ([System.IO.Path]::GetTempPath()) "peon-cli-$id.ps1"
        @"
`$env:CLAUDE_CONFIG_DIR = '$ConfigDir'
& '$($script:HookHandleUse)' '$PackName'
exit `$LASTEXITCODE
"@ | Set-Content $wrapper
        $output = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapper 2>&1
        $code = $LASTEXITCODE
        Remove-Item $wrapper -ErrorAction SilentlyContinue
        return @{ Output = $output; ExitCode = $code }
    }

    # Helper: run hook-handle-use.ps1 in hook mode (stdin JSON)
    # Uses cmd.exe to pipe JSON into PowerShell's stdin so [Console]::OpenStandardInput() works
    function script:Invoke-HookStdin {
        param([string]$Json, [string]$ConfigDir)
        $id = [guid]::NewGuid().ToString('N').Substring(0,8)
        $tmpJson = Join-Path ([System.IO.Path]::GetTempPath()) "peon-stdin-$id.json"
        $wrapper = Join-Path ([System.IO.Path]::GetTempPath()) "peon-hook-$id.ps1"
        $Json | Set-Content $tmpJson -NoNewline
        @"
`$env:CLAUDE_CONFIG_DIR = '$ConfigDir'
& '$($script:HookHandleUse)'
exit `$LASTEXITCODE
"@ | Set-Content $wrapper
        # Use cmd /c to pipe file content into PowerShell's raw stdin
        $output = cmd.exe /c "type `"$tmpJson`" | powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$wrapper`"" 2>&1
        $code = $LASTEXITCODE
        Remove-Item $tmpJson -ErrorAction SilentlyContinue
        Remove-Item $wrapper -ErrorAction SilentlyContinue
        return @{ Output = $output; ExitCode = $code }
    }

    # Helper: run win-play.ps1 with specified PATH
    function script:Invoke-WinPlay {
        param([string]$AudioPath, [double]$Vol, [string]$MockPath)
        $id = [guid]::NewGuid().ToString('N').Substring(0,8)
        $wrapper = Join-Path ([System.IO.Path]::GetTempPath()) "peon-wp-$id.ps1"
        if ($MockPath) {
            @"
`$env:PATH = '$MockPath'
& '$($script:WinPlay)' -path '$AudioPath' -vol $Vol
exit `$LASTEXITCODE
"@ | Set-Content $wrapper
        } else {
            @"
& '$($script:WinPlay)' -path '$AudioPath' -vol $Vol
exit `$LASTEXITCODE
"@ | Set-Content $wrapper
        }
        $output = powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapper 2>&1
        $code = $LASTEXITCODE
        Remove-Item $wrapper -ErrorAction SilentlyContinue
        return @{ Output = $output; ExitCode = $code }
    }

    # Helper: create a mock player .cmd that logs its arguments
    function script:New-MockPlayer {
        param([string]$Name, [string]$Dir, [string]$LogFile)
        $batPath = Join-Path $Dir "$Name.cmd"
        # Batch file that appends player name and all args to log
        $content = "@echo off`r`necho $Name %* >> `"$LogFile`""
        Set-Content -Path $batPath -Value $content
        return $batPath
    }
}

# ============================================================
# hook-handle-use.ps1: Input Validation (Scenarios 1-6)
# ============================================================

Describe "hook-handle-use.ps1: Input Validation" {
    BeforeEach {
        $script:testEnv = script:New-PeonTestEnv
    }

    AfterEach {
        script:Remove-PeonTestEnv -Env $script:testEnv
    }

    # Scenario 1: Valid pack name in CLI mode sets session pack
    It "Scenario 1: Valid pack name in CLI mode sets session pack" {
        $r = script:Invoke-HookCli -PackName "peon" -ConfigDir $script:testEnv.Claude
        $r.ExitCode | Should -Be 0

        $config = Get-Content $script:testEnv.Config -Raw | ConvertFrom-Json
        $config.pack_rotation_mode | Should -Be "session_override"

        $state = Get-Content $script:testEnv.State -Raw | ConvertFrom-Json
        $state.session_packs.default.pack | Should -Be "peon"
    }

    # Scenario 2: Path traversal in pack name is rejected
    It "Scenario 2: Path traversal in pack name is rejected" {
        $r = script:Invoke-HookCli -PackName "../../../etc/passwd" -ConfigDir $script:testEnv.Claude
        $r.ExitCode | Should -Be 1
        ($r.Output -join "`n") | Should -Match "Invalid pack name"

        # Config unchanged
        $config = Get-Content $script:testEnv.Config -Raw | ConvertFrom-Json
        $config.pack_rotation_mode | Should -Be "random"
    }

    # Scenario 3: Pack name with shell metacharacters is rejected
    It "Scenario 3: Shell metacharacters in pack name are rejected" {
        $r = script:Invoke-HookCli -PackName 'peon;rm -rf /' -ConfigDir $script:testEnv.Claude
        $r.ExitCode | Should -Be 1
        ($r.Output -join "`n") | Should -Match "Invalid pack name"
    }

    # Scenario 4: Session ID with invalid characters is sanitized to "default"
    It "Scenario 4: Invalid session_id is sanitized to default" {
        $json = @{
            prompt = "/peon-ping-use peon"
            session_id = "../../bad"
        } | ConvertTo-Json -Compress

        $r = script:Invoke-HookStdin -Json $json -ConfigDir $script:testEnv.Claude
        $state = Get-Content $script:testEnv.State -Raw | ConvertFrom-Json
        $state.session_packs.default.pack | Should -Be "peon"
        # Malicious key must not exist
        $state.session_packs.PSObject.Properties.Name | Should -Not -Contain "../../bad"
    }

    # Scenario 5: Nonexistent pack name returns error with available pack list
    It "Scenario 5: Nonexistent pack lists available packs" {
        $r = script:Invoke-HookCli -PackName "nonexistent" -ConfigDir $script:testEnv.Claude
        $r.ExitCode | Should -Be 1
        $text = $r.Output -join "`n"
        $text | Should -Match "not found"
        $text | Should -Match "peon"
    }

    # Scenario 6: Hook mode with /peon-ping-use command extracts pack name
    It "Scenario 6: Hook mode extracts pack from /peon-ping-use command" {
        $json = @{
            prompt = "/peon-ping-use peasant"
            conversation_id = "test-session-123"
        } | ConvertTo-Json -Compress

        $r = script:Invoke-HookStdin -Json $json -ConfigDir $script:testEnv.Claude
        $response = ($r.Output -join "") | ConvertFrom-Json
        $response.continue | Should -Be $false

        $state = Get-Content $script:testEnv.State -Raw | ConvertFrom-Json
        $state.session_packs.'test-session-123'.pack | Should -Be "peasant"
    }
}

# ============================================================
# hook-handle-use.ps1: State Mutations (Scenarios 7-9)
# ============================================================

Describe "hook-handle-use.ps1: State Mutations" {
    BeforeEach {
        $script:testEnv = script:New-PeonTestEnv
    }

    AfterEach {
        script:Remove-PeonTestEnv -Env $script:testEnv
    }

    # Scenario 7: Sets pack_rotation_mode to session_override in config
    It "Scenario 7: Sets pack_rotation_mode to session_override in config" {
        script:Invoke-HookCli -PackName "peon" -ConfigDir $script:testEnv.Claude | Out-Null
        $config = Get-Content $script:testEnv.Config -Raw | ConvertFrom-Json
        $config.pack_rotation_mode | Should -Be "session_override"
    }

    # Scenario 8: Adds pack to pack_rotation array if not present
    It "Scenario 8: Adds pack to pack_rotation array" {
        script:Invoke-HookCli -PackName "peon" -ConfigDir $script:testEnv.Claude | Out-Null
        $config = Get-Content $script:testEnv.Config -Raw | ConvertFrom-Json
        $config.pack_rotation | Should -Contain "peon"
    }

    # Scenario 9: Non-/peon-ping-use prompts pass through (continue:true)
    It "Scenario 9: Non-command prompts pass through with continue:true" {
        $json = @{
            prompt = "explain this code"
            session_id = "abc"
        } | ConvertTo-Json -Compress

        $r = script:Invoke-HookStdin -Json $json -ConfigDir $script:testEnv.Claude
        $response = ($r.Output -join "") | ConvertFrom-Json
        $response.continue | Should -Be $true

        # Config unchanged
        $config = Get-Content $script:testEnv.Config -Raw | ConvertFrom-Json
        $config.pack_rotation_mode | Should -Be "random"
    }
}

# ============================================================
# win-play.ps1: Volume Clamping and Player Chain (Scenarios 10-16)
# ============================================================

Describe "win-play.ps1: WAV/MP3 Branching and Player Chain" {
    BeforeEach {
        $id = [guid]::NewGuid().ToString('N').Substring(0,8)
        $script:wpDir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-wp-$id"
        New-Item -ItemType Directory -Path $script:wpDir -Force | Out-Null

        # Create dummy audio files (44 bytes each)
        [byte[]]$emptyBytes = @(0) * 44
        [System.IO.File]::WriteAllBytes((Join-Path $script:wpDir "test.wav"), $emptyBytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:wpDir "test.mp3"), $emptyBytes)

        # Mock player directory
        $script:mockDir = Join-Path $script:wpDir "mock-players"
        New-Item -ItemType Directory -Path $script:mockDir -Force | Out-Null

        $script:mockLog = Join-Path $script:wpDir "player.log"
    }

    AfterEach {
        Remove-Item -Recurse -Force $script:wpDir -ErrorAction SilentlyContinue
    }

    # Scenario 10: WAV file uses SoundPlayer path (not CLI players)
    It "Scenario 10: WAV file takes SoundPlayer branch, not CLI players" {
        script:New-MockPlayer -Name "ffplay" -Dir $script:mockDir -LogFile $script:mockLog
        $wavFile = Join-Path $script:wpDir "test.wav"
        # SoundPlayer will throw on dummy WAV -- that's expected; we verify ffplay is NOT called
        script:Invoke-WinPlay -AudioPath $wavFile -Vol 0.5 -MockPath "$($script:mockDir);$env:PATH" | Out-Null

        if (Test-Path $script:mockLog) {
            $logContent = Get-Content $script:mockLog -Raw
            $logContent | Should -Not -Match "ffplay"
        }
        # No log file also means ffplay was not called -- pass
    }

    # Scenario 11: MP3 file tries ffplay first with correct volume
    It "Scenario 11: MP3 file uses ffplay with volume = vol * 100" {
        script:New-MockPlayer -Name "ffplay" -Dir $script:mockDir -LogFile $script:mockLog
        $mp3File = Join-Path $script:wpDir "test.mp3"
        script:Invoke-WinPlay -AudioPath $mp3File -Vol 0.7 -MockPath "$($script:mockDir);$env:PATH" | Out-Null

        Test-Path $script:mockLog | Should -Be $true
        $logContent = Get-Content $script:mockLog -Raw
        $logContent | Should -Match "ffplay"
        # 0.7 * 100 = 70
        $logContent | Should -Match "-volume 70"
    }

    # Scenario 12: Volume boundary vol=0.0 -> ffplay -volume 0
    It "Scenario 12: Volume clamped to 0 for ffplay when vol=0.0" {
        script:New-MockPlayer -Name "ffplay" -Dir $script:mockDir -LogFile $script:mockLog
        $mp3File = Join-Path $script:wpDir "test.mp3"
        script:Invoke-WinPlay -AudioPath $mp3File -Vol 0.0 -MockPath "$($script:mockDir);$env:PATH" | Out-Null

        $logContent = Get-Content $script:mockLog -Raw
        $logContent | Should -Match "-volume 0"
    }

    # Scenario 13: Volume boundary vol=1.0 -> ffplay -volume 100
    It "Scenario 13: Volume clamped to 100 for ffplay when vol=1.0" {
        script:New-MockPlayer -Name "ffplay" -Dir $script:mockDir -LogFile $script:mockLog
        $mp3File = Join-Path $script:wpDir "test.mp3"
        script:Invoke-WinPlay -AudioPath $mp3File -Vol 1.0 -MockPath "$($script:mockDir);$env:PATH" | Out-Null

        $logContent = Get-Content $script:mockLog -Raw
        $logContent | Should -Match "-volume 100"
    }

    # Scenario 14: Falls through to mpv when ffplay not available
    It "Scenario 14: Falls through to mpv when no ffplay" {
        script:New-MockPlayer -Name "mpv" -Dir $script:mockDir -LogFile $script:mockLog
        $mp3File = Join-Path $script:wpDir "test.mp3"
        # Only mock dir in PATH, so ffplay is not found
        script:Invoke-WinPlay -AudioPath $mp3File -Vol 0.5 -MockPath $script:mockDir | Out-Null

        Test-Path $script:mockLog | Should -Be $true
        $logContent = Get-Content $script:mockLog -Raw
        $logContent | Should -Match "mpv"
        $logContent | Should -Match "--volume=50"
    }

    # Scenario 15: Falls through to vlc when ffplay and mpv not available
    It "Scenario 15: Falls through to vlc when no ffplay or mpv" {
        script:New-MockPlayer -Name "vlc" -Dir $script:mockDir -LogFile $script:mockLog
        $mp3File = Join-Path $script:wpDir "test.mp3"
        script:Invoke-WinPlay -AudioPath $mp3File -Vol 0.5 -MockPath $script:mockDir | Out-Null

        Test-Path $script:mockLog | Should -Be $true
        $logContent = Get-Content $script:mockLog -Raw
        $logContent | Should -Match "vlc"
        # vol * 2.0 = 1.0 with InvariantCulture
        $logContent | Should -Match "--gain 1(\.\d+)?(\s|$)"
    }

    # Scenario 16: Exits silently when no player available
    It "Scenario 16: Exits silently when no player available" {
        $mp3File = Join-Path $script:wpDir "test.mp3"
        # Only mock dir (empty) in PATH -- no players
        $r = script:Invoke-WinPlay -AudioPath $mp3File -Vol 0.5 -MockPath $script:mockDir
        $r.ExitCode | Should -Be 0
        if ($r.Output) {
            ($r.Output -join "`n") | Should -Not -Match "(?i)error|exception"
        }
    }
}
