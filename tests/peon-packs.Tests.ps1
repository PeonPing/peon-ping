# Pester 5 functional tests for peon.ps1 pack selection and rotation
# Depends on: tests/windows-setup.ps1 (shared test harness)
#
# Run: Invoke-Pester -Path tests/peon-packs.Tests.ps1
#
# Tests the pack selection override hierarchy in peon.ps1 (Windows native):
#   session_override > path_rules > pack_rotation > default_pack
#
# path_rules uses PowerShell -like operator for glob matching (fnmatch parity).

BeforeAll {
    . $PSScriptRoot/windows-setup.ps1
}

# ============================================================
# Default Pack Fallback (Scenarios 1-3)
# ============================================================

Describe "Default Pack: Scenario 1 - active_pack is used when no overrides active" {
    BeforeAll {
        # Config with active_pack:"peon", no pack_rotation, rotation_mode:"random"
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @()
            pack_rotation_mode = "random"
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows sound from peon pack (path contains 'peon')" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\peon\\'
    }
}

Describe "Default Pack: Scenario 2 - active_pack selects sc_kerrigan" {
    BeforeAll {
        # Config with active_pack:"sc_kerrigan" -- should use that pack
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "sc_kerrigan"
            pack_rotation      = @()
            pack_rotation_mode = "random"
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows sound from sc_kerrigan pack" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

Describe "Default Pack: Scenario 3 - Fallback to 'peon' when active_pack is empty" {
    BeforeAll {
        # Config with empty active_pack -- should fall back to "peon"
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = ""
            pack_rotation      = @()
            pack_rotation_mode = "random"
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows sound from peon pack (fallback)" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\peon\\'
    }
}

# ============================================================
# Path Rules (Scenarios 4-7)
# ============================================================

Describe "Path Rules: Scenario 4 - path_rules glob match selects pack" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @()
            pack_rotation_mode = "random"
            path_rules         = @(
                @{ pattern = "*/myproject/*"; pack = "sc_kerrigan" }
            )
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "selects sc_kerrigan when cwd matches the path_rules pattern" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:/Users/dev/myproject/src"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

Describe "Path Rules: Scenario 5 - path_rules first-match-wins" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @()
            pack_rotation_mode = "random"
            path_rules         = @(
                @{ pattern = "*/myproject/*"; pack = "sc_kerrigan" },
                @{ pattern = "*/my*/*";       pack = "peon" }
            )
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "selects sc_kerrigan (first matching rule) when cwd matches both patterns" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:/Users/dev/myproject/src"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

Describe "Path Rules: Scenario 6 - path_rules missing cwd fallthrough to default_pack" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @()
            pack_rotation_mode = "random"
            path_rules         = @(
                @{ pattern = "*/myproject/*"; pack = "sc_kerrigan" }
            )
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "falls through to default_pack when cwd matches no path_rules pattern" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:/Users/dev/otherproject/src"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\peon\\'
    }
}

Describe "Path Rules: Scenario 7 - path_rules matched pack directory missing fallthrough" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @()
            pack_rotation_mode = "random"
            path_rules         = @(
                @{ pattern = "*/myproject/*"; pack = "ghost_pack" }
            )
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "falls through to default_pack when matched pack directory does not exist" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:/Users/dev/myproject/src"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\peon\\'
    }
}

# ============================================================
# Session Override (Scenarios 8-10)
# ============================================================

