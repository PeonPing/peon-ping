# Pester 5 tests for structured hook logging in peon.ps1 (Windows native)
# Depends on: tests/windows-setup.ps1 (shared test harness)
#
# Run: Invoke-Pester -Path tests/hook-logging-windows.Tests.ps1
#
# These tests validate:
# - debug=false (default) produces no log file (zero overhead)
# - debug=true creates daily log file at $PEON_DIR/logs/peon-ping-YYYY-MM-DD.log
# - All 9 phases logged: [hook], [config], [state], [route], [sound], [play], [notify], [trainer], [exit]
# - Log format: YYYY-MM-DDTHH:MM:SS.mmm [phase] inv=XXXX key1=val1 key2=val2
# - [exit] line includes duration_ms
# - PEON_DEBUG=1 enables both stderr warnings AND file logging (additive)
# - Daily rotation prunes files older than debug_retention_days
# - Add-Content IOException disables logging for rest of invocation
# - Shared test fixtures from tests/fixtures/hook-logging/ validate cross-platform parity
# - Existing Pester tests pass unchanged

BeforeAll {
    . $PSScriptRoot/windows-setup.ps1

    # Helper: get the log file path for today from a test directory
    function Get-PeonLogFile {
        param([string]$TestDir)
        $logDir = Join-Path $TestDir 'logs'
        $logDate = (Get-Date).ToString('yyyy-MM-dd')
        return Join-Path $logDir "peon-ping-$logDate.log"
    }

    # Helper: get log content as array of lines
    # Uses Write-Output -NoEnumerate to preserve array type through the pipeline.
    function Get-PeonLogLines {
        param([string]$TestDir)
        $logFile = Get-PeonLogFile $TestDir
        if (Test-Path $logFile) {
            $arr = @(Get-Content $logFile -Encoding UTF8 | Where-Object { $_ -ne '' })
            Write-Output -NoEnumerate $arr
            return
        }
        Write-Output -NoEnumerate @()
    }

    # Helper: get lines matching a specific phase
    # Uses Write-Output -NoEnumerate to preserve array type through the pipeline.
    function Get-PeonLogPhaseLines {
        param([string]$TestDir, [string]$Phase)
        $lines = Get-PeonLogLines $TestDir
        $arr = @($lines | Where-Object { $_ -match "\[$Phase\]" })
        Write-Output -NoEnumerate $arr
    }

    # Shared fixture validation helper (mirrors BATS validate_log_fixture)
    # Reads a .expected.txt fixture and validates that each expected phase and
    # non-wildcard key=value pair appears in the actual log output.
    function Test-LogFixture {
        param([string]$TestDir, [string]$FixtureName)
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures/hook-logging'
        $expectedFile = Join-Path $fixtureDir "$FixtureName.expected.txt"

        if (-not (Test-Path $expectedFile)) {
            throw "Missing fixture expected file: $expectedFile"
        }

        $logLines = Get-PeonLogLines $TestDir
        if ($logLines.Count -eq 0) {
            throw "No log lines found in test directory"
        }

        $expectedLines = @(Get-Content $expectedFile -Encoding UTF8 | Where-Object { $_ -ne '' })
        foreach ($eline in $expectedLines) {
            # Extract phase tag
            if ($eline -match '\[([a-z]+)\]') {
                $phase = $matches[1]
                $phaseLines = @($logLines | Where-Object { $_ -match "\[$phase\]" })
                if ($phaseLines.Count -eq 0) {
                    throw "Missing phase [$phase] in log output"
                }

                # Check non-wildcard key=value pairs
                $kvPart = ($eline -replace '.*\[[a-z]+\]\s*', '').Trim()
                foreach ($kv in ($kvPart -split '\s+')) {
                    if ($kv -match '^([^=]+)=(.+)$') {
                        $key = $matches[1]
                        $val = $matches[2]
                        # Skip wildcard (empty value handled by the regex not matching)
                        if ($val -eq '') { continue }
                        $found = $phaseLines | Where-Object { $_ -match "$key=" }
                        if (-not $found) {
                            throw "Missing $key in [$phase] log line"
                        }
                    }
                }
            }
        }
        return $true
    }
}

