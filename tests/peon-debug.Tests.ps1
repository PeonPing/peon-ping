# Pester 5 tests for PEON_DEBUG warning stream output
# Run: Invoke-Pester -Path tests/peon-debug.Tests.ps1
#
# These tests validate:
# - Warning stream output when PEON_DEBUG=1 is set
# - Silent operation when PEON_DEBUG is unset
# - Diagnostic messages from win-play.ps1 failure paths
# - Diagnostic messages from embedded peon.ps1 catch blocks

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:WinPlayPath = Join-Path (Join-Path $script:RepoRoot "scripts") "win-play.ps1"
    $script:InstallPath = Join-Path $script:RepoRoot "install.ps1"
}

# ============================================================
# win-play.ps1 — PEON_DEBUG warning stream
# ============================================================

Describe "win-play.ps1 PEON_DEBUG warnings" {

    It "emits warning when WAV playback fails and PEON_DEBUG=1" {
        $env:PEON_DEBUG = "1"
        try {
            # Pass a non-existent WAV path to trigger the catch block
            $warnings = powershell -NoProfile -NonInteractive -Command "
                `$env:PEON_DEBUG = '1'
                `$WarningPreference = 'Continue'
                & '$($script:WinPlayPath)' -path 'C:\nonexistent\fake.wav' -vol 0.5 3>&1
            "
            $warningText = ($warnings | Where-Object { $_ -is [System.Management.Automation.WarningRecord] -or ($_ -match 'WAV playback failed') }) -join "`n"
            $warningText | Should -Match "WAV playback failed"
        } finally {
            Remove-Item Env:\PEON_DEBUG -ErrorAction SilentlyContinue
        }
    }

    It "emits warning when no CLI player found for non-WAV file and PEON_DEBUG=1" {
        $env:PEON_DEBUG = "1"
        try {
            # Use a non-WAV extension to trigger the CLI player chain;
            # mock all players unavailable by using a clean PATH
            $warnings = powershell -NoProfile -NonInteractive -Command "
                `$env:PEON_DEBUG = '1'
                `$env:PATH = 'C:\Windows\System32'
                `$env:ProgramFiles = 'C:\nonexistent_programs'
                `${env:ProgramFiles(x86)} = 'C:\nonexistent_programs_x86'
                `$WarningPreference = 'Continue'
                & '$($script:WinPlayPath)' -path 'C:\nonexistent\fake.mp3' -vol 0.5 3>&1
            "
            $warningText = ($warnings | Where-Object { $_ -is [System.Management.Automation.WarningRecord] -or ($_ -match 'no audio player found') }) -join "`n"
            $warningText | Should -Match "no audio player found"
        } finally {
            Remove-Item Env:\PEON_DEBUG -ErrorAction SilentlyContinue
        }
    }

    It "emits no warnings when PEON_DEBUG is unset (WAV path)" {
        Remove-Item Env:\PEON_DEBUG -ErrorAction SilentlyContinue
        $warnings = powershell -NoProfile -NonInteractive -Command "
            Remove-Item Env:\PEON_DEBUG -ErrorAction SilentlyContinue
            `$WarningPreference = 'Continue'
            & '$($script:WinPlayPath)' -path 'C:\nonexistent\fake.wav' -vol 0.5 3>&1
        "
        $warningText = ($warnings | Where-Object { $_ -is [System.Management.Automation.WarningRecord] -or ($_ -match 'peon-ping:') }) -join "`n"
        $warningText | Should -BeNullOrEmpty
    }

    It "emits no warnings when PEON_DEBUG is unset (non-WAV path)" {
        Remove-Item Env:\PEON_DEBUG -ErrorAction SilentlyContinue
        $warnings = powershell -NoProfile -NonInteractive -Command "
            Remove-Item Env:\PEON_DEBUG -ErrorAction SilentlyContinue
            `$env:PATH = 'C:\Windows\System32'
            `$env:ProgramFiles = 'C:\nonexistent_programs'
            `${env:ProgramFiles(x86)} = 'C:\nonexistent_programs_x86'
            `$WarningPreference = 'Continue'
            & '$($script:WinPlayPath)' -path 'C:\nonexistent\fake.mp3' -vol 0.5 3>&1
        "
        $warningText = ($warnings | Where-Object { $_ -is [System.Management.Automation.WarningRecord] -or ($_ -match 'peon-ping:') }) -join "`n"
        $warningText | Should -BeNullOrEmpty
    }
}

# ============================================================
# Embedded peon.ps1 in install.ps1 — PEON_DEBUG pattern validation
# ============================================================

Describe "Embedded peon.ps1 PEON_DEBUG diagnostic patterns" {

    BeforeAll {
        # Extract the embedded peon.ps1 from install.ps1 line-by-line
        $lines = Get-Content $script:InstallPath
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

    It "declares `$peonDebug variable gated on PEON_DEBUG env var" {
        $script:EmbeddedPeon | Should -Match '\$peonDebug\s*=\s*\$env:PEON_DEBUG\s+-eq\s+"1"'
    }

    It "has PEON_DEBUG-gated warning for state write failure" {
        $script:EmbeddedPeon | Should -Match 'if\s*\(\$peonDebug\)\s*\{\s*Write-Warning\s+"peon-ping:\s*state write failed'
    }

    It "has PEON_DEBUG-gated warning for category check failure" {
        $script:EmbeddedPeon | Should -Match 'if\s*\(\$peonDebug\)\s*\{\s*Write-Warning\s+"peon-ping:\s*category check failed'
    }

    It "has PEON_DEBUG-gated warning for sound lookup failure" {
        $script:EmbeddedPeon | Should -Match 'if\s*\(\$peonDebug\)\s*\{\s*Write-Warning\s+"peon-ping:\s*sound lookup failed'
    }

    It "has PEON_DEBUG-gated warning for missing win-play.ps1" {
        $script:EmbeddedPeon | Should -Match 'if\s*\(\$peonDebug\)\s*\{\s*Write-Warning\s+"peon-ping:\s*win-play\.ps1 not found'
    }

    It "has no empty catch blocks in the embedded peon.ps1" {
        # Ensure all catch blocks have content (no catch {})
        $script:EmbeddedPeon | Should -Not -Match 'catch\s*\{\s*\}'
    }
}

# ============================================================
# win-play.ps1 — PEON_DEBUG pattern validation
# ============================================================

Describe "win-play.ps1 PEON_DEBUG diagnostic patterns" {

    BeforeAll {
        $script:WinPlayContent = Get-Content $script:WinPlayPath -Raw
    }

    It "declares `$peonDebug variable gated on PEON_DEBUG env var" {
        $script:WinPlayContent | Should -Match '\$peonDebug\s*=\s*\$env:PEON_DEBUG\s+-eq\s+"1"'
    }

    It "has PEON_DEBUG-gated warning for WAV playback failure" {
        $script:WinPlayContent | Should -Match 'if\s*\(\$peonDebug\)\s*\{\s*Write-Warning\s+"peon-ping:\s*WAV playback failed'
    }

    It "has PEON_DEBUG-gated warning for no audio player found" {
        $script:WinPlayContent | Should -Match 'if\s*\(\$peonDebug\)\s*\{\s*Write-Warning\s+"peon-ping:\s*no audio player found'
    }

    It "has no empty catch blocks" {
        $script:WinPlayContent | Should -Not -Match 'catch\s*\{\s*\}'
    }
}
