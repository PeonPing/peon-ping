# Pester 5 tests for debug and logs CLI commands in peon.ps1 (Windows native)
# Run: Invoke-Pester -Path tests/debug-logs-windows.Tests.ps1
#
# These tests validate:
# - peon debug on/off/status CLI commands
# - peon logs / logs --last N / logs --session ID / logs --prune / logs --clear CLI commands
# - peon --help includes debug and logs commands
# - Output format matches expected strings

BeforeAll {
    . $PSScriptRoot/windows-setup.ps1

    # Create a test environment with a peon.ps1, config.json, packs, etc.
    function New-DebugTestEnv {
        param(
            [hashtable]$ConfigOverrides = @{}
        )
        $env = New-PeonTestEnvironment -ConfigOverrides $ConfigOverrides
        return $env.TestDir
    }

    # Run peon.ps1 with CLI arguments (uses -Command to capture Write-Host output)
    function Invoke-PeonCli {
        param(
            [string]$TestDir,
            [string[]]$Arguments
        )
        $peonScript = Join-Path $TestDir "peon.ps1"
        $argStr = ($Arguments | ForEach-Object { "'" + $_ + "'" }) -join " "
        $result = & powershell.exe -NoProfile -NonInteractive -Command "& '$peonScript' $argStr" 2>&1
        return @{
            Output = ($result -join "`n")
            RawOutput = $result
            ExitCode = $LASTEXITCODE
        }
    }

    # Read config.json from test dir
    function Get-TestConfig {
        param([string]$TestDir)
        $path = Join-Path $TestDir "config.json"
        return Get-Content $path -Raw | ConvertFrom-Json
    }

    # Create a fake log file in the test dir
    function New-FakeLogFile {
        param(
            [string]$TestDir,
            [string]$Date,
            [string[]]$Lines
        )
        $logDir = Join-Path $TestDir "logs"
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        $logFile = Join-Path $logDir "peon-ping-$Date.log"
        $Lines | Set-Content $logFile -Encoding UTF8
    }
}

# ============================================================
# peon debug on
# ============================================================
Describe "peon debug on" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "sets debug to true in config.json" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "on")
        $cfg = Get-TestConfig $script:testDir
        $cfg.debug | Should -BeTrue
    }

    It "outputs confirmation message" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "on")
        $result.Output | Should -Match "debug logging enabled"
        $result.Output | Should -Match "logs"
    }

    It "is idempotent" {
        Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "on") | Out-Null
        Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "on") | Out-Null
        $cfg = Get-TestConfig $script:testDir
        $cfg.debug | Should -BeTrue
    }
}

# ============================================================
# peon debug off
# ============================================================
Describe "peon debug off" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv -ConfigOverrides @{ debug = $true }
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "sets debug to false in config.json" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "off")
        $cfg = Get-TestConfig $script:testDir
        $cfg.debug | Should -BeFalse
    }

    It "outputs confirmation message" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "off")
        $result.Output | Should -Match "debug logging disabled"
    }
}

# ============================================================
# peon debug status
# ============================================================
Describe "peon debug status" {
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "shows disabled when debug is false" {
        $script:testDir = New-DebugTestEnv
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "status")
        $result.Output | Should -Match "debug disabled"
    }

    It "shows enabled when debug is true" {
        $script:testDir = New-DebugTestEnv -ConfigOverrides @{ debug = $true }
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "status")
        $result.Output | Should -Match "debug enabled"
    }

    It "shows log directory path" {
        $script:testDir = New-DebugTestEnv
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "status")
        $result.Output | Should -Match "log directory:"
    }

    It "shows file count and size when logs exist" {
        $script:testDir = New-DebugTestEnv
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-25" -Lines @(
            "2026-03-25T10:00:00.000 [config] inv=a1b2 loaded=config.json",
            "2026-03-25T10:00:00.001 [exit] inv=a1b2 duration_ms=5 exit=0"
        )
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "status")
        $result.Output | Should -Match "log files: 1"
    }

    It "shows zero files when no logs exist" {
        $script:testDir = New-DebugTestEnv
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "status")
        $result.Output | Should -Match "log files: 0"
    }

    It "defaults to status when no subcommand given" {
        $script:testDir = New-DebugTestEnv
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug")
        $result.Output | Should -Match "debug disabled"
    }
}

# ============================================================
# peon logs (no args -- today's log, last 50 lines)
# ============================================================
Describe "peon logs (today)" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "shows last 50 lines of today's log" {
        $today = (Get-Date).ToString('yyyy-MM-dd')
        $lines = 1..60 | ForEach-Object { "$today`T10:00:00.000 [config] inv=a1b2 line=$_" }
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines $lines
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs")
        # Should show lines 11-60 (last 50)
        $result.Output | Should -Match "line=60"
        $result.Output | Should -Match "line=11"
        $result.Output | Should -Not -Match "line=10\b"
    }

    It "shows all lines when fewer than 50" {
        $today = (Get-Date).ToString('yyyy-MM-dd')
        $lines = 1..5 | ForEach-Object { "$today`T10:00:00.000 [config] inv=a1b2 line=$_" }
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines $lines
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs")
        $result.Output | Should -Match "line=1"
        $result.Output | Should -Match "line=5"
    }

    It "shows helpful message when no log files exist" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs")
        $result.Output | Should -Match "no log file"
        $result.Output | Should -Match "peon debug on"
    }
}

