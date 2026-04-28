# Pester 5 tests for Windows Notification Templates + Notifications CLI (install.ps1)
# Run: Invoke-Pester -Path tests/win-notification-templates.Tests.ps1
#
# These tests validate:
# - Template CLI: get/set/reset notification message templates
# - Template resolution: rendering templates with event variables
# - Notifications on/off toggle and --popups alias
# - Verbose status output for desktop/mobile notifications
# - Help text includes notification commands

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:InstallPs1 = Join-Path $script:RepoRoot "install.ps1"

    # Extract peon.ps1 content from install.ps1 here-string ($hookScript = @'...'@)
    function Get-PeonPs1Content {
        $installContent = Get-Content $script:InstallPs1 -Raw
        # Find start marker: $hookScript = @'
        $startMarker = "`$hookScript = @'"
        $startIdx = $installContent.IndexOf($startMarker)
        if ($startIdx -lt 0) { throw "Could not find `$hookScript = @' in install.ps1" }
        # Move past the opening line
        $afterStart = $installContent.IndexOf("`n", $startIdx) + 1
        # Find closing '@ (must be on its own line)
        $endIdx = $installContent.IndexOf("`r`n'@", $afterStart)
        if ($endIdx -lt 0) { $endIdx = $installContent.IndexOf("`n'@", $afterStart) }
        if ($endIdx -lt 0) { throw "Could not find closing '@ in install.ps1" }
        return $installContent.Substring($afterStart, $endIdx - $afterStart)
    }

    # Create a test installation directory with peon.ps1 and required fixtures
    function New-TestInstall {
        param(
            [hashtable]$Config = @{},
            [hashtable]$State = @{}
        )

        $testDir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-notif-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null

        # Write peon.ps1
        $peonContent = Get-PeonPs1Content
        Set-Content -Path (Join-Path $testDir "peon.ps1") -Value $peonContent -Encoding UTF8

        # Default config
        $defaultConfig = @{
            default_pack = "peon"
            volume = 0.5
            enabled = $true
            desktop_notifications = $true
            categories = @{
                "session.start" = $true
                "task.complete" = $true
                "input.required" = $true
            }
            annoyed_threshold = 3
            annoyed_window_seconds = 10
            silent_window_seconds = 0
            session_start_cooldown_seconds = 30
            suppress_subagent_complete = $false
            pack_rotation = @()
            pack_rotation_mode = "random"
            path_rules = @()
            session_ttl_days = 7
        }

        # Merge caller-provided config
        foreach ($key in $Config.Keys) {
            $defaultConfig[$key] = $Config[$key]
        }

        $defaultConfig | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $testDir "config.json") -Encoding UTF8

        # Write state
        if ($State.Count -gt 0) {
            $State | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $testDir ".state.json") -Encoding UTF8
        } else {
            '{}' | Set-Content (Join-Path $testDir ".state.json") -Encoding UTF8
        }

        # Create minimal pack structure so hook mode does not fail
        $packsDir = Join-Path $testDir "packs"
        $peonPackDir = Join-Path $packsDir "peon"
        $peonSoundsDir = Join-Path $peonPackDir "sounds"
        New-Item -ItemType Directory -Path $peonSoundsDir -Force | Out-Null
        Set-Content -Path (Join-Path $peonSoundsDir "test.mp3") -Value "" -Encoding UTF8
        $peonManifest = @{
            name = "peon"
            version = "1.0.0"
            categories = @{
                "session.start" = @{
                    sounds = @(@{ file = "sounds/test.mp3"; label = "test" })
                }
                "task.complete" = @{
                    sounds = @(@{ file = "sounds/test.mp3"; label = "test" })
                }
                "input.required" = @{
                    sounds = @(@{ file = "sounds/test.mp3"; label = "test" })
                }
            }
        }
        $peonManifest | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $peonPackDir "openpeon.json") -Encoding UTF8

        # Create scripts directory with stubs
        $scriptsDir = Join-Path $testDir "scripts"
        New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
        # Stub win-play.ps1 that just exits
        'param($path, $vol) exit 0' | Set-Content (Join-Path $scriptsDir "win-play.ps1") -Encoding UTF8
        # Stub win-notify.ps1 that logs parameters to file for assertion
        @'
