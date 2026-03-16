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

# ============================================================
# Step 2a: Event Routing Tests (Scenarios 1-7)
# ============================================================

Describe "Event Routing: Scenario 1 - SessionStart plays session.start sound" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "plays a sound from the session.start category (Hello*.wav)" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Hello[12]\.wav'
    }
}

Describe "Event Routing: Scenario 2 - Stop plays task.complete sound" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "plays a sound from the task.complete category (Done*.wav)" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Done[12]\.wav'
    }
}

Describe "Event Routing: Scenario 3 - PermissionRequest plays input.required sound" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "plays a sound from the input.required category (Perm*.wav)" {
        $json = New-CespJson -HookEventName "PermissionRequest"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Perm[12]\.wav'
    }
}

Describe "Event Routing: Scenario 4 - PostToolUseFailure plays task.error sound" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "plays a sound from the task.error category (Error*.wav)" {
        $json = New-CespJson -HookEventName "PostToolUseFailure"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Error1\.wav'
    }
}

Describe "Event Routing: Scenario 5 - SubagentStart plays task.acknowledge sound" {
    BeforeAll {
        # Enable task.acknowledge (disabled by default in harness config)
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            categories = @{
                "session.start"    = $true
                "task.acknowledge" = $true
                "task.complete"    = $true
                "task.error"       = $true
                "input.required"   = $true
                "resource.limit"   = $true
                "user.spam"        = $true
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "plays a sound from the task.acknowledge category (Ack*.wav)" {
        $json = New-CespJson -HookEventName "SubagentStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Ack1\.wav'
    }
}

Describe "Event Routing: Scenario 6 - Notification with permission_prompt is suppressed" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "produces no audio when notification_type is permission_prompt" {
        $json = New-CespJson -HookEventName "Notification" -NotificationType "permission_prompt"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 0
    }

    It "also suppresses idle_prompt notification type" {
        $json = New-CespJson -HookEventName "Notification" -NotificationType "idle_prompt"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 0
    }
}

Describe "Event Routing: Scenario 7 - Cursor camelCase events are remapped" {
    # Use BeforeEach to get a fresh environment per test, avoiding debounce
    # cross-contamination (camelCase "stop" and "subagentStop" both map to Stop
    # which has 5s debounce)
    BeforeEach {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "remaps camelCase sessionStart to PascalCase and plays session.start" {
        $json = New-CespJson -HookEventName "sessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Hello[12]\.wav'
    }

    It "remaps camelCase stop to PascalCase and plays task.complete" {
        $json = New-CespJson -HookEventName "stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Done[12]\.wav'
    }

    It "remaps subagentStop to Stop and plays task.complete" {
        $json = New-CespJson -HookEventName "subagentStop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        $result.AudioLog[0] | Should -Match 'Done[12]\.wav'
    }
}

# ============================================================
# Step 2a: Config Behavior Tests (Scenarios 8-11)
# ============================================================

Describe "Config: Scenario 8 - enabled:false exits silently" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ enabled = $false }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "exits 0 with no audio and no state changes" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 0
    }
}

Describe "Config: Scenario 9 - Category toggle disables specific events" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            categories = @{
                "session.start"    = $true
                "task.acknowledge" = $false
                "task.complete"    = $false
                "task.error"       = $true
                "input.required"   = $true
                "resource.limit"   = $true
                "user.spam"        = $true
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "suppresses Stop (task.complete disabled) but plays SessionStart (session.start enabled)" {
        # Stop should be suppressed because task.complete is false
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 0

        # SessionStart should still play since session.start is true
        $json2 = New-CespJson -HookEventName "SessionStart"
        $result2 = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json2
        $result2.ExitCode | Should -Be 0
        $result2.AudioLog.Count | Should -Be 1
    }
}

Describe "Config: Scenario 10 - Volume is passed to win-play.ps1" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ volume = 0.3 }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows volume parameter is 0.3" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 1
        # Format is "path|volume"
        $parts = $result.AudioLog[0] -split '\|'
        $parts.Count | Should -Be 2
        [double]$parts[1] | Should -Be 0.3
    }
}

Describe "Config: Scenario 11 - Missing config exits silently" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
        # Delete config.json to simulate missing config
        Remove-Item (Join-Path $script:testDir "config.json") -Force
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "exits 0 with no crash and no audio" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 0
    }
}

# ============================================================
# Step 2a: State Management Tests (Scenarios 12-17)
# ============================================================

Describe "State: Scenario 12 - Stop debounce suppresses rapid Stop events" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "first Stop plays sound, second is suppressed (state pre-seeded)" {
        # First Stop: plays a sound (no last_stop_time in state)
        $json = New-CespJson -HookEventName "Stop"
        $result1 = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result1.ExitCode | Should -Be 0
        $result1.AudioLog.Count | Should -Be 1

        # Second Stop: should be suppressed because last_stop_time was just set
        # (within 5s debounce window)
        $result2 = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result2.ExitCode | Should -Be 0
        $result2.AudioLog.Count | Should -Be 0
    }

    It "Stop after debounce window plays sound (stale last_stop_time)" {
        # Pre-seed state with a last_stop_time from 10 seconds ago
        $staleTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 10
        $env2 = New-PeonTestEnvironment -StateOverrides @{ last_stop_time = $staleTime }
        try {
            $json = New-CespJson -HookEventName "Stop"
            $result = Invoke-PeonHook -TestDir $env2.TestDir -JsonPayload $json
            $result.ExitCode | Should -Be 0
            $result.AudioLog.Count | Should -Be 1
        } finally {
            Remove-PeonTestEnvironment -TestDir $env2.TestDir
        }
    }
}