# ============================================================
# peon logs --last N
# ============================================================
Describe "peon logs --last N" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "shows last N lines across log files" {
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-24" -Lines @(
            "2026-03-24T10:00:00.000 [config] inv=a1b2 day=24-line1",
            "2026-03-24T10:00:00.001 [exit] inv=a1b2 day=24-line2"
        )
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-25" -Lines @(
            "2026-03-25T10:00:00.000 [config] inv=c3d4 day=25-line1",
            "2026-03-25T10:00:00.001 [exit] inv=c3d4 day=25-line2"
        )
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--last", "3")
        # Should get last 3 lines: day=24-line2, day=25-line1, day=25-line2
        $result.Output | Should -Match "day=24-line2"
        $result.Output | Should -Match "day=25-line1"
        $result.Output | Should -Match "day=25-line2"
    }

    It "defaults to 50 when N not given" {
        $today = (Get-Date).ToString('yyyy-MM-dd')
        $lines = 1..60 | ForEach-Object { "$today`T10:00:00.000 [config] inv=a1b2 line=$_" }
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines $lines
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--last")
        $result.Output | Should -Match "line=60"
        $result.Output | Should -Match "line=11"
        $result.Output | Should -Not -Match "line=10\b"
    }

    It "shows message when no log files exist" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--last", "10")
        $result.Output | Should -Match "no log files"
    }

    It "shows usage when N is not a number" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--last", "foo")
        $result.Output | Should -Match "positive integer"
    }

    It "shows usage when N is zero" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--last", "0")
        $result.Output | Should -Match "positive integer"
    }

    It "shows usage when N is negative" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--last", "-5")
        $result.Output | Should -Match "positive integer"
    }
}

# ============================================================
# peon logs --session ID
# ============================================================
Describe "peon logs --session ID" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "filters log entries by session ID" {
        $today = (Get-Date).ToString('yyyy-MM-dd')
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines @(
            "$today`T10:00:00.000 [hook] inv=a1b2 event=SessionStart session=abc123",
            "$today`T10:00:00.001 [hook] inv=c3d4 event=Stop session=def456",
            "$today`T10:00:00.002 [config] inv=a1b2 session=abc123 loaded=config.json"
        )
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--session", "abc123")
        $result.Output | Should -Match "session=abc123"
        $result.Output | Should -Not -Match "def456"
    }

    It "shows message when session not found" {
        $today = (Get-Date).ToString('yyyy-MM-dd')
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines @(
            "$today`T10:00:00.000 [hook] inv=a1b2 event=SessionStart session=abc123"
        )
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--session", "nonexistent")
        $result.Output | Should -Match "no entries for session"
    }

    It "shows usage when no session ID given" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--session")
        $result.Output | Should -Match "Usage:"
    }
}

# ============================================================
# peon logs --session ID --all
# ============================================================
Describe "peon logs --session ID --all" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "searches across all log files" {
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-23" -Lines @(
            "2026-03-23T23:59:00.000 [hook] inv=a1b2 event=SessionStart session=midnight123"
        )
        $today = (Get-Date).ToString('yyyy-MM-dd')
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines @(
            "$today`T00:00:05.000 [sound] inv=c3d4 session=midnight123 file=Hello1.wav",
            "$today`T00:01:00.000 [hook] inv=e5f6 event=Start session=other999"
        )
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--session", "midnight123", "--all")
        $result.Output | Should -Match "midnight123"
        $result.Output | Should -Match "2026-03-23"
        $result.Output | Should -Not -Match "other999"
    }

    It "shows message when session not found across all files" {
        $today = (Get-Date).ToString('yyyy-MM-dd')
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines @(
            "$today`T10:00:00.000 [hook] inv=a1b2 event=SessionStart session=abc123"
        )
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--session", "nonexistent", "--all")
        $result.Output | Should -Match "no entries for session=nonexistent across all log files"
    }

    It "shows message when no log files exist with --all" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--session", "abc123", "--all")
        $result.Output | Should -Match "no log files found"
    }

    It "returns results in chronological order" {
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-22" -Lines @(
            "2026-03-22T12:00:00.000 [hook] inv=a1b2 event=Start session=chrono123"
        )
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-23" -Lines @(
            "2026-03-23T12:00:00.000 [hook] inv=c3d4 event=Stop session=chrono123"
        )
        $today = (Get-Date).ToString('yyyy-MM-dd')
        New-FakeLogFile -TestDir $script:testDir -Date $today -Lines @(
            "$today`T12:00:00.000 [sound] inv=e5f6 session=chrono123 file=Hello1.wav"
        )
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--session", "chrono123", "--all")
        $lines = ($result.Output -split "`n" | Where-Object { $_ -ne '' })
        $lines[0] | Should -Match "2026-03-22"
        $lines[1] | Should -Match "2026-03-23"
    }
}

