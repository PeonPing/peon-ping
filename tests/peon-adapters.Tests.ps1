# Pester 5 functional tests for Windows PowerShell adapters (.ps1)
# Run: Invoke-Pester -Path tests/peon-adapters.Tests.ps1
#
# These tests EXECUTE adapter scripts with controlled input and verify
# the actual JSON output shape -- not regex matching source code.
#
# Mock strategy: A mock peon.ps1 captures stdin JSON to a log file.
# Each test gets a fresh temp directory and $env:CLAUDE_PEON_DIR override.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:AdaptersDir = Join-Path $script:RepoRoot "adapters"

    # Helper: Create isolated test environment with mock peon.ps1
    function New-TestPeonDir {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null

        # Mock peon.ps1 that captures stdin JSON to .peon-input.log
        $mockPeon = @'
$ErrorActionPreference = "SilentlyContinue"
$logFile = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) ".peon-input.log"
try {
    if ([Console]::IsInputRedirected) {
        $stream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
        $raw = $reader.ReadToEnd()
        $reader.Close()
        if ($raw) {
            $raw | Out-File -Append -FilePath $logFile -Encoding UTF8
        }
    }
} catch {}
exit 0
'@
        Set-Content -Path (Join-Path $dir "peon.ps1") -Value $mockPeon -Encoding UTF8
        return $dir
    }

    function Get-PeonInputLog {
        param([string]$TestDir)
        $logFile = Join-Path $TestDir ".peon-input.log"
        if (-not (Test-Path $logFile)) { return $null }
        $raw = Get-Content $logFile -Raw -ErrorAction SilentlyContinue
        if (-not $raw) { return $null }
        # Return the last non-empty line as parsed JSON
        $lines = @($raw -split "`n" | Where-Object { $_.Trim() })
        if ($lines.Count -eq 0) { return $null }
        $lastLine = [string]$lines[$lines.Count - 1]
        $lastLine = $lastLine.Trim()
        return $lastLine | ConvertFrom-Json
    }

    function Remove-TestPeonDir {
        param([string]$TestDir)
        if ($TestDir -and (Test-Path $TestDir)) {
            Remove-Item $TestDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# Category A: Simple Translators - Functional Tests
# ============================================================

Describe "Functional: codex.ps1 event mapping" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "maps agent-turn-complete to Stop" {
        $adapter = Join-Path $script:AdaptersDir "codex.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "agent-turn-complete"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
        $json.session_id | Should -Match '^codex-'
    }

    It "maps permission-required to Notification with permission_prompt" {
        $adapter = Join-Path $script:AdaptersDir "codex.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "permission-required"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Notification"
        $json.notification_type | Should -Be "permission_prompt"
    }

    It "maps start to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "codex.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "start"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }
}

Describe "Functional: gemini.ps1 event mapping" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "maps AfterTool with non-zero exit_code to PostToolUseFailure" {
        $adapter = Join-Path $script:AdaptersDir "gemini.ps1"
        $stdinJson = '{"exit_code": 1, "stderr": "command failed"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter -EventType "AfterTool"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PostToolUseFailure"
    }

    It "maps AfterTool with zero exit_code to Stop" {
        $adapter = Join-Path $script:AdaptersDir "gemini.ps1"
        $stdinJson = '{"exit_code": 0}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter -EventType "AfterTool"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
    }

    It "maps SessionStart to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "gemini.ps1"
        '{}' | & powershell -NoProfile -NonInteractive -File $adapter -EventType "SessionStart"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }

    It "maps AfterAgent to Stop" {
        $adapter = Join-Path $script:AdaptersDir "gemini.ps1"
        '{}' | & powershell -NoProfile -NonInteractive -File $adapter -EventType "AfterAgent"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
    }

    It "exits cleanly for unknown event type" {
        $adapter = Join-Path $script:AdaptersDir "gemini.ps1"
        '{}' | & powershell -NoProfile -NonInteractive -File $adapter -EventType "UnknownEvent"

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }
}