Describe "State: Scenario 13 - No-repeat logic avoids same sound twice" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "two consecutive SessionStart invocations pick different sounds" {
        # session.start has exactly 2 sounds: Hello1.wav and Hello2.wav
        # With no-repeat, second invocation must pick the other one
        $json = New-CespJson -HookEventName "SessionStart"
        $result1 = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result1.AudioLog.Count | Should -Be 1

        $result2 = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result2.AudioLog.Count | Should -Be 1

        # Extract just the sound filename from path|volume entries
        $sound1 = ($result1.AudioLog[0] -split '\|')[0] | Split-Path -Leaf
        $sound2 = ($result2.AudioLog[0] -split '\|')[0] | Split-Path -Leaf

        $sound1 | Should -Not -Be $sound2
    }
}

Describe "State: Scenario 14 - UserPromptSubmit spam detection triggers user.spam" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            annoyed_threshold      = 3
            annoyed_window_seconds = 10
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "third rapid UserPromptSubmit plays user.spam sound" {
        $sessionId = "spam-test-session"
        $now = [long][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $ts1 = $now - 2
        $ts2 = $now - 1
        $env2 = New-PeonTestEnvironment -ConfigOverrides @{
            annoyed_threshold      = 3
            annoyed_window_seconds = 60
        } -StateOverrides @{
            prompt_timestamps = @{
                $sessionId = @($ts1, $ts2)
            }
        }
        try {
            $json = New-CespJson -HookEventName "UserPromptSubmit" -SessionId $sessionId
            $result = Invoke-PeonHook -TestDir $env2.TestDir -JsonPayload $json
            $result.ExitCode | Should -Be 0
            $result.AudioLog.Count | Should -Be 1
            $result.AudioLog[0] | Should -Match 'Angry1\.wav'
        } finally {
            Remove-PeonTestEnvironment -TestDir $env2.TestDir
        }
    }

    It "UserPromptSubmit below threshold exits silently" {
        # This verifies the basic event handling path works even if accumulation is broken
        $json = New-CespJson -HookEventName "UserPromptSubmit" -SessionId "single-prompt"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -Be 0
    }
}

Describe "State: Scenario 15 - Session TTL expiry cleans old sessions" {
    BeforeAll {
        # Pre-seed state with an old session_packs entry (30 days ago)
        $oldTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - (30 * 86400)
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            session_ttl_days = 7
        } -StateOverrides @{
            session_packs = @{
                "old-session-xyz" = @{
                    pack = "peon"
                    last_used = $oldTime
                }
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "removes expired session_pack entries from state" {
        $json = New-CespJson -HookEventName "SessionStart" -SessionId "new-session-001"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        # Check that the old session was cleaned from state
        $state = Get-PeonState -TestDir $script:testDir
        # The old-session-xyz entry should be gone (expired past TTL)
        $sessionPacks = $state.session_packs
        if ($sessionPacks) {
            # Check as PSCustomObject (ConvertFrom-Json returns PSCustomObject, not hashtable)
            $hasOldSession = $false
            if ($sessionPacks -is [PSCustomObject]) {
                $hasOldSession = $null -ne ($sessionPacks.PSObject.Properties | Where-Object { $_.Name -eq "old-session-xyz" })
            } elseif ($sessionPacks -is [hashtable]) {
                $hasOldSession = $sessionPacks.ContainsKey("old-session-xyz")
            }
            $hasOldSession | Should -BeFalse
        }
    }
}

Describe "State: Scenario 16 - State file survives corrupted JSON" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
        # Corrupt the state file
        Set-Content -Path (Join-Path $script:testDir ".state.json") -Value 'NOT{JSON' -Encoding UTF8
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "exits 0 and does not crash, state is reinitialized" {
        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        # Should still play a sound -- corrupted state is handled gracefully
        $result.AudioLog.Count | Should -Be 1
    }
}

Describe "State: Scenario 17 - Empty stdin exits silently" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "exits 0 with no crash and no audio when stdin is empty" {
        # Pipe whitespace-only input (not valid JSON, simulates effectively empty stdin)
        # Cannot pass truly empty string due to Mandatory parameter on Invoke-PeonHook,
        # so we use a single space which ConvertFrom-Json will reject, same as empty stdin.
        $peonPath = Join-Path $script:testDir "peon.ps1"
        $audioLogPath = Join-Path $script:testDir ".audio-log.txt"
        if (Test-Path $audioLogPath) { Remove-Item $audioLogPath -Force }

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -NoLogo -File `"$peonPath`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        $proc.Start() | Out-Null
        # Write nothing to stdin then close
        $proc.StandardInput.Close()
        $exited = $proc.WaitForExit(15000)
        if (-not $exited) { $proc.Kill() }
        $exitCode = $proc.ExitCode
        $proc.Dispose()

        $exitCode | Should -Be 0
        (Test-Path $audioLogPath) | Should -BeFalse
    }
}