# ============================================================
# peon logs --clear
# ============================================================
Describe "peon logs --clear" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "deletes all log files" {
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-24" -Lines @("line1")
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-25" -Lines @("line2")
        $logDir = Join-Path $script:testDir "logs"
        $before = @(Get-ChildItem $logDir -Filter "peon-ping-*.log")
        $before.Count | Should -Be 2

        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--clear")
        $result.Output | Should -Match "cleared 2 log file"

        $after = @(Get-ChildItem $logDir -Filter "peon-ping-*.log" -ErrorAction SilentlyContinue)
        $after.Count | Should -Be 0
    }

    It "shows message when no log files to clear" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--clear")
        $result.Output | Should -Match "no log files to clear"
    }
}

# ============================================================
# peon logs --prune
# ============================================================
Describe "peon logs --prune" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv -ConfigOverrides @{ debug_retention_days = 7 }
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "deletes log files older than retention days" {
        # Create old files (>7 days ago) and a recent file
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-10" -Lines @("old1")
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-12" -Lines @("old2")
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-25" -Lines @("recent")
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-26" -Lines @("today")

        $logDir = Join-Path $script:testDir "logs"
        $before = @(Get-ChildItem $logDir -Filter "peon-ping-*.log")
        $before.Count | Should -Be 4

        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--prune")
        $result.Output | Should -Match "pruned 2 log file\(s\) older than 7 days"

        $after = @(Get-ChildItem $logDir -Filter "peon-ping-*.log")
        $after.Count | Should -Be 2
        # Verify old files are gone and recent files remain
        ($after | Where-Object { $_.Name -match "2026-03-10" }) | Should -BeNullOrEmpty
        ($after | Where-Object { $_.Name -match "2026-03-12" }) | Should -BeNullOrEmpty
        ($after | Where-Object { $_.Name -match "2026-03-25" }) | Should -Not -BeNullOrEmpty
        ($after | Where-Object { $_.Name -match "2026-03-26" }) | Should -Not -BeNullOrEmpty
    }

    It "shows message when no old log files to prune" {
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-25" -Lines @("recent")
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--prune")
        $result.Output | Should -Match "no log files older than 7 days"
    }

    It "shows message when no logs directory exists" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--prune")
        $result.Output | Should -Match "no logs directory found"
    }

    It "respects custom debug_retention_days from config" {
        # Override config to retention of 3 days
        $configPath = Join-Path $script:testDir "config.json"
        $cfg = Get-Content $configPath -Raw | ConvertFrom-Json
        $cfg.debug_retention_days = 3
        $cfg | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8

        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-20" -Lines @("old")
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-22" -Lines @("also-old")
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-25" -Lines @("recent")

        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--prune")
        $result.Output | Should -Match "pruned 2 log file\(s\) older than 3 days"

        $logDir = Join-Path $script:testDir "logs"
        $after = @(Get-ChildItem $logDir -Filter "peon-ping-*.log")
        $after.Count | Should -Be 1
    }

    It "shows message when log files exist but none are old enough" {
        New-FakeLogFile -TestDir $script:testDir -Date "2026-03-26" -Lines @("today")
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--prune")
        $result.Output | Should -Match "no log files older than 7 days"
    }
}

# ============================================================
# peon --help includes debug and logs
# ============================================================
Describe "peon --help includes debug and logs" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "lists debug commands in help" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("--help")
        $result.Output | Should -Match "debug on"
        $result.Output | Should -Match "debug off"
        $result.Output | Should -Match "debug status"
    }

    It "lists logs commands in help" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("--help")
        $result.Output | Should -Match "logs\b"
        $result.Output | Should -Match "logs --last"
        $result.Output | Should -Match "logs --session"
        $result.Output | Should -Match "logs --session ID --all"
        $result.Output | Should -Match "logs --prune"
        $result.Output | Should -Match "logs --clear"
    }
}

# ============================================================
# peon logs with unknown flag
# ============================================================
Describe "peon logs with unknown flag" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "shows usage for unrecognized flags" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("logs", "--bogus")
        $result.Output | Should -Match "Usage:"
    }
}

# ============================================================
# peon debug with unknown subcommand
# ============================================================
Describe "peon debug with unknown subcommand" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "shows usage for unrecognized debug subcommands" {
        $result = Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "bogus")
        $result.Output | Should -Match "Usage:"
    }
}

# ============================================================
# peon debug preserves other config keys
# ============================================================
Describe "peon debug preserves config" {
    BeforeEach {
        $script:testDir = New-DebugTestEnv -ConfigOverrides @{ volume = 0.8 }
    }
    AfterEach {
        Remove-PeonTestEnvironment -TestDir $script:testDir
    }

    It "does not destroy other config keys" {
        Invoke-PeonCli -TestDir $script:testDir -Arguments @("debug", "on") | Out-Null
        $cfg = Get-TestConfig $script:testDir
        $cfg.debug | Should -BeTrue
        $cfg.volume | Should -Be 0.8
        $cfg.enabled | Should -BeTrue
    }
}