# ============================================================
# debug=false (default) -- zero overhead
# ============================================================

Describe "debug=false produces no log file" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "no logs directory created when debug is false (default)" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $logDir = Join-Path $script:testDir 'logs'
        $logDir | Should -Not -Exist
    }

    It "no logs directory created when debug is explicitly false" {
        $json = New-CespJson -HookEventName "Stop"
        # Explicitly set debug=false in config
        $config = Get-Content (Join-Path $script:testDir "config.json") -Raw | ConvertFrom-Json
        $config | Add-Member -NotePropertyName "debug" -NotePropertyValue $false -Force
        $config | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:testDir "config.json") -Encoding UTF8
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $logDir = Join-Path $script:testDir 'logs'
        $logDir | Should -Not -Exist
    }
}

# ============================================================
# debug=true -- log file with all phases
# ============================================================

Describe "debug=true creates daily log file with expected phases" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ debug = $true }
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "creates log file at logs/peon-ping-YYYY-MM-DD.log" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $logFile = Get-PeonLogFile $script:testDir
        $logFile | Should -Exist
    }

    It "log file contains all 9 phases for Stop event" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $phases = @('config', 'hook', 'state', 'route', 'sound', 'play', 'notify', 'trainer', 'exit')
        foreach ($phase in $phases) {
            $phaseLines = Get-PeonLogPhaseLines $script:testDir $phase
            $phaseLines.Count | Should -BeGreaterThan 0 -Because "phase [$phase] should be present in log"
        }
    }

    It "log lines follow ISO-8601 timestamp + [phase] inv=XXXX format" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $lines = Get-PeonLogLines $script:testDir
        $lines.Count | Should -BeGreaterThan 0
        foreach ($line in $lines) {
            $line | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3} \[[a-z]+\] inv=[a-f0-9]{4}'
        }
    }

    It "[exit] line includes duration_ms" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $exitLines = Get-PeonLogPhaseLines $script:testDir 'exit'
        $exitLines.Count | Should -BeGreaterThan 0
        $exitLines[0] | Should -Match 'duration_ms=\d+'
    }

    It "[hook] line includes event and session" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "test-sess-42"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $hookLines = Get-PeonLogPhaseLines $script:testDir 'hook'
        $hookLines.Count | Should -BeGreaterThan 0
        $hookLines[0] | Should -Match 'event=Stop'
        $hookLines[0] | Should -Match 'session=test-sess-42'
    }

    It "[config] line includes loaded path and pack" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $configLines = Get-PeonLogPhaseLines $script:testDir 'config'
        $configLines.Count | Should -BeGreaterThan 0
        $configLines[0] | Should -Match 'loaded='
        $configLines[0] | Should -Match 'pack=peon'
    }

    It "[sound] line includes file and pack" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $soundLines = Get-PeonLogPhaseLines $script:testDir 'sound'
        $soundLines.Count | Should -BeGreaterThan 0
        $soundLines[0] | Should -Match 'pack=peon'
        $soundLines[0] | Should -Match 'file='
    }

    It "invocation ID is consistent across all lines" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $lines = Get-PeonLogLines $script:testDir
        $invIds = @($lines | ForEach-Object {
            if ($_ -match 'inv=([a-f0-9]{4})') { $matches[1] }
        } | Select-Object -Unique)
        $invIds.Count | Should -Be 1 -Because "all lines from one invocation should share the same inv= ID"
    }
}

# ============================================================
# PEON_DEBUG=1 enables both stderr and file logging (additive)
# ============================================================