Describe "Functional: copilot.ps1 event mapping" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "maps first userPromptSubmitted to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "userPromptSubmitted"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }

    It "maps second userPromptSubmitted to UserPromptSubmit" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"

        # Create the marker file directly to simulate the first call having happened
        # The copilot adapter uses ".copilot-session-$sessionId" where sessionId
        # defaults to "copilot-$PID". Since each powershell invocation has a new PID,
        # we pre-create a marker that matches the session ID the adapter will use.
        # Instead, we pipe stdin JSON with a fixed sessionId to both calls.
        $stdinJson = '{"sessionId": "test-fixed-session"}'

        # First call creates the marker file
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter -Event "userPromptSubmitted"

        # Verify marker file was created
        $markerPattern = Join-Path $script:testDir ".copilot-session-test-fixed-session"
        $markerPattern | Should -Exist

        # Clear the log for the second call
        $logFile = Join-Path $script:testDir ".peon-input.log"
        Remove-Item $logFile -Force -ErrorAction SilentlyContinue

        # Second call should map to UserPromptSubmit
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter -Event "userPromptSubmitted"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "UserPromptSubmit"
    }

    It "maps sessionStart to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "sessionStart"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }

    It "maps postToolUse to Stop" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "postToolUse"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
    }

    It "maps errorOccurred to PostToolUseFailure" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "errorOccurred"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PostToolUseFailure"
    }

    It "exits silently for sessionEnd (no event forwarded)" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "sessionEnd"

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }

    It "exits silently for preToolUse (too noisy)" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "preToolUse"

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }
}

Describe "Functional: windsurf.ps1 event mapping" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "maps post_cascade_response to Stop" {
        $adapter = Join-Path $script:AdaptersDir "windsurf.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "post_cascade_response"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
        $json.session_id | Should -Match '^windsurf-'
    }

    It "maps first pre_user_prompt to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "windsurf.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "pre_user_prompt"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }

    It "exits silently for unknown event" {
        $adapter = Join-Path $script:AdaptersDir "windsurf.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "unknown_event"

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }
}

Describe "Functional: kiro.ps1 event mapping" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "remaps agentSpawn to SessionStart with kiro- prefix" {
        $adapter = Join-Path $script:AdaptersDir "kiro.ps1"
        $stdinJson = '{"hook_event_name": "agentSpawn", "session_id": "test123"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
        $json.session_id | Should -Match '^kiro-'
    }

    It "remaps stop to Stop" {
        $adapter = Join-Path $script:AdaptersDir "kiro.ps1"
        $stdinJson = '{"hook_event_name": "stop", "session_id": "test456"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
    }

    It "remaps userPromptSubmit to UserPromptSubmit" {
        $adapter = Join-Path $script:AdaptersDir "kiro.ps1"
        $stdinJson = '{"hook_event_name": "userPromptSubmit", "session_id": "test789"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "UserPromptSubmit"
    }

    It "exits silently for unknown event" {
        $adapter = Join-Path $script:AdaptersDir "kiro.ps1"
        $stdinJson = '{"hook_event_name": "preToolUse", "session_id": "test000"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }
}

Describe "Functional: openclaw.ps1 event mapping" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "maps session.start to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "openclaw.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "session.start"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
        $json.session_id | Should -Match '^openclaw-'
    }

    It "maps task.complete to Stop" {
        $adapter = Join-Path $script:AdaptersDir "openclaw.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "task.complete"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
    }

    It "maps task.error to PostToolUseFailure" {
        $adapter = Join-Path $script:AdaptersDir "openclaw.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "task.error"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PostToolUseFailure"
    }

    It "maps input.required to Notification with permission_prompt" {
        $adapter = Join-Path $script:AdaptersDir "openclaw.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "input.required"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Notification"
        $json.notification_type | Should -Be "permission_prompt"
    }

    It "maps resource.limit to Notification with resource_limit" {
        $adapter = Join-Path $script:AdaptersDir "openclaw.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "resource.limit"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Notification"
        $json.notification_type | Should -Be "resource_limit"
    }

    It "accepts raw Claude Code event names (passthrough)" {
        $adapter = Join-Path $script:AdaptersDir "openclaw.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "SessionStart"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }
}

