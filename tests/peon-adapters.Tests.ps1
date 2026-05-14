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

    It "maps sessionStart to SessionStart" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "sessionStart"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionStart"
    }

    It "maps sessionEnd to SessionEnd" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","reason":"complete"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "sessionEnd"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SessionEnd"
        $json.reason | Should -Be "complete"
    }

    It "maps userPromptSubmitted to UserPromptSubmit (no marker-file dual mode)" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","prompt":"hello"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "userPromptSubmitted"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "UserPromptSubmit"
        $json.prompt | Should -Be "hello"
    }

    It "maps agentStop to Stop with stop_reason field" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","stopReason":"end_turn","transcriptPath":"/tmp/t"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "agentStop"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Stop"
        $json.stop_reason | Should -Be "end_turn"
        $json.transcript_path | Should -Be "/tmp/t"
    }

    It "skips postToolUse silently (no PostToolUse handler in peon.ps1; routing to Stop floods debounce)" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "postToolUse"

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }

    It "maps postToolUseFailure to PostToolUseFailure with error field" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","toolName":"shell","error":"oops"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "postToolUseFailure"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PostToolUseFailure"
        $json.tool_name | Should -Be "shell"
        $json.error | Should -Be "oops"
    }

    It "maps errorOccurred to PostToolUseFailure (Copilot CLI generic-error compat)" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "errorOccurred"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PostToolUseFailure"
    }

    It "maps preToolUse to PreToolUse with tool_name and tool_input" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","toolName":"shell","toolArgs":{"cmd":"ls"}}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "preToolUse"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PreToolUse"
        $json.tool_name | Should -Be "shell"
        $json.tool_input.cmd | Should -Be "ls"
    }

    It "maps notification to Notification with notification_type" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","notificationType":"elicitation_dialog","message":"q?"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "notification"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "Notification"
        $json.notification_type | Should -Be "elicitation_dialog"
    }

    It "maps permissionRequest to PermissionRequest with tool_name" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","toolName":"rm"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "permissionRequest"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PermissionRequest"
        $json.tool_name | Should -Be "rm"
    }

    It "maps subagentStart to SubagentStart with agent_name" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","agentName":"helper"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "subagentStart"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SubagentStart"
        $json.agent_name | Should -Be "helper"
    }

    It "maps subagentStop to SubagentStop" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","transcriptPath":"/tmp/x"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "subagentStop"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "SubagentStop"
        $json.transcript_path | Should -Be "/tmp/x"
    }

    It "maps preCompact to PreCompact with trigger" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s","trigger":"auto"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "preCompact"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.hook_event_name | Should -Be "PreCompact"
        $json.trigger | Should -Be "auto"
    }

    It "skips unknown events silently" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        & powershell -NoProfile -NonInteractive -File $adapter -Event "bogusEvent"

        $logFile = Join-Path $script:testDir ".peon-input.log"
        $logFile | Should -Not -Exist
    }

    It "always sets source=copilot in forwarded payload" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"s"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "agentStop"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.source | Should -Be "copilot"
    }

    It "translates sessionId to session_id" {
        $adapter = Join-Path $script:AdaptersDir "copilot.ps1"
        '{"sessionId":"my-session-123"}' | & powershell -NoProfile -NonInteractive -File $adapter -Event "agentStop"

        $json = Get-PeonInputLog $script:testDir
        $json | Should -Not -BeNullOrEmpty
        $json.session_id | Should -Be "my-session-123"
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