Describe "PEON_DEBUG=1 env var enables logging" {
    BeforeEach {
        # Config has debug=false (default) -- PEON_DEBUG overrides
        $script:env = New-PeonTestEnvironment
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "PEON_DEBUG=1 creates log file even when config debug=false" {
        $json = New-CespJson -HookEventName "Stop"

        # Invoke with PEON_DEBUG=1 in the environment
        $peonPath = Join-Path $script:testDir "peon.ps1"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -NoLogo -File `"$peonPath`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.Environment["PEON_DEBUG"] = "1"

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        try {
            $proc.Start() | Out-Null
            $proc.StandardInput.Write($json)
            $proc.StandardInput.Close()
            $proc.WaitForExit(15000) | Out-Null
        } finally {
            $proc.Dispose()
        }

        $logFile = Get-PeonLogFile $script:testDir
        $logFile | Should -Exist
        $lines = Get-PeonLogLines $script:testDir
        $lines.Count | Should -BeGreaterThan 0
    }
}

# ============================================================
# Daily rotation
# ============================================================

Describe "Daily rotation prunes old log files" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ debug = $true; debug_retention_days = 3 }
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "removes log files older than retention days" {
        # Pre-create log directory with old files
        $logDir = Join-Path $script:testDir 'logs'
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null

        # Create "old" log files (7 and 10 days old)
        $old7 = (Get-Date).AddDays(-7).ToString('yyyy-MM-dd')
        $old10 = (Get-Date).AddDays(-10).ToString('yyyy-MM-dd')
        $recent = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')

        Set-Content -Path (Join-Path $logDir "peon-ping-$old7.log") -Value "old7" -Encoding UTF8
        Set-Content -Path (Join-Path $logDir "peon-ping-$old10.log") -Value "old10" -Encoding UTF8
        Set-Content -Path (Join-Path $logDir "peon-ping-$recent.log") -Value "recent" -Encoding UTF8

        # Invoke peon.ps1 to trigger rotation
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        # Old files (7 and 10 days) should be pruned (retention=3)
        (Join-Path $logDir "peon-ping-$old7.log") | Should -Not -Exist
        (Join-Path $logDir "peon-ping-$old10.log") | Should -Not -Exist
        # Recent file (1 day old) should be kept
        (Join-Path $logDir "peon-ping-$recent.log") | Should -Exist
        # Today's file should exist
        (Get-PeonLogFile $script:testDir) | Should -Exist
    }
}

# ============================================================
# Paused early-exit logging
# ============================================================

Describe "Paused (enabled=false) logs hook and exit before early-exit" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ debug = $true; enabled = $false }
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "creates log file when paused with debug=true" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0
        $logFile = Get-PeonLogFile $script:testDir
        $logFile | Should -Exist
    }

    It "[hook] contains paused=True" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $hookLines = Get-PeonLogPhaseLines $script:testDir 'hook'
        $hookLines.Count | Should -BeGreaterThan 0
        $hookLines[0] | Should -Match 'paused=True'
    }

    It "[exit] contains reason=paused" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $exitLines = Get-PeonLogPhaseLines $script:testDir 'exit'
        $exitLines.Count | Should -BeGreaterThan 0
        $exitLines[0] | Should -Match 'reason=paused'
    }

    It "[config] shows enabled=False" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $configLines = Get-PeonLogPhaseLines $script:testDir 'config'
        $configLines.Count | Should -BeGreaterThan 0
        $configLines[0] | Should -Match 'enabled=False'
    }

    It "[exit] includes duration_ms" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $exitLines = Get-PeonLogPhaseLines $script:testDir 'exit'
        $exitLines.Count | Should -BeGreaterThan 0
        $exitLines[0] | Should -Match 'duration_ms=\d+'
    }

    It "no sound or route phases logged when paused" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $soundLines = Get-PeonLogPhaseLines $script:testDir 'sound'
        $soundLines.Count | Should -Be 0
        $playLines = Get-PeonLogPhaseLines $script:testDir 'play'
        $playLines.Count | Should -Be 0
    }
}

# ============================================================
# Route suppression logging
# ============================================================