param($body, $title, $dismissSeconds, $parentPid)
$logPath = Join-Path (Split-Path -Parent $PSScriptRoot) ".notify-log.txt"
"BODY=$body`nTITLE=$title" | Add-Content $logPath
exit 0
'@ | Set-Content (Join-Path $scriptsDir "win-notify.ps1") -Encoding UTF8

        return $testDir
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

    # Run peon.ps1 in hook mode by piping JSON via stdin
    function Invoke-PeonHook {
        param(
            [string]$TestDir,
            [string]$HookJson
        )
        $peonScript = Join-Path $TestDir "peon.ps1"
        $tmpInput = Join-Path $TestDir ".hook-input.json"
        Set-Content -Path $tmpInput -Value $HookJson -Encoding UTF8 -NoNewline
        $result = & cmd.exe /c "type `"$tmpInput`" | powershell.exe -NoProfile -NonInteractive -File `"$peonScript`"" 2>&1
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

    # Read notification log from test dir
    function Get-NotifyLog {
        param([string]$TestDir)
        $path = Join-Path $TestDir ".notify-log.txt"
        if (Test-Path $path) {
            return Get-Content $path -Raw
        }
        return ""
    }
}

# ============================================================
# Syntax Validation
# ============================================================

Describe "Notifications: Syntax Validation" {
    It "extracted peon.ps1 has valid PowerShell syntax" {
        $content = Get-PeonPs1Content
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        $errors.Count | Should -Be 0 -Because "Parse errors: $($errors | ForEach-Object { "$($_.Token.StartLine):$($_.Message)" })"
    }
}

# ============================================================
# Resolve-TemplateKey Unit Tests (shared helper)
# ============================================================

Describe "Resolve-TemplateKey: category-to-key mapping" {
    BeforeAll {
        # Extract Resolve-TemplateKey function from peon.ps1 and load it
        $content = Get-PeonPs1Content
        $fnMatch = [regex]::Match($content, '(?ms)(function Resolve-TemplateKey \{.+?\n\})')
        if (-not $fnMatch.Success) { throw "Could not extract Resolve-TemplateKey from peon.ps1" }
        Invoke-Expression $fnMatch.Groups[1].Value
    }

    It "maps task.complete to stop" {
        Resolve-TemplateKey -Category "task.complete" -Event "Stop" -Ntype "" | Should -Be "stop"
    }

    It "maps task.error to error" {
        Resolve-TemplateKey -Category "task.error" -Event "PostToolUseFailure" -Ntype "" | Should -Be "error"
    }

    It "maps Notification with idle_prompt to idle" {
        Resolve-TemplateKey -Category "" -Event "Notification" -Ntype "idle_prompt" | Should -Be "idle"
    }

    It "maps Notification with elicitation_dialog to question" {
        Resolve-TemplateKey -Category "" -Event "Notification" -Ntype "elicitation_dialog" | Should -Be "question"
    }

    It "maps PermissionRequest to permission" {
        Resolve-TemplateKey -Category "" -Event "PermissionRequest" -Ntype "" | Should -Be "permission"
    }

    It "returns null for unknown category" {
        Resolve-TemplateKey -Category "session.start" -Event "SessionStart" -Ntype "" | Should -BeNullOrEmpty
    }
}

# ============================================================
# Template CLI (13 tests — mirrors Unix BATS)
# ============================================================