Describe "Functional: deepagents.ps1 event mapping" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "maps task.complete to Stop with session_id from thread_id" {
        $adapter = Join-Path $script:AdaptersDir "deepagents.ps1"
        $stdinJson = '{"event": "task.complete", "thread_id": "abc"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
        $json.session_id | Should -Be "deepagents-abc"
    }

    It "maps session.start to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "deepagents.ps1"
        $stdinJson = '{"event": "session.start", "thread_id": "xyz"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }

    It "exits silently on tool.call (noise filter)" {
        $adapter = Join-Path $script:AdaptersDir "deepagents.ps1"
        $stdinJson = '{"event": "tool.call", "thread_id": "abc"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }

    It "exits silently on unknown event" {
        $adapter = Join-Path $script:AdaptersDir "deepagents.ps1"
        $stdinJson = '{"event": "some.unknown.event"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }

    It "exits silently when no stdin" {
        $adapter = Join-Path $script:AdaptersDir "deepagents.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }

    It "maps permission.request to PermissionRequest" {
        $adapter = Join-Path $script:AdaptersDir "deepagents.ps1"
        $stdinJson = '{"event": "permission.request", "thread_id": "perm1"}'
        $stdinJson | & powershell -NoProfile -NonInteractive -File $adapter

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PermissionRequest"
    }
}

# ============================================================
# Category B: Filesystem Watchers - Function-level Tests
# ============================================================

Describe "Functional: amp.ps1 Emit-Event builds correct CESP JSON" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "Emit-Event builds correct session_id from thread ID" {
        # Extract the Emit-Event function and invoke it directly.
        # We do this by building a small wrapper that sources the function
        # definition and calls it.
        $ampSource = Get-Content (Join-Path $script:AdaptersDir "amp.ps1") -Raw

        # Extract function body via regex
        if ($ampSource -match '(?s)(function Emit-Event \{.*?\n\})') {
            $emitFunc = $matches[1]
        } else {
            throw "Could not extract Emit-Event from amp.ps1"
        }

        $wrapper = @"
`$ErrorActionPreference = "SilentlyContinue"
`$PeonDir = "$($script:testDir -replace '\\','\\')"
`$PeonScript = Join-Path `$PeonDir "peon.ps1"
$emitFunc
Emit-Event "SessionStart" "T-abc1234567890"
"@

        $wrapperFile = Join-Path $script:testDir "test-emit.ps1"
        Set-Content -Path $wrapperFile -Value $wrapper -Encoding UTF8
        & powershell -NoProfile -NonInteractive -File $wrapperFile

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
        # amp.ps1 truncates: Substring(2, min(8, len-2)) => "abc12345"
        $json.session_id | Should -Be "amp-abc12345"
    }
}

Describe "Functional: antigravity.ps1 Emit-Event builds correct CESP JSON" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "Emit-Event builds correct session_id from guid" {
        $agSource = Get-Content (Join-Path $script:AdaptersDir "antigravity.ps1") -Raw

        if ($agSource -match '(?s)(function Emit-Event \{.*?\n\})') {
            $emitFunc = $matches[1]
        } else {
            throw "Could not extract Emit-Event from antigravity.ps1"
        }

        $wrapper = @"
`$ErrorActionPreference = "SilentlyContinue"
`$PeonDir = "$($script:testDir -replace '\\','\\')"
`$PeonScript = Join-Path `$PeonDir "peon.ps1"
$emitFunc
Emit-Event "SessionStart" "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
"@

        $wrapperFile = Join-Path $script:testDir "test-emit-ag.ps1"
        Set-Content -Path $wrapperFile -Value $wrapper -Encoding UTF8
        & powershell -NoProfile -NonInteractive -File $wrapperFile

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
        # antigravity.ps1 truncates: Substring(0, min(8, len)) => "a1b2c3d4"
        $json.session_id | Should -Be "antigravity-a1b2c3d4"
    }
}