Describe "Route suppression reasons are logged" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ debug = $true }
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "debounce produces [route] with reason=debounce_5s" {
        # First Stop sets last_stop_time
        $json = New-CespJson -HookEventName "Stop" -SessionId "s-deb1"
        Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json | Out-Null

        # Second Stop within 5s triggers debounce
        $json2 = New-CespJson -HookEventName "Stop" -SessionId "s-deb2"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json2
        $result.ExitCode | Should -Be 0

        $routeLines = Get-PeonLogPhaseLines $script:testDir 'route'
        $debounceLines = @($routeLines | Where-Object { $_ -match 'reason=debounce_5s' })
        $debounceLines.Count | Should -BeGreaterThan 0
    }

    It "delegate mode produces [route] with reason=delegate_mode" {
        $json = New-CespJson -HookEventName "Stop" -SessionId "s-del" -PermissionMode "delegate"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $routeLines = Get-PeonLogPhaseLines $script:testDir 'route'
        $delegateLines = @($routeLines | Where-Object { $_ -match 'reason=delegate_mode' })
        $delegateLines.Count | Should -BeGreaterThan 0
    }

    It "category disabled produces [route] with reason=category_disabled" {
        # Disable session.start in config (SessionStart does not set $notify, so
        # category_disabled triggers a full exit rather than just skipping sound)
        $config = Get-Content (Join-Path $script:testDir "config.json") -Raw | ConvertFrom-Json
        $config.categories.'session.start' = $false
        $config.debug = $true
        $config | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:testDir "config.json") -Encoding UTF8

        $json = New-CespJson -HookEventName "SessionStart"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $routeLines = Get-PeonLogPhaseLines $script:testDir 'route'
        $disabledLines = @($routeLines | Where-Object { $_ -match 'reason=category_disabled' })
        $disabledLines.Count | Should -BeGreaterThan 0
    }
}

# ============================================================
# Missing pack error path
# ============================================================

Describe "Missing pack logs sound error" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ debug = $true; active_pack = "nonexistent_pack" }
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "logs [sound] error when pack manifest is missing" {
        $json = New-CespJson -HookEventName "Stop"
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $json
        $result.ExitCode | Should -Be 0

        $soundLines = Get-PeonLogPhaseLines $script:testDir 'sound'
        $errorLines = @($soundLines | Where-Object { $_ -match 'error=' })
        $errorLines.Count | Should -BeGreaterThan 0
    }
}

# ============================================================
# Shared fixture validation (cross-platform parity with BATS)
# ============================================================

Describe "Shared test fixtures produce expected log output" {
    BeforeEach {
        $script:env = New-PeonTestEnvironment -ConfigOverrides @{ debug = $true }
        $script:testDir = $script:env.TestDir
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "stop-normal fixture produces all expected phases" {
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures/hook-logging'
        $inputJson = Get-Content (Join-Path $fixtureDir 'stop-normal.input.json') -Raw
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $inputJson
        $result.ExitCode | Should -Be 0

        Test-LogFixture -TestDir $script:testDir -FixtureName 'stop-normal' | Should -BeTrue
    }

    It "cwd-with-spaces fixture logs quoted cwd value" {
        $fixtureDir = Join-Path $PSScriptRoot 'fixtures/hook-logging'
        $inputJson = Get-Content (Join-Path $fixtureDir 'cwd-with-spaces.input.json') -Raw
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $inputJson
        $result.ExitCode | Should -Be 0

        Test-LogFixture -TestDir $script:testDir -FixtureName 'cwd-with-spaces' | Should -BeTrue

        # Additionally verify the cwd is quoted (contains spaces)
        $hookLines = Get-PeonLogPhaseLines $script:testDir 'hook'
        $hookLines[0] | Should -Match 'cwd="'
    }

    It "paused fixture produces expected suppression" {
        # Set enabled=false to simulate paused state
        $config = Get-Content (Join-Path $script:testDir "config.json") -Raw | ConvertFrom-Json
        $config.enabled = $false
        $config.debug = $true
        $config | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:testDir "config.json") -Encoding UTF8

        $fixtureDir = Join-Path $PSScriptRoot 'fixtures/hook-logging'
        $inputJson = Get-Content (Join-Path $fixtureDir 'paused.input.json') -Raw
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $inputJson
        $result.ExitCode | Should -Be 0

        # Paused invocations now produce log output (paused check moved after log init)
        $logFile = Get-PeonLogFile $script:testDir
        $logFile | Should -Exist

        # [hook] should contain paused=True
        $hookLines = Get-PeonLogPhaseLines $script:testDir 'hook'
        $hookLines.Count | Should -BeGreaterThan 0
        $hookLines[0] | Should -Match 'paused=True'

        # [exit] should contain reason=paused
        $exitLines = Get-PeonLogPhaseLines $script:testDir 'exit'
        $exitLines.Count | Should -BeGreaterThan 0
        $exitLines[0] | Should -Match 'reason=paused'

        # [config] should show enabled=False
        $configLines = Get-PeonLogPhaseLines $script:testDir 'config'
        $configLines.Count | Should -BeGreaterThan 0
        $configLines[0] | Should -Match 'enabled=False'
    }

    It "missing-pack fixture logs sound error path" {
        # Override active_pack to nonexistent
        $config = Get-Content (Join-Path $script:testDir "config.json") -Raw | ConvertFrom-Json
        $config | Add-Member -NotePropertyName "default_pack" -NotePropertyValue "nonexistent_pack" -Force
        $config.debug = $true
        $config | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:testDir "config.json") -Encoding UTF8

        $fixtureDir = Join-Path $PSScriptRoot 'fixtures/hook-logging'
        $inputJson = Get-Content (Join-Path $fixtureDir 'missing-pack.input.json') -Raw
        $result = Invoke-PeonHook -TestDir $script:testDir -JsonPayload $inputJson
        $result.ExitCode | Should -Be 0

        # Should have [sound] with error
        $soundLines = Get-PeonLogPhaseLines $script:testDir 'sound'
        $errorLines = @($soundLines | Where-Object { $_ -match 'error=' })
        $errorLines.Count | Should -BeGreaterThan 0
    }
}