Describe "Session Override: Scenario 8 - session_override mode uses per-session pack from state" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation_mode = "session_override"
        } -StateOverrides @{
            session_packs = @{
                "test-session-001" = @{
                    pack      = "sc_kerrigan"
                    last_used = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                }
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows sc_kerrigan pack sound (session override active)" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "test-session-001"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

Describe "Session Override: Scenario 9 - session_override beats pack_rotation" {
    BeforeAll {
        # Config has pack_rotation with peon, but session_override assigns sc_kerrigan
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @("peon")
            pack_rotation_mode = "session_override"
        } -StateOverrides @{
            session_packs = @{
                "test-session-001" = @{
                    pack      = "sc_kerrigan"
                    last_used = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                }
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows sc_kerrigan (session_override wins over rotation)" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "test-session-001"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

Describe "Session Override: Scenario 10 - session_override falls back to active_pack when session not in state" {
    BeforeAll {
        # session_override mode but the session is not in state -- should fall back to active_pack
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation_mode = "session_override"
        } -StateOverrides @{
            session_packs = @{
                "other-session" = @{
                    pack      = "sc_kerrigan"
                    last_used = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                }
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows peon pack (active_pack fallback, session not matched)" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "unmatched-session-xyz"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\peon\\'
    }
}

# ============================================================
# Session Override: agentskill alias
# ============================================================

Describe "Session Override: agentskill mode works identically to session_override" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation_mode = "agentskill"
        } -StateOverrides @{
            session_packs = @{
                "test-session-001" = @{
                    pack      = "sc_kerrigan"
                    last_used = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                }
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "audio log shows sc_kerrigan (agentskill mode uses session_packs)" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "test-session-001"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

# ============================================================
# Session Override: missing pack falls back to default
# ============================================================

Describe "Session Override: missing pack directory falls back to active_pack" {
    BeforeAll {
        # Session points to "ghost" pack that does not exist
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation_mode = "session_override"
        } -StateOverrides @{
            session_packs = @{
                "test-session-001" = @{
                    pack      = "ghost"
                    last_used = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                }
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "falls through to peon when session pack directory does not exist" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "test-session-001"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\peon\\'
    }

    It "cleans up the invalid session entry from state" {
        $state = Get-PeonState -TestDir $script:testDir
        # The ghost session entry should have been removed
        if ($state.session_packs -and $state.session_packs.PSObject.Properties.Name -contains "test-session-001") {
            $state.session_packs."test-session-001" | Should -BeNullOrEmpty
        }
    }
}

# ============================================================
# Session Override: default key (Cursor users)
# ============================================================

Describe "Session Override: 'default' key in session_packs for Cursor users" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation_mode = "session_override"
        } -StateOverrides @{
            session_packs = @{
                "default" = @{
                    pack      = "sc_kerrigan"
                    last_used = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                }
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "uses the default session pack for an unmatched session" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "unknown-cursor-session"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

# ============================================================
# Pack Rotation (Scenarios 11-12)
# ============================================================

Describe "Pack Rotation: Scenario 11 - rotation selects from array" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @("peon", "sc_kerrigan")
            pack_rotation_mode = "random"
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "plays sounds from at least 2 different packs over 10 invocations" {
        $packs = @{}
        for ($i = 1; $i -le 10; $i++) {
            # Clear state debounce between runs -- use unique sessions
            $staleEpoch = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - 10
            $stateRaw = Get-Content (Join-Path $script:testDir ".state.json") -Raw | ConvertFrom-Json
            $stateRaw | Add-Member -NotePropertyName "last_stop_time" -NotePropertyValue $staleEpoch -Force
            $stateRaw | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:testDir ".state.json") -Encoding UTF8

            $json = New-CespJson -HookEventName "Stop" -SessionId "rotation-sess-$i"
            $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
            $result.ExitCode | Should -Be 0
            if ($result.AudioLog.Count -ge 1) {
                $audioPath = ($result.AudioLog[0] -split '\|')[0]
                if ($audioPath -match '\\packs\\([^\\]+)\\') {
                    $packName = $matches[1]
                    $packs[$packName] = $true
                }
            }
        }
        # With 2 packs and 10 random picks, probability of missing one is (0.5)^10 = 0.1%
        $packs.Count | Should -BeGreaterOrEqual 2
    }
}

Describe "Pack Rotation: Scenario 12 - rotation with single-pack array uses that pack" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation      = @("sc_kerrigan")
            pack_rotation_mode = "random"
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "always selects sc_kerrigan when it is the only rotation entry" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

# ============================================================
# Edge Cases
# ============================================================

Describe "Edge Case: empty pack_rotation array uses active_pack" {
    BeforeAll {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "sc_kerrigan"
            pack_rotation      = @()
            pack_rotation_mode = "random"
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "falls through to active_pack when rotation list is empty" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

Describe "Edge Case: missing pack_rotation_mode defaults to random" {
    BeforeAll {
        # No pack_rotation_mode key -- should default to "random" and use active_pack
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack   = "sc_kerrigan"
            pack_rotation = @()
        }
        $script:testDir = $script:env.TestDir

        # Remove pack_rotation_mode from config entirely
        $configPath = Join-Path $script:testDir "config.json"
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
        $config.PSObject.Properties.Remove("pack_rotation_mode")
        $config | ConvertTo-Json -Depth 5 | Set-Content $configPath -Encoding UTF8
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "uses active_pack when pack_rotation_mode is absent" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}

Describe "Edge Case: session_override with old string format (migration)" {
    BeforeAll {
        # Old format: session_packs value is just a string, not a dict
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            active_pack        = "peon"
            pack_rotation_mode = "session_override"
        } -StateOverrides @{
            session_packs = @{
                "test-session-001" = "sc_kerrigan"
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterAll {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "handles legacy string format in session_packs and selects correct pack" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "test-session-001"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $result.AudioLog.Count | Should -BeGreaterOrEqual 1
        $result.AudioLog[0] | Should -Match '\\packs\\sc_kerrigan\\'
    }
}
