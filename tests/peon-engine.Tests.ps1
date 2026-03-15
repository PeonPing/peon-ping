# Pester 5 functional tests for peon.ps1 (Windows native hook engine)
# Depends on: tests/windows-setup.ps1 (shared test harness)
#
# Run: Invoke-Pester -Path tests/peon-engine.Tests.ps1
#
# These tests validate the harness infrastructure and core peon.ps1 behavior
# by running the actual extracted script in isolated temp directories.

BeforeAll {
    . $PSScriptRoot/windows-setup.ps1
}

# ============================================================
# Harness Smoke Tests -- validate the test infrastructure itself
# ============================================================

Describe "Harness: Extract-PeonHookScript" {
    It "returns non-empty PowerShell content from install.ps1" {
        $script = Extract-PeonHookScript
        $script | Should -Not -BeNullOrEmpty
        $script.Length | Should -BeGreaterThan 100
    }

    It "extracted content has valid PowerShell syntax (zero parse errors)" {
        $script = Extract-PeonHookScript
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($script, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "extracted content contains expected peon.ps1 markers" {
        $script = Extract-PeonHookScript
        # Should contain the event routing switch, CESP category references, and InstallDir
        $script | Should -Match 'session\.start'
        $script | Should -Match 'task\.complete'
        $script | Should -Match 'InstallDir'
    }
}

Describe "Harness: New-PeonTestEnvironment" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "creates peon.ps1 in the test directory" {
        $script:env.PeonPath | Should -Exist
    }

    It "creates config.json with expected defaults" {
        $configPath = Join-Path $script:testDir "config.json"
        $configPath | Should -Exist
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $config.enabled | Should -BeTrue
        $config.volume | Should -Be 0.5
        $config.active_pack | Should -Be "peon"
    }

    It "creates .state.json" {
        $statePath = Join-Path $script:testDir ".state.json"
        $statePath | Should -Exist
    }

    It "creates peon pack with openpeon.json manifest" {
        $manifestPath = Join-Path (Join-Path (Join-Path $script:testDir "packs") "peon") "openpeon.json"
        $manifestPath | Should -Exist
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.name | Should -Be "peon"
    }

    It "creates peon pack sound files" {
        $soundsDir = Join-Path (Join-Path (Join-Path $script:testDir "packs") "peon") "sounds"
        (Join-Path $soundsDir "Hello1.wav") | Should -Exist
        (Join-Path $soundsDir "Done1.wav") | Should -Exist
        (Join-Path $soundsDir "Angry1.wav") | Should -Exist
    }

    It "creates sc_kerrigan pack with manifest and sounds" {
        $kerriganManifest = Join-Path (Join-Path (Join-Path $script:testDir "packs") "sc_kerrigan") "openpeon.json"
        $kerriganManifest | Should -Exist
        (Join-Path (Join-Path (Join-Path (Join-Path $script:testDir "packs") "sc_kerrigan") "sounds") "Hello1.wav") | Should -Exist
    }

    It "creates mock win-play.ps1 in scripts directory" {
        $winPlayPath = Join-Path (Join-Path $script:testDir "scripts") "win-play.ps1"
        $winPlayPath | Should -Exist
        $content = Get-Content $winPlayPath -Raw
        $content | Should -Match '\.audio-log\.txt'
    }

    It "creates VERSION file" {
        $versionPath = Join-Path $script:testDir "VERSION"
        $versionPath | Should -Exist
    }

    It "accepts ConfigOverrides" {
        Remove-PeonTestEnvironment -TestDir $script:testDir
        $env2 = New-PeonTestEnvironment -ConfigOverrides @{ volume = 0.8; enabled = $false }
        try {
            $config = Get-PeonConfig -TestDir $env2.TestDir
            $config.volume | Should -Be 0.8
            $config.enabled | Should -BeFalse
        } finally {
            Remove-PeonTestEnvironment -TestDir $env2.TestDir
        }
    }

    It "accepts StateOverrides" {
        Remove-PeonTestEnvironment -TestDir $script:testDir
        $env2 = New-PeonTestEnvironment -StateOverrides @{ last_stop_time = "2026-01-01T00:00:00Z" }
        try {
            $state = Get-PeonState -TestDir $env2.TestDir
            $state.last_stop_time | Should -Be "2026-01-01T00:00:00Z"
        } finally {
            Remove-PeonTestEnvironment -TestDir $env2.TestDir
        }
    }
}

Describe "Harness: New-CespJson" {
    It "creates valid JSON with hook_event_name and session_id" {
        $json = New-CespJson -HookEventName "SessionStart"
        $parsed = $json | ConvertFrom-Json
        $parsed.hook_event_name | Should -Be "SessionStart"
        $parsed.session_id | Should -Be "test-session-001"
    }

    It "includes notification_type when provided" {
        $json = New-CespJson -HookEventName "Notification" -NotificationType "permission_prompt"
        $parsed = $json | ConvertFrom-Json
        $parsed.notification_type | Should -Be "permission_prompt"
    }

    It "includes cwd when provided" {
        $json = New-CespJson -HookEventName "SessionStart" -Cwd "C:\projects\test"
        $parsed = $json | ConvertFrom-Json
        $parsed.cwd | Should -Be "C:\projects\test"
    }

    It "uses custom session_id when provided" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "custom-sess-42"
        $parsed = $json | ConvertFrom-Json
        $parsed.session_id | Should -Be "custom-sess-42"
    }
}

Describe "Harness: Remove-PeonTestEnvironment" {
    It "removes the test directory" {
        $env1 = New-PeonTestEnvironment
        $dir = $env1.TestDir
        $dir | Should -Exist
        Remove-PeonTestEnvironment -TestDir $dir
        $dir | Should -Not -Exist
    }

    It "handles already-removed directory without error" {
        $env1 = New-PeonTestEnvironment
        $dir = $env1.TestDir
        Remove-PeonTestEnvironment -TestDir $dir
        # Second call should not throw
        { Remove-PeonTestEnvironment -TestDir $dir } | Should -Not -Throw
    }
}

# ============================================================
# Functional Smoke Tests -- peon.ps1 via Invoke-PeonHook
# ============================================================

Describe "Invoke-PeonHook: SessionStart plays a sound" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "exits with code 0 and logs audio" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        # Audio log should contain a path to a peon pack sound
        $result.AudioLog[0] | Should -Match 'peon'
        $result.AudioLog[0] | Should -Match 'Hello'
    }
}

Describe "Invoke-PeonHook: Stop plays a completion sound" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "exits with code 0 and plays a Done sound" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match 'Done'
    }
}

Describe "Invoke-PeonHook: disabled config skips sound" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ enabled = $false }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "exits with code 0 but does not log audio" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 0
    }
}

Describe "Invoke-PeonHook: mock win-play.ps1 logs without playing real audio" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log contains file path and volume" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        # Format is "path|volume"
        $parts = $result.AudioLog[0] -split '\|'
        $parts.Count | Should -Be 2
        $parts[0] | Should -Match '\.wav$'
        # Volume should be a decimal number
        { [double]$parts[1] } | Should -Not -Throw
    }
}

Describe "Invoke-PeonHook: Get-AudioLog helper" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "returns empty array when no audio has been played" {
        $log = Get-AudioLog -TestDir $script:testDir
        $log.Count | Should -Be 0
    }

    It "returns logged entries after a hook invocation" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        # Verify via Invoke-PeonHook result
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        # Verify via Get-AudioLog helper (reads the same file on disk)
        $log = Get-AudioLog -TestDir $script:testDir
        $log.Count | Should -BeGreaterOrEqual 1
    }
}