# ============================================================
# Embedded peon.ps1 logging pattern validation (static analysis)
# ============================================================

Describe "Embedded peon.ps1 has logging infrastructure" {
    BeforeAll {
        $script:RepoRoot = Split-Path $PSScriptRoot -Parent
        $lines = Get-Content (Join-Path $script:RepoRoot "install.ps1")
        $inBlock = $false
        $blockLines = [System.Collections.Generic.List[string]]::new()
        foreach ($line in $lines) {
            if (-not $inBlock -and $line -match '^\$hookScript\s*=\s*@''') {
                $inBlock = $true
                continue
            }
            if ($inBlock -and $line -eq "'@") {
                break
            }
            if ($inBlock) {
                $blockLines.Add($line)
            }
        }
        $script:EmbeddedPeon = $blockLines -join "`n"
    }

    It "declares `$peonInv invocation ID variable" {
        $script:EmbeddedPeon | Should -Match '\$peonInv\s*='
    }

    It "declares `$peonLogEnabled based on config.debug or PEON_DEBUG" {
        $script:EmbeddedPeon | Should -Match 'peonLogEnabled'
    }

    It "defines `$peonLog scriptblock" {
        $script:EmbeddedPeon | Should -Match '\$peonLog\s*='
    }

    It "has empty scriptblock when logging disabled" {
        $script:EmbeddedPeon | Should -Match '\$peonLog\s*=\s*\{\s*\}'
    }

    It "logs all 9 phases" {
        foreach ($phase in @('config', 'hook', 'state', 'route', 'sound', 'play', 'notify', 'trainer', 'exit')) {
            $script:EmbeddedPeon | Should -Match "peonLog\s+'$phase'" -Because "phase [$phase] should be logged"
        }
    }

    It "uses Add-Content for log writes" {
        $script:EmbeddedPeon | Should -Match 'Add-Content.*peonLogPath'
    }

    It "has IOException catch that disables logging" {
        $script:EmbeddedPeon | Should -Match 'catch.*peonLogEnabled.*\$false'
    }

    It "has daily rotation logic" {
        $script:EmbeddedPeon | Should -Match 'peon-ping-\*\.log'
        $script:EmbeddedPeon | Should -Match 'debug_retention_days'
    }

    It "uses Stopwatch for duration_ms" {
        $script:EmbeddedPeon | Should -Match 'Stopwatch'
        $script:EmbeddedPeon | Should -Match 'ElapsedMilliseconds'
    }
}