Describe "Functional: kimi.ps1 Process-WireLine maps events" {
    It "maps TurnEnd to Stop with correct session_id" {
        $kimiSource = Get-Content (Join-Path $script:AdaptersDir "kimi.ps1") -Raw

        if ($kimiSource -match '(?s)(function Process-WireLine \{.*?\n\})') {
            $procFunc = $matches[1]
        } else {
            throw "Could not extract Process-WireLine from kimi.ps1"
        }

        $wrapper = @"
`$ErrorActionPreference = "SilentlyContinue"
$procFunc
`$result = Process-WireLine '{"message":{"type":"TurnEnd"}}' "abc12345-dead-beef" "C:\test"
`$result | ConvertTo-Json -Compress
"@

        $wrapperFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-kimi-$([guid]::NewGuid().ToString('N').Substring(0,8)).ps1"
        Set-Content -Path $wrapperFile -Value $wrapper -Encoding UTF8
        try {
            $output = & powershell -NoProfile -NonInteractive -File $wrapperFile 2>$null
            $json = $output | ConvertFrom-Json
            $json.event | Should -Be "Stop"
            $json.session_id | Should -Be "kimi-abc12345"
            $json.cwd | Should -Be "C:\test"
        } finally {
            Remove-Item $wrapperFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "maps CompactionBegin to PreCompact" {
        $kimiSource = Get-Content (Join-Path $script:AdaptersDir "kimi.ps1") -Raw

        if ($kimiSource -match '(?s)(function Process-WireLine \{.*?\n\})') {
            $procFunc = $matches[1]
        } else {
            throw "Could not extract Process-WireLine from kimi.ps1"
        }

        $wrapper = @"
`$ErrorActionPreference = "SilentlyContinue"
$procFunc
`$result = Process-WireLine '{"message":{"type":"CompactionBegin"}}' "uuid12345678" "C:\proj"
`$result | ConvertTo-Json -Compress
"@

        $wrapperFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-kimi-compact-$([guid]::NewGuid().ToString('N').Substring(0,8)).ps1"
        Set-Content -Path $wrapperFile -Value $wrapper -Encoding UTF8
        try {
            $output = & powershell -NoProfile -NonInteractive -File $wrapperFile 2>$null
            $json = $output | ConvertFrom-Json
            $json.event | Should -Be "PreCompact"
        } finally {
            Remove-Item $wrapperFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "maps SubagentEvent with TurnBegin to SubagentStart" {
        $kimiSource = Get-Content (Join-Path $script:AdaptersDir "kimi.ps1") -Raw

        if ($kimiSource -match '(?s)(function Process-WireLine \{.*?\n\})') {
            $procFunc = $matches[1]
        } else {
            throw "Could not extract Process-WireLine from kimi.ps1"
        }

        $wireJson = '{"message":{"type":"SubagentEvent","payload":{"message":{"type":"TurnBegin"}}}}'

        $wrapper = @"
`$ErrorActionPreference = "SilentlyContinue"
$procFunc
`$result = Process-WireLine '$wireJson' "subagent-uuid1" "C:\proj"
`$result | ConvertTo-Json -Compress
"@

        $wrapperFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-kimi-sub-$([guid]::NewGuid().ToString('N').Substring(0,8)).ps1"
        Set-Content -Path $wrapperFile -Value $wrapper -Encoding UTF8
        try {
            $output = & powershell -NoProfile -NonInteractive -File $wrapperFile 2>$null
            $json = $output | ConvertFrom-Json
            $json.event | Should -Be "SubagentStart"
        } finally {
            Remove-Item $wrapperFile -Force -ErrorAction SilentlyContinue
        }
    }

    It "returns null for unrecognized wire event" {
        $kimiSource = Get-Content (Join-Path $script:AdaptersDir "kimi.ps1") -Raw

        if ($kimiSource -match '(?s)(function Process-WireLine \{.*?\n\})') {
            $procFunc = $matches[1]
        } else {
            throw "Could not extract Process-WireLine from kimi.ps1"
        }

        $wrapper = @"
`$ErrorActionPreference = "SilentlyContinue"
$procFunc
`$result = Process-WireLine '{"message":{"type":"SomeRandomEvent"}}' "uuid999" "C:\proj"
if (`$null -eq `$result) { Write-Output "NULL" } else { Write-Output "NOT_NULL" }
"@

        $wrapperFile = Join-Path ([System.IO.Path]::GetTempPath()) "test-kimi-null-$([guid]::NewGuid().ToString('N').Substring(0,8)).ps1"
        Set-Content -Path $wrapperFile -Value $wrapper -Encoding UTF8
        try {
            $output = & powershell -NoProfile -NonInteractive -File $wrapperFile 2>$null
            $output.Trim() | Should -Be "NULL"
        } finally {
            Remove-Item $wrapperFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# Category C: Installer/Structural - deepagents.ps1 syntax
# ============================================================

Describe "Structural: deepagents.ps1 syntax validation" {
    It "has valid PowerShell syntax" {
        $path = Join-Path $script:AdaptersDir "deepagents.ps1"
        $path | Should -Exist
        $content = Get-Content $path -Raw
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "does not use ExecutionPolicy Bypass" {
        $path = Join-Path $script:AdaptersDir "deepagents.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Not -Match "ExecutionPolicy Bypass"
    }
}

# ============================================================
# Edge Cases
# ============================================================

Describe "Edge: adapters handle missing peon.ps1 gracefully" {
    BeforeEach {
        # Create a temp dir WITHOUT peon.ps1 to test graceful exit
        $script:emptyDir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-empty-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:emptyDir -Force | Out-Null
        $env:CLAUDE_PEON_DIR = $script:emptyDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-Item $script:emptyDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "codex.ps1 exits 0 when peon.ps1 is missing" {
        $adapter = Join-Path $script:AdaptersDir "codex.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "start"
        $LASTEXITCODE | Should -Be 0
    }

    It "deepagents.ps1 exits 0 when peon.ps1 is missing" {
        $adapter = Join-Path $script:AdaptersDir "deepagents.ps1"
        '{"event": "session.start"}' | & powershell -NoProfile -NonInteractive -File $adapter
        $LASTEXITCODE | Should -Be 0
    }

    It "kiro.ps1 exits 0 when peon.ps1 is missing" {
        $adapter = Join-Path $script:AdaptersDir "kiro.ps1"
        '{"hook_event_name": "stop", "session_id": "x"}' | & powershell -NoProfile -NonInteractive -File $adapter
        $LASTEXITCODE | Should -Be 0
    }
}

# ============================================================
# CESP JSON shape validation
# ============================================================

Describe "CESP JSON shape: all Category A adapters produce required fields" {
    BeforeEach {
        $script:testDir = New-TestPeonDir
        $env:CLAUDE_PEON_DIR = $script:testDir
    }
    AfterEach {
        Remove-Item Env:\CLAUDE_PEON_DIR -ErrorAction SilentlyContinue
        Remove-TestPeonDir $script:testDir
    }

    It "<adapter> produces hook_event_name, session_id, cwd, notification_type" -ForEach @(
        @{ adapter = "codex";      args = @("-Event", "start") },
        @{ adapter = "windsurf";   args = @("-Event", "post_cascade_response") },
        @{ adapter = "openclaw";   args = @("-Event", "task.complete") }
    ) {
        $adapterPath = Join-Path $script:AdaptersDir "$adapter.ps1"
        & powershell -NoProfile -NonInteractive -File $adapterPath @args

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.PSObject.Properties.Name | Should -Contain "hook_event_name"
        $json.PSObject.Properties.Name | Should -Contain "session_id"
        $json.PSObject.Properties.Name | Should -Contain "cwd"
        $json.PSObject.Properties.Name | Should -Contain "notification_type"
    }
}