Describe "Notifications CLI: template show all (none configured)" {
    It "shows no templates by default" {
        $testDir = New-TestInstall
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--notifications", "template")
            $result.Output | Should -Match "no notification templates configured"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: template set" {
    It "sets stop template in config" {
        $testDir = New-TestInstall
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--notifications", "template", "stop", "{project}: {summary}")
            $result.Output | Should -Match 'template stop set to'

            $cfg = Get-TestConfig -TestDir $testDir
            $cfg.notification_templates.stop | Should -Be "{project}: {summary}"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: template show single" {
    It "shows current template value" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ stop = "{project} finished" }
        }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--notifications", "template", "stop")
            $result.Output | Should -Match 'template stop = "{project} finished"'
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: template invalid key" {
    It "rejects invalid key with exit code 1" {
        $testDir = New-TestInstall
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--notifications", "template", "bogus", "{project}")
            $result.Output | Should -Match 'invalid template key "bogus"'
            $result.ExitCode | Should -Be 1
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: template reset" {
    It "clears all templates" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ stop = "{project}: {summary}" }
        }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--notifications", "template", "--reset")
            $result.Output | Should -Match "notification templates cleared"

            $cfg = Get-TestConfig -TestDir $testDir
            $cfg.notification_templates | Should -BeNullOrEmpty
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: template rendering - Stop with summary" {
    It "renders transcript_summary in stop template" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ stop = "{project}: {summary}" }
            desktop_notifications = $true
        }
        try {
            $hookJson = @{
                hook_event_name = "Stop"
                session_id = "test-session"
                cwd = "C:\Users\test\myproject"
                transcript_summary = "Fixed the login bug"
            } | ConvertTo-Json -Depth 5
            $result = Invoke-PeonHook -TestDir $testDir -HookJson $hookJson
            # Check the notify log to see what body was passed
            # Poll for notify log (async Start-Process may take longer on CI)
            $logPath = Join-Path $testDir ".notify-log.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            $notifyLog = Get-NotifyLog -TestDir $testDir
            $notifyLog | Should -Match "myproject: Fixed the login bug"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: template rendering - Stop without summary" {
    It "renders empty summary when transcript_summary not present" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ stop = "{project}: {summary}" }
            desktop_notifications = $true
        }
        try {
            $hookJson = @{
                hook_event_name = "Stop"
                session_id = "test-session"
                cwd = "C:\Users\test\myproject"
            } | ConvertTo-Json -Depth 5
            $result = Invoke-PeonHook -TestDir $testDir -HookJson $hookJson
            # Poll for notify log (async Start-Process may take longer on CI)
            $logPath = Join-Path $testDir ".notify-log.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            $notifyLog = Get-NotifyLog -TestDir $testDir
            $notifyLog | Should -Match "BODY=myproject: \r?\n"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: template rendering - PermissionRequest with tool_name" {
    It "renders tool_name in permission template" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ permission = "{project} needs {tool_name}" }
            desktop_notifications = $true
        }
        try {
            $hookJson = @{
                hook_event_name = "PermissionRequest"
                session_id = "test-session"
                cwd = "C:\Users\test\myproject"
                tool_name = "bash"
            } | ConvertTo-Json -Depth 5
            $result = Invoke-PeonHook -TestDir $testDir -HookJson $hookJson
            # Poll for notify log (async Start-Process may take longer on CI)
            $logPath = Join-Path $testDir ".notify-log.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            $notifyLog = Get-NotifyLog -TestDir $testDir
            $notifyLog | Should -Match "myproject needs bash"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: no template falls back to status body and project title" {
    It "puts status word in body and project name in title when no template configured" {
        $testDir = New-TestInstall -Config @{
            desktop_notifications = $true
        }
        try {
            $hookJson = @{
                hook_event_name = "Stop"
                session_id = "test-session"
                cwd = "C:\Users\test\myproject"
            } | ConvertTo-Json -Depth 5
            $result = Invoke-PeonHook -TestDir $testDir -HookJson $hookJson
            # Poll for notify log (async Start-Process may take longer on CI)
            $logPath = Join-Path $testDir ".notify-log.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            $notifyLog = Get-NotifyLog -TestDir $testDir
            # Body now carries the status word, not the project name. Title carries the project.
            $notifyLog | Should -Match "BODY=done"
            $notifyLog | Should -Match "TITLE=.* myproject"
            $notifyLog | Should -Not -Match "BODY=myproject"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: unknown variable renders as empty string" {
    It "renders unknown {nonexistent} as empty" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ stop = "{project}-{nonexistent}-end" }
            desktop_notifications = $true
        }
        try {
            $hookJson = @{
                hook_event_name = "Stop"
                session_id = "test-session"
                cwd = "C:\Users\test\myproject"
            } | ConvertTo-Json -Depth 5
            $result = Invoke-PeonHook -TestDir $testDir -HookJson $hookJson
            # Poll for notify log (async Start-Process may take longer on CI)
            $logPath = Join-Path $testDir ".notify-log.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            $notifyLog = Get-NotifyLog -TestDir $testDir
            $notifyLog | Should -Match "myproject--end"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: --status shows templates when configured" {
    It "shows configured templates in status output" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ stop = "{project}: {summary}" }
        }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--status", "--verbose")
            $result.Output | Should -Match "notification templates:"
            $result.Output | Should -Match 'stop = "{project}: {summary}"'
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: template with all 5 variables" {
    It "renders all 5 template variables correctly" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{ stop = "{project}|{summary}|{tool_name}|{status}|{event}" }
            desktop_notifications = $true
        }
        try {
            $hookJson = @{
                hook_event_name = "Stop"
                session_id = "test-session"
                cwd = "C:\Users\test\myproject"
                transcript_summary = "Did stuff"
                tool_name = "editor"
            } | ConvertTo-Json -Depth 5
            $result = Invoke-PeonHook -TestDir $testDir -HookJson $hookJson
            # Poll for notify log (async Start-Process may take longer on CI)
            $logPath = Join-Path $testDir ".notify-log.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            $notifyLog = Get-NotifyLog -TestDir $testDir
            $notifyLog | Should -Match "myproject\|Did stuff\|editor\|done\|Stop"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications: multiple templates each render for their event" {
    It "renders stop template for Stop event" {
        $testDir = New-TestInstall -Config @{
            notification_templates = @{
                stop = "STOP:{project}"
                permission = "PERM:{project}"
            }
            desktop_notifications = $true
        }
        try {
            $hookJson = @{
                hook_event_name = "Stop"
                session_id = "test-session"
                cwd = "C:\Users\test\myproject"
            } | ConvertTo-Json -Depth 5
            $result = Invoke-PeonHook -TestDir $testDir -HookJson $hookJson
            # Poll for notify log (async Start-Process may take longer on CI)
            $logPath = Join-Path $testDir ".notify-log.txt"
            $deadline = [DateTime]::UtcNow.AddSeconds(5)
            while (-not (Test-Path $logPath) -and [DateTime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 100
            }
            $notifyLog = Get-NotifyLog -TestDir $testDir
            $notifyLog | Should -Match "STOP:myproject"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# Notifications on/off + popups alias (6 tests)
# ============================================================

Describe "Notifications CLI: off" {
    It "sets desktop_notifications to false" {
        $testDir = New-TestInstall -Config @{ desktop_notifications = $true }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--notifications", "off")
            $result.Output | Should -Match "desktop notifications off"

            $cfg = Get-TestConfig -TestDir $testDir
            $cfg.desktop_notifications | Should -Be $false
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: on" {
    It "sets desktop_notifications to true" {
        $testDir = New-TestInstall -Config @{ desktop_notifications = $false }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--notifications", "on")
            $result.Output | Should -Match "desktop notifications on"

            $cfg = Get-TestConfig -TestDir $testDir
            $cfg.desktop_notifications | Should -Be $true
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: --popups alias" {
    It "--popups off behaves identically to --notifications off" {
        $testDir = New-TestInstall -Config @{ desktop_notifications = $true }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--popups", "off")
            $result.Output | Should -Match "desktop notifications off"

            $cfg = Get-TestConfig -TestDir $testDir
            $cfg.desktop_notifications | Should -Be $false
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: --status --verbose desktop state" {
    It "shows desktop notification state" {
        $testDir = New-TestInstall -Config @{ desktop_notifications = $true }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--status", "--verbose")
            $result.Output | Should -Match "desktop notifications on"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: --status --verbose sounds still play" {
    It "shows 'sounds still play' when notifications off" {
        $testDir = New-TestInstall -Config @{ desktop_notifications = $false }
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--status", "--verbose")
            $result.Output | Should -Match "sounds still play"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Notifications CLI: --help includes notifications" {
    It "help text shows notifications and popups commands" {
        $testDir = New-TestInstall
        try {
            $result = Invoke-PeonCli -TestDir $testDir -Arguments @("--help")
            $result.Output | Should -Match "--notifications"
            $result.Output | Should -Match "--popups"
        } finally {
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
