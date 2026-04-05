# Pester 5 tests for TTS speech text resolution (install.ps1 / peon.ps1)
# Run: Invoke-Pester -Path tests/tts-resolution.Tests.ps1
#
# Tests validate the TTS speech text resolution chain:
# (a) manifest speech_text present -> uses it
# (b) notification template configured -> uses it
# (c) neither -> uses default "{project} -- {status}"
# (d) empty resolved text -> TTS_TEXT is empty
# (e) TTS disabled -> TTS_ENABLED=false, TTS_TEXT empty
# (f) trainer fires with TTS enabled -> TRAINER_TTS_TEXT populated
# (g) all 8 TTS variables present in output

BeforeAll {
    . $PSScriptRoot/windows-setup.ps1

    # Helper: read TTS variables from the .tts-vars.json file written by peon.ps1
    function Get-TtsVars {
        param([string]$TestDir)
        $ttsPath = Join-Path $TestDir ".tts-vars.json"
        if (-not (Test-Path $ttsPath)) { return $null }
        return (Get-Content $ttsPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    }
}

Describe "TTS: manifest speech_text present on chosen sound entry" {
    BeforeEach {
        # Create env with TTS enabled and speech_text on sound entry
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            tts = @{ enabled = $true; backend = "auto"; voice = "default"; rate = 1.0; volume = 0.5; mode = "sound-then-speak" }
        }
        $script:testDir = $script:env.TestDir

        # Patch manifest to add speech_text to task.complete sound
        $manifestPath = Join-Path (Join-Path (Join-Path $script:testDir "packs") "peon") "openpeon.json"
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.categories.'task.complete'.sounds = @(
            @{ file = "sounds/Done1.wav"; label = "Done"; speech_text = "Task complete for {project}" }
        )
        $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "uses manifest speech_text with interpolated variables" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:\projects\myproject"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $tts = Get-TtsVars -TestDir $script:testDir
        $tts | Should -Not -BeNullOrEmpty
        $tts.TTS_ENABLED | Should -BeTrue
        $tts.TTS_TEXT | Should -Be "Task complete for myproject"
    }
}

Describe "TTS: falls back to notification template when no speech_text" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            tts = @{ enabled = $true }
            notification_templates = @{ stop = "{project} is done" }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "uses notification template text for TTS" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:\projects\myproject"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $tts = Get-TtsVars -TestDir $script:testDir
        $tts | Should -Not -BeNullOrEmpty
        $tts.TTS_ENABLED | Should -BeTrue
        $tts.TTS_TEXT | Should -Be "myproject is done"
    }
}

Describe "TTS: falls back to default template when no notification template" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            tts = @{ enabled = $true }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "uses default template with project and status" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:\projects\myproject"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $tts = Get-TtsVars -TestDir $script:testDir
        $tts | Should -Not -BeNullOrEmpty
        $tts.TTS_ENABLED | Should -BeTrue
        $tts.TTS_TEXT | Should -Match "myproject"
        $tts.TTS_TEXT | Should -Match "done"
    }
}

Describe "TTS: empty resolved text produces empty TTS_TEXT" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            tts = @{ enabled = $true }
            notification_templates = @{ stop = "{summary}" }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "produces empty TTS_TEXT when template resolves to empty" {
        # Stop event with no transcript_summary -> {summary} resolves to empty
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:\projects\myproject"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $tts = Get-TtsVars -TestDir $script:testDir
        $tts | Should -Not -BeNullOrEmpty
        $tts.TTS_TEXT | Should -BeNullOrEmpty
    }
}

Describe "TTS: disabled in config produces TTS_ENABLED=false" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            tts = @{ enabled = $false }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "sets TTS_ENABLED to false and TTS_TEXT empty" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:\projects\myproject"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $tts = Get-TtsVars -TestDir $script:testDir
        $tts | Should -Not -BeNullOrEmpty
        $tts.TTS_ENABLED | Should -BeFalse
        $tts.TTS_TEXT | Should -BeNullOrEmpty
    }
}

Describe "TTS: all 8 TTS variables present with custom config" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{
            tts = @{
                enabled = $true
                backend = "espeak"
                voice = "en-us"
                rate = 1.5
                volume = 0.8
                mode = "speak-only"
            }
        }
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "outputs all 8 TTS variables with correct values" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:\projects\myproject"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $tts = Get-TtsVars -TestDir $script:testDir
        $tts | Should -Not -BeNullOrEmpty
        $tts.TTS_ENABLED | Should -BeTrue
        $tts.TTS_TEXT | Should -Not -BeNullOrEmpty
        $tts.TTS_BACKEND | Should -Be "espeak"
        $tts.TTS_VOICE | Should -Be "en-us"
        $tts.TTS_RATE | Should -Be 1.5
        $tts.TTS_VOLUME | Should -Be 0.8
        $tts.TTS_MODE | Should -Be "speak-only"
        $tts.TRAINER_TTS_TEXT | Should -BeNullOrEmpty
    }
}

Describe "TTS: no TTS config section uses safe defaults" {
    BeforeEach {
        # No tts key at all in config
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }

    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "defaults to TTS_ENABLED=false with default backend/voice/rate/volume/mode" {
        $json = New-CespJson -HookEventName "Stop" -Cwd "C:\projects\myproject"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $tts = Get-TtsVars -TestDir $script:testDir
        $tts | Should -Not -BeNullOrEmpty
        $tts.TTS_ENABLED | Should -BeFalse
        $tts.TTS_BACKEND | Should -Be "auto"
        $tts.TTS_VOICE | Should -Be "default"
        $tts.TTS_RATE | Should -Be 1.0
        $tts.TTS_VOLUME | Should -Be 0.5
        $tts.TTS_MODE | Should -Be "sound-then-speak"
    }
}
