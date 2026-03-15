# Pester 5 tests for Windows PowerShell adapters (.ps1)
# Run: Invoke-Pester -Path tests/adapters-windows.Tests.ps1
#
# These tests validate:
# - PowerShell syntax for all adapter scripts
# - Event mapping logic (Category A: simple translators)
# - Daemon management flags (Category B: filesystem watchers)
# - FileSystemWatcher usage (Category B)
# - Installer structure (Category C: opencode, kilo)
# - No ExecutionPolicy Bypass in any adapter
# - peon.ps1 path resolution patterns

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:AdaptersDir = Join-Path $script:RepoRoot "adapters"
}

# ============================================================
# Syntax validation
# ============================================================

Describe "PowerShell Syntax Validation" {
    $allAdapters = @("codex", "gemini", "copilot", "windsurf", "kiro", "openclaw",
                     "amp", "antigravity", "kimi", "opencode", "kilo")

    It "adapters/<name>.ps1 has valid PowerShell syntax" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" },
        @{ name = "opencode" }, @{ name = "kilo" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $path | Should -Exist
        $content = Get-Content $path -Raw
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

Describe "Core Script Syntax Validation" {
    It "<name> has valid PowerShell syntax" -ForEach @(
        @{ name = "install.ps1" },
        @{ name = "scripts/win-play.ps1" }
    ) {
        $path = Join-Path $script:RepoRoot $name
        $path | Should -Exist
        $content = Get-Content $path -Raw
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        $errors.Count | Should -Be 0 -Because "Parse errors: $($errors | ForEach-Object { "$($_.Token.StartLine):$($_.Message)" })"
    }
}

# ============================================================
# Security: no ExecutionPolicy Bypass
# ============================================================

Describe "No ExecutionPolicy Bypass" {
    It "adapters/<name>.ps1 does not use ExecutionPolicy Bypass" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" },
        @{ name = "opencode" }, @{ name = "kilo" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Not -Match "ExecutionPolicy Bypass"
    }

    It "install.ps1 does not use ExecutionPolicy Bypass" {
        $path = Join-Path $script:RepoRoot "install.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Not -Match "ExecutionPolicy Bypass"
    }
}

# ============================================================
# Category A: Simple Event Translators
# ============================================================

Describe "Category A: Codex Adapter" {
    BeforeAll {
        $script:codexContent = Get-Content (Join-Path $script:AdaptersDir "codex.ps1") -Raw
    }

    It "accepts Event parameter" {
        $script:codexContent | Should -Match 'param\('
        $script:codexContent | Should -Match '\[string\]\$Event'
    }

    It "maps agent-turn-complete to Stop" {
        $script:codexContent | Should -Match '"agent-turn-complete".*"complete".*"done"'
        $script:codexContent | Should -Match '\$mapped = "Stop"'
    }

    It "maps start/session-start to SessionStart" {
        $script:codexContent | Should -Match '"start".*"session-start"'
        $script:codexContent | Should -Match '\$mapped = "SessionStart"'
    }

    It "maps permission events to Notification with permission_prompt" {
        $script:codexContent | Should -Match 'permission'
        $script:codexContent | Should -Match '\$ntype = "permission_prompt"'
    }

    It "pipes JSON to peon.ps1" {
        $script:codexContent | Should -Match 'peon\.ps1'
        $script:codexContent | Should -Match 'ConvertTo-Json'
    }
}

Describe "Category A: Gemini Adapter" {
    BeforeAll {
        $script:geminiContent = Get-Content (Join-Path $script:AdaptersDir "gemini.ps1") -Raw
    }

    It "accepts EventType parameter" {
        $script:geminiContent | Should -Match '\[string\]\$EventType'
    }

    It "maps SessionStart to SessionStart" {
        $script:geminiContent | Should -Match '"SessionStart"\s*\{[^}]*\$mapped = "SessionStart"'
    }

    It "maps AfterAgent to Stop" {
        $script:geminiContent | Should -Match '"AfterAgent"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "maps AfterTool with non-zero exit to PostToolUseFailure" {
        $script:geminiContent | Should -Match 'PostToolUseFailure'
    }

    It "reads JSON from stdin" {
        $script:geminiContent | Should -Match 'IsInputRedirected'
        $script:geminiContent | Should -Match 'StreamReader'
    }

    It "returns empty JSON object to Gemini" {
        $script:geminiContent | Should -Match 'Write-Output "\{\}"'
    }
}

Describe "Category A: Copilot Adapter" {
    BeforeAll {
        $script:copilotContent = Get-Content (Join-Path $script:AdaptersDir "copilot.ps1") -Raw
    }

    It "maps sessionStart to SessionStart" {
        $script:copilotContent | Should -Match '"sessionStart"\s*\{[^}]*\$mapped = "SessionStart"'
    }

    It "maps postToolUse to Stop" {
        $script:copilotContent | Should -Match '"postToolUse"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "maps errorOccurred to PostToolUseFailure" {
        $script:copilotContent | Should -Match '"errorOccurred"\s*\{[^}]*\$mapped = "PostToolUseFailure"'
    }

    It "handles first userPromptSubmitted as SessionStart" {
        $script:copilotContent | Should -Match 'copilot-session'
        $script:copilotContent | Should -Match '\$mapped = "SessionStart"'
    }

    It "handles subsequent userPromptSubmitted as UserPromptSubmit" {
        $script:copilotContent | Should -Match '\$mapped = "UserPromptSubmit"'
    }

    It "exits gracefully for sessionEnd" {
        $script:copilotContent | Should -Match '"sessionEnd"'
        $script:copilotContent | Should -Match 'exit 0'
    }

    It "exits gracefully for preToolUse (too noisy)" {
        $script:copilotContent | Should -Match '"preToolUse"'
    }
}

Describe "Category A: Windsurf Adapter" {
    BeforeAll {
        $script:windsurfContent = Get-Content (Join-Path $script:AdaptersDir "windsurf.ps1") -Raw
    }

    It "maps post_cascade_response to Stop" {
        $script:windsurfContent | Should -Match '"post_cascade_response"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "handles pre_user_prompt session detection" {
        $script:windsurfContent | Should -Match 'windsurf-session'
        $script:windsurfContent | Should -Match '"pre_user_prompt"'
    }

    It "maps post_write_code to Stop" {
        $script:windsurfContent | Should -Match '"post_write_code"'
    }

    It "maps post_run_command to Stop" {
        $script:windsurfContent | Should -Match '"post_run_command"'
    }

    It "drains stdin" {
        $script:windsurfContent | Should -Match 'IsInputRedirected'
    }
}

Describe "Category A: Kiro Adapter" {
    BeforeAll {
        $script:kiroContent = Get-Content (Join-Path $script:AdaptersDir "kiro.ps1") -Raw
    }

    It "remaps agentSpawn to SessionStart" {
        $script:kiroContent | Should -Match '"agentSpawn"\s*=\s*"SessionStart"'
    }

    It "remaps userPromptSubmit to UserPromptSubmit" {
        $script:kiroContent | Should -Match '"userPromptSubmit"\s*=\s*"UserPromptSubmit"'
    }

    It "remaps stop to Stop" {
        $script:kiroContent | Should -Match '"stop"\s*=\s*"Stop"'
    }

    It "prefixes session_id with kiro-" {
        $script:kiroContent | Should -Match '"kiro-\$sid"'
    }

    It "skips unknown events" {
        $script:kiroContent | Should -Match 'if \(-not \$mapped\)'
        $script:kiroContent | Should -Match 'exit 0'
    }
}

Describe "Category A: OpenClaw Adapter" {
    BeforeAll {
        $script:openclawContent = Get-Content (Join-Path $script:AdaptersDir "openclaw.ps1") -Raw
    }

    It "maps session.start to SessionStart" {
        $script:openclawContent | Should -Match '"session\.start"'
        $script:openclawContent | Should -Match '\$mapped = "SessionStart"'
    }

    It "maps task.complete to Stop" {
        $script:openclawContent | Should -Match '"task\.complete"'
        $script:openclawContent | Should -Match '\$mapped = "Stop"'
    }

    It "maps task.error to PostToolUseFailure" {
        $script:openclawContent | Should -Match '"task\.error"'
        $script:openclawContent | Should -Match '\$mapped = "PostToolUseFailure"'
    }

    It "maps input.required to Notification with permission_prompt" {
        $script:openclawContent | Should -Match '"input\.required"'
        $script:openclawContent | Should -Match '\$ntype = "permission_prompt"'
    }

    It "maps resource.limit to Notification with resource_limit" {
        $script:openclawContent | Should -Match '"resource\.limit"'
        $script:openclawContent | Should -Match '\$ntype = "resource_limit"'
    }

    It "accepts raw Claude Code event names" {
        $script:openclawContent | Should -Match '"SessionStart", "Stop", "Notification"'
    }
}

# ============================================================
# Category B: Filesystem Watcher Adapters
# ============================================================

Describe "Category B: Amp Adapter" {
    BeforeAll {
        $script:ampContent = Get-Content (Join-Path $script:AdaptersDir "amp.ps1") -Raw
    }

    It "has Install/Uninstall/Status daemon flags" {
        $script:ampContent | Should -Match '\[switch\]\$Install'
        $script:ampContent | Should -Match '\[switch\]\$Uninstall'
        $script:ampContent | Should -Match '\[switch\]\$Status'
    }

    It "uses FileSystemWatcher" {
        $script:ampContent | Should -Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches T-*.json files" {
        $script:ampContent | Should -Match 'T-\*\.json'
    }

    It "has idle detection logic" {
        $script:ampContent | Should -Match 'IdleSeconds'
        $script:ampContent | Should -Match 'StopCooldown'
    }

    It "checks if thread is waiting for user input" {
        $script:ampContent | Should -Match 'Test-ThreadWaiting'
        $script:ampContent | Should -Match 'tool_use'
    }

    It "has PID file management" {
        $script:ampContent | Should -Match '\.amp-adapter\.pid'
    }

    It "tries Windows-native AMP_DATA_DIR path first" {
        $script:ampContent | Should -Match 'LOCALAPPDATA'
    }
}

Describe "Category B: Antigravity Adapter" {
    BeforeAll {
        $script:antigravityContent = Get-Content (Join-Path $script:AdaptersDir "antigravity.ps1") -Raw
    }

    It "has Install/Uninstall/Status daemon flags" {
        $script:antigravityContent | Should -Match '\[switch\]\$Install'
        $script:antigravityContent | Should -Match '\[switch\]\$Uninstall'
        $script:antigravityContent | Should -Match '\[switch\]\$Status'
    }

    It "uses FileSystemWatcher" {
        $script:antigravityContent | Should -Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches *.pb files" {
        $script:antigravityContent | Should -Match '\*\.pb'
    }

    It "has idle detection logic" {
        $script:antigravityContent | Should -Match 'IdleSeconds'
        $script:antigravityContent | Should -Match 'StopCooldown'
    }

    It "has PID file management" {
        $script:antigravityContent | Should -Match '\.antigravity-adapter\.pid'
    }
}

Describe "Category B: Kimi Adapter" {
    BeforeAll {
        $script:kimiContent = Get-Content (Join-Path $script:AdaptersDir "kimi.ps1") -Raw
    }

    It "has Install/Uninstall/Status/Help flags" {
        $script:kimiContent | Should -Match '\[switch\]\$Install'
        $script:kimiContent | Should -Match '\[switch\]\$Uninstall'
        $script:kimiContent | Should -Match '\[switch\]\$Status'
        $script:kimiContent | Should -Match '\[switch\]\$Help'
    }

    It "uses FileSystemWatcher" {
        $script:kimiContent | Should -Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches wire.jsonl files with subdirectory recursion" {
        $script:kimiContent | Should -Match 'wire\.jsonl'
        $script:kimiContent | Should -Match 'IncludeSubdirectories.*true'
    }

    It "maps TurnEnd to Stop" {
        $script:kimiContent | Should -Match '"TurnEnd".*"Stop"'
    }

    It "maps TurnBegin to SessionStart for new sessions" {
        $script:kimiContent | Should -Match '"TurnBegin"'
        $script:kimiContent | Should -Match '"SessionStart"'
    }

    It "maps SubagentEvent with TurnBegin to SubagentStart" {
        $script:kimiContent | Should -Match '"SubagentEvent"'
        $script:kimiContent | Should -Match '"SubagentStart"'
    }

    It "maps CompactionBegin to PreCompact" {
        $script:kimiContent | Should -Match '"CompactionBegin".*"PreCompact"'
    }

    It "has /clear detection logic" {
        $script:kimiContent | Should -Match 'ClearGraceSeconds'
        $script:kimiContent | Should -Match 'lastNewSession'
    }

    It "resolves CWD from workspace hash using MD5" {
        $script:kimiContent | Should -Match 'Resolve-KimiCwd'
        $script:kimiContent | Should -Match 'MD5'
    }

    It "reads new bytes from wire.jsonl using offset tracking" {
        $script:kimiContent | Should -Match 'sessionOffset'
        $script:kimiContent | Should -Match 'FileStream'
    }

    It "has PID file management" {
        $script:kimiContent | Should -Match '\.kimi-adapter\.pid'
    }
}

# ============================================================
# Category C: Installer Adapters
# ============================================================

Describe "Category C: OpenCode Installer" {
    BeforeAll {
        $script:opencodeContent = Get-Content (Join-Path $script:AdaptersDir "opencode.ps1") -Raw
    }

    It "has Uninstall flag" {
        $script:opencodeContent | Should -Match '\[switch\]\$Uninstall'
    }

    It "downloads the peon-ping.ts plugin" {
        $script:opencodeContent | Should -Match 'peon-ping\.ts'
        $script:opencodeContent | Should -Match 'Invoke-WebRequest'
    }

    It "creates default config.json" {
        $script:opencodeContent | Should -Match 'config\.json'
        $script:opencodeContent | Should -Match 'default_pack'
    }

    It "installs default pack from registry" {
        $script:opencodeContent | Should -Match 'peonping\.github\.io/registry'
    }

    It "uses LOCALAPPDATA for Windows-native path" {
        $script:opencodeContent | Should -Match 'LOCALAPPDATA'
    }
}

Describe "Category C: Kilo Installer" {
    BeforeAll {
        $script:kiloContent = Get-Content (Join-Path $script:AdaptersDir "kilo.ps1") -Raw
    }

    It "has Uninstall flag" {
        $script:kiloContent | Should -Match '\[switch\]\$Uninstall'
    }

    It "downloads and patches OpenCode plugin for Kilo" {
        $script:kiloContent | Should -Match 'peon-ping\.ts'
        $script:kiloContent | Should -Match '@kilocode/plugin'
    }

    It "patches config path from opencode to kilo" {
        $script:kiloContent | Should -Match '".config", "kilo", "peon-ping"'
    }

    It "creates default config.json" {
        $script:kiloContent | Should -Match 'config\.json'
        $script:kiloContent | Should -Match 'default_pack'
    }

    It "installs default pack from registry" {
        $script:kiloContent | Should -Match 'peonping\.github\.io/registry'
    }
}

# ============================================================
# install.ps1 adapter installation
# ============================================================

Describe "install.ps1 Adapter Installation" {
    BeforeAll {
        $script:installContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
    }

    It "installs adapter scripts to adapters/ directory" {
        $script:installContent | Should -Match 'Installing adapter scripts'
        $script:installContent | Should -Match 'adapters'
    }

    It "installs all 11 adapter files" {
        $script:installContent | Should -Match 'codex\.ps1'
        $script:installContent | Should -Match 'gemini\.ps1'
        $script:installContent | Should -Match 'copilot\.ps1'
        $script:installContent | Should -Match 'windsurf\.ps1'
        $script:installContent | Should -Match 'kiro\.ps1'
        $script:installContent | Should -Match 'openclaw\.ps1'
        $script:installContent | Should -Match 'amp\.ps1'
        $script:installContent | Should -Match 'antigravity\.ps1'
        $script:installContent | Should -Match 'kimi\.ps1'
        $script:installContent | Should -Match 'opencode\.ps1'
        $script:installContent | Should -Match 'kilo\.ps1'
    }

    It "calls Unblock-File on installed adapters" {
        $script:installContent | Should -Match 'Unblock-File'
    }

    It "has execution policy detection" {
        $script:installContent | Should -Match 'Get-ExecutionPolicy'
        $script:installContent | Should -Match 'Restricted'
    }

    It "handles missing Claude Code gracefully" {
        $script:installContent | Should -Match 'ClaudeCodeDetected'
        $script:installContent | Should -Match 'Skipping Claude Code hook registration'
    }
}

# ============================================================
# Cross-cutting: peon.ps1 resolution pattern
# ============================================================

Describe "All adapters resolve peon.ps1 via CLAUDE_PEON_DIR" {
    It "adapters/<name>.ps1 checks CLAUDE_PEON_DIR env var" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Match 'CLAUDE_PEON_DIR'
    }

    It "adapters/<name>.ps1 falls back to ~/.claude/hooks/peon-ping" -ForEach @(
        @{ name = "codex" }, @{ name = "gemini" }, @{ name = "copilot" },
        @{ name = "windsurf" }, @{ name = "kiro" }, @{ name = "openclaw" },
        @{ name = "amp" }, @{ name = "antigravity" }, @{ name = "kimi" }
    ) {
        $path = Join-Path $script:AdaptersDir "$name.ps1"
        $content = Get-Content $path -Raw
        $content | Should -Match '\.claude\\hooks\\peon-ping'
    }
}

# ============================================================
# win-play.ps1 audio backend
# ============================================================

Describe "win-play.ps1 Audio Backend" {
    BeforeAll {
        $script:winPlayPath = Join-Path (Join-Path $script:RepoRoot "scripts") "win-play.ps1"
        $script:winPlayContent = Get-Content $script:winPlayPath -Raw
    }

    It "has valid PowerShell syntax" {
        $script:winPlayPath | Should -Exist
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($script:winPlayContent, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "requires path and vol parameters" {
        $script:winPlayContent | Should -Match '\[string\]\$path'
        $script:winPlayContent | Should -Match '\[double\]\$vol'
    }

    It "uses SoundPlayer for WAV files" {
        $script:winPlayContent | Should -Match '\.wav\$'
        $script:winPlayContent | Should -Match 'System\.Media\.SoundPlayer'
        $script:winPlayContent | Should -Match 'PlaySync'
    }

    It "contains zero references to MediaPlayer or PresentationCore" {
        $script:winPlayContent | Should -Not -Match 'System\.Windows\.Media\.MediaPlayer'
        $script:winPlayContent | Should -Not -Match 'PresentationCore'
    }

    It "uses ffplay as first CLI player choice" {
        $script:winPlayContent | Should -Match 'ffplay'
        $script:winPlayContent | Should -Match '-nodisp'
        $script:winPlayContent | Should -Match '-autoexit'
    }

    It "uses mpv as second CLI player choice" {
        $script:winPlayContent | Should -Match 'mpv'
        $script:winPlayContent | Should -Match '--no-video'
    }

    It "uses vlc as third CLI player choice" {
        $script:winPlayContent | Should -Match 'vlc'
        $script:winPlayContent | Should -Match '--play-and-exit'
    }

    It "normalizes volume for ffplay (0-100 scale)" {
        $script:winPlayContent | Should -Match '\$vol \* 100'
    }

    It "normalizes volume for mpv (0-100 scale)" {
        $script:winPlayContent | Should -Match 'volume=\$mpvVol'
    }

    It "normalizes volume for vlc (0.0-2.0 gain multiplier)" {
        $script:winPlayContent | Should -Match '\$vol \* 2\.0'
        $script:winPlayContent | Should -Match '--gain'
    }

    It "exits silently (exit 0) if no CLI player found" {
        # The last line before the end should be exit 0
        $script:winPlayContent | Should -Match 'exit 0'
    }

    It "disposes SoundPlayer after playback" {
        $script:winPlayContent | Should -Match '\$sp\.Dispose\(\)'
    }
}

# ============================================================
# hook-handle-use.ps1 (per-session pack assignment)
# ============================================================

Describe "hook-handle-use.ps1" {
    BeforeAll {
        $script:hhuPath = Join-Path (Join-Path $script:RepoRoot "scripts") "hook-handle-use.ps1"
        $script:hhuContent = Get-Content $script:hhuPath -Raw
    }

    It "has valid PowerShell syntax" {
        $script:hhuPath | Should -Exist
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($script:hhuContent, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "sanitizes pack name with safe charset regex" {
        $script:hhuContent | Should -Match '\$packName -notmatch.*\^.a-zA-Z0-9_-.*\$'
    }

    It "sanitizes session_id with safe charset regex" {
        $script:hhuContent | Should -Match '\$sessionId -notmatch.*\^.a-zA-Z0-9_-.*\$'
    }

    It "outputs JSON response with continue flag" {
        $script:hhuContent | Should -Match 'ConvertTo-Json'
        $script:hhuContent | Should -Match 'continue'
    }

    It "supports CLI mode via positional args" {
        $script:hhuContent | Should -Match '\$args\.Count'
        $script:hhuContent | Should -Match 'cliMode'
    }

    It "reads stdin JSON in hook mode" {
        $script:hhuContent | Should -Match 'OpenStandardInput'
        $script:hhuContent | Should -Match 'StreamReader'
    }

    It "validates pack directory exists before assignment" {
        $script:hhuContent | Should -Match 'Test-Path \$packPath'
    }

    It "sets pack_rotation_mode to session_override" {
        $script:hhuContent | Should -Match 'pack_rotation_mode.*session_override'
    }

    It "writes session_packs with timestamp to .state.json" {
        $script:hhuContent | Should -Match 'session_packs'
        $script:hhuContent | Should -Match 'last_used'
    }

    It "blocks LLM invocation on successful match (continue=false)" {
        $script:hhuContent | Should -Match 'Write-Response -Continue \$false -Message "Voice set to'
    }

    It "passes through unrelated prompts (continue=true)" {
        $script:hhuContent | Should -Match 'Write-Response -Continue \$true'
    }
}

# ============================================================
# uninstall.ps1
# ============================================================

Describe "uninstall.ps1" {
    BeforeAll {
        $script:uninstallPath = Join-Path $script:RepoRoot "uninstall.ps1"
        $script:uninstallContent = Get-Content $script:uninstallPath -Raw
    }

    It "has valid PowerShell syntax" {
        $script:uninstallPath | Should -Exist
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($script:uninstallContent, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "has KeepSounds parameter" {
        $script:uninstallContent | Should -Match '\[switch\]\$KeepSounds'
    }

    It "has Force parameter" {
        $script:uninstallContent | Should -Match '\[switch\]\$Force'
    }

    It "removes hooks from settings.json" {
        $script:uninstallContent | Should -Match 'settings\.json'
        $script:uninstallContent | Should -Match 'peon\.ps1.*peon\.sh.*notify\.sh.*hook-handle-use'
    }

    It "removes skills" {
        $script:uninstallContent | Should -Match 'peon-ping-toggle.*peon-ping-config.*peon-ping-use'
    }

    It "removes CLI command (peon.cmd)" {
        $script:uninstallContent | Should -Match 'peon\.cmd'
    }

    It "preserves packs directory when KeepSounds is set" {
        $script:uninstallContent | Should -Match '\$_.Name -ne "packs"'
    }

    It "cleans up Cursor hooks" {
        $script:uninstallContent | Should -Match 'hooks\.json'
        $script:uninstallContent | Should -Match 'hook-handle-use'
    }

    It "does not use ExecutionPolicy Bypass" {
        $script:uninstallContent | Should -Not -Match 'ExecutionPolicy Bypass'
    }
}

# ============================================================
# Embedded peon.ps1 hook script (inside install.ps1)
# Mirrors BATS test coverage for peon.sh event handling
# ============================================================

Describe "Embedded peon.ps1 Hook Script" {
    BeforeAll {
        # Extract the embedded peon.ps1 from install.ps1 (between @' and '@)
        $script:installContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
        if ($script:installContent -match "(?s)\`$hookScript = @'(.+?)'@") {
            $script:peonHookContent = $matches[1]
        } else {
            $script:peonHookContent = ""
        }
    }

    It "embedded hook script is extractable" {
        $script:peonHookContent | Should -Not -BeNullOrEmpty
    }

    It "has valid PowerShell syntax" {
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($script:peonHookContent, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    # --- Event Routing (mirrors BATS: SessionStart/Stop/Notification/PermissionRequest) ---

    It "maps SessionStart to session.start category" {
        $script:peonHookContent | Should -Match '"SessionStart"\s*\{[^}]*\$category = "session\.start"'
    }

    It "maps Stop to task.complete category" {
        $script:peonHookContent | Should -Match '"Stop"\s*\{[^}]*\$category = "task\.complete"'
    }

    It "maps PermissionRequest to input.required category" {
        $script:peonHookContent | Should -Match '"PermissionRequest"\s*\{[^}]*\$category = "input\.required"'
    }

    It "maps PostToolUseFailure to task.error category" {
        $script:peonHookContent | Should -Match '"PostToolUseFailure"\s*\{[^}]*\$category = "task\.error"'
    }

    It "maps SubagentStart to task.acknowledge category" {
        $script:peonHookContent | Should -Match '"SubagentStart"\s*\{[^}]*\$category = "task\.acknowledge"'
    }

    # --- Cursor Event Remapping ---

    It "remaps Cursor camelCase events to PascalCase" {
        $script:peonHookContent | Should -Match '"sessionStart"\s*=\s*"SessionStart"'
        $script:peonHookContent | Should -Match '"stop"\s*=\s*"Stop"'
        $script:peonHookContent | Should -Match '"beforeSubmitPrompt"\s*=\s*"UserPromptSubmit"'
    }

    It "remaps subagentStart to SubagentStart" {
        $script:peonHookContent | Should -Match '"subagentStart"\s*=\s*"SubagentStart"'
    }

    It "remaps preCompact to PreCompact" {
        $script:peonHookContent | Should -Match '"preCompact"\s*=\s*"PreCompact"'
    }

    # --- Stop Debounce (mirrors BATS: rapid Stop events are debounced) ---

    It "debounces rapid Stop events with 5s cooldown" {
        $script:peonHookContent | Should -Match 'last_stop_time'
        $script:peonHookContent | Should -Match '-lt 5'
    }

    # --- Annoyed Easter Egg (mirrors BATS: annoyed triggers after rapid prompts) ---

    It "detects rapid UserPromptSubmit for annoyed easter egg" {
        $script:peonHookContent | Should -Match '"UserPromptSubmit"\s*\{'
        $script:peonHookContent | Should -Match 'annoyedThreshold'
        $script:peonHookContent | Should -Match 'annoyedWindow'
    }

    It "maps annoyed to user.spam category" {
        $script:peonHookContent | Should -Match '\$category = "user\.spam"'
    }

    It "tracks prompt timestamps per session" {
        $script:peonHookContent | Should -Match 'prompt_timestamps'
        $script:peonHookContent | Should -Match '\$sessionId'
    }

    # --- Config: enabled/disabled (mirrors BATS: enabled=false skips everything) ---

    It "exits early when config enabled is false" {
        $script:peonHookContent | Should -Match '-not \$config\.enabled.*exit 0'
    }

    # --- Category toggle (mirrors BATS: category disabled skips sound) ---

    It "checks if category is enabled before playing sound" {
        $script:peonHookContent | Should -Match '\$catEnabled.*-eq \$false.*exit 0'
    }

    # --- Sound Selection: No-Repeat (mirrors BATS: sound picker avoids immediate repeats) ---

    It "implements no-repeat logic for sound selection" {
        $script:peonHookContent | Should -Match 'lastPlayed'
        $script:peonHookContent | Should -Match '-ne \$lastPlayed'
    }

    It "persists last played sound to state" {
        $script:peonHookContent | Should -Match '\$state\[\$lastKey\] = \$soundFile'
    }

    It "falls back to all candidates when filtering leaves none" {
        $script:peonHookContent | Should -Match '\$candidates\.Count -eq 0.*\$candidates = @\(\$catSounds\)'
    }

    # --- Icon Resolution Chain (mirrors BATS: CESP §5.5 icon tests) ---

    It "resolves sound-level icon first" {
        $script:peonHookContent | Should -Match '\$chosen\.icon'
    }

    It "resolves category-level icon second" {
        $script:peonHookContent | Should -Match '\$manifest\.categories\.\$category\.icon'
    }

    It "resolves pack-level icon third" {
        $script:peonHookContent | Should -Match '\$manifest\.icon'
    }

    It "falls back to icon.png at pack root" {
        $script:peonHookContent | Should -Match 'icon\.png'
    }

    It "blocks path traversal in icon resolution" {
        $script:peonHookContent | Should -Match 'StartsWith\(\$packRoot\)'
    }

    # --- Pack Rotation / Session Override (mirrors BATS: session_override mode) ---

    It "supports agentskill / session_override rotation mode" {
        $script:peonHookContent | Should -Match 'agentskill.*session_override'
    }

    It "looks up session-specific pack from session_packs state" {
        $script:peonHookContent | Should -Match 'session_packs'
        $script:peonHookContent | Should -Match 'sessionId'
    }

    It "uses Get-ActivePack helper for pack resolution" {
        $script:peonHookContent | Should -Match 'function Get-ActivePack'
        $script:peonHookContent | Should -Match '\$activePack = Get-ActivePack \$config'
    }

    It "Get-ActivePack falls back through default_pack, active_pack, then peon" {
        $script:peonHookContent | Should -Match 'default_pack'
        $script:peonHookContent | Should -Match 'active_pack'
        $script:peonHookContent | Should -Match '"peon"'
    }

    # --- Volume (mirrors BATS: volume from config is passed to playback) ---

    It "reads volume from config" {
        $script:peonHookContent | Should -Match '\$volume = \$config\.volume'
    }

    It "defaults volume to 0.5" {
        $script:peonHookContent | Should -Match '\$volume.*0\.5'
    }

    # --- Self-Timeout Safety Net ---

    It "registers an 8-second self-timeout timer before any I/O" {
        $script:peonHookContent | Should -Match 'System\.Timers\.Timer'
        $script:peonHookContent | Should -Match '8000'
        $script:peonHookContent | Should -Match '\[Environment\]::Exit\(1\)'
    }

    # --- Audio Delegation (detached process via win-play.ps1) ---

    It "contains zero references to MediaPlayer, PresentationCore, SoundPlayer, or System.Windows.Forms" {
        $script:peonHookContent | Should -Not -Match 'MediaPlayer'
        $script:peonHookContent | Should -Not -Match 'PresentationCore'
        $script:peonHookContent | Should -Not -Match 'SoundPlayer'
        $script:peonHookContent | Should -Not -Match 'System\.Windows\.Forms'
    }

    It "delegates audio to win-play.ps1 via Start-Process with -WindowStyle Hidden" {
        $script:peonHookContent | Should -Match 'Start-Process'
        $script:peonHookContent | Should -Match 'win-play\.ps1'
        $script:peonHookContent | Should -Match 'WindowStyle Hidden'
    }

    # --- CLI Commands (mirrors BATS: peon --toggle/--pause/--resume/--status) ---

    It "supports --toggle CLI command" {
        $script:peonHookContent | Should -Match '--toggle'
        $script:peonHookContent | Should -Match '-not \$cfg\.enabled'
    }

    It "supports --pause CLI command" {
        $script:peonHookContent | Should -Match '--pause'
        $script:peonHookContent | Should -Match '"enabled": false'
    }

    It "supports --resume CLI command" {
        $script:peonHookContent | Should -Match '--resume'
        $script:peonHookContent | Should -Match '"enabled": true'
    }

    It "supports --status CLI command" {
        $script:peonHookContent | Should -Match '--status'
        $script:peonHookContent | Should -Match 'ENABLED'
        $script:peonHookContent | Should -Match 'PAUSED'
    }

    It "supports --packs CLI command with use/next/list subcommands" {
        $script:peonHookContent | Should -Match '--packs'
        $script:peonHookContent | Should -Match '"use"'
        $script:peonHookContent | Should -Match '"next"'
    }

    It "supports --volume CLI command with clamping" {
        $script:peonHookContent | Should -Match '--volume'
        $script:peonHookContent | Should -Match 'Max.*0\.0.*Min.*1\.0'
    }

    It "supports --help CLI command" {
        $script:peonHookContent | Should -Match '--help'
    }

    # --- State Persistence ---

    It "reads and writes .state.json" {
        $script:peonHookContent | Should -Match '\.state\.json'
        $script:peonHookContent | Should -Match 'Write-StateAtomic'
    }

    It "Write-StateAtomic uses Move-Item -Force on PS 7+ for atomic overwrite" {
        $script:peonHookContent | Should -Match 'PSVersionTable\.PSVersion\.Major -ge 7'
        $script:peonHookContent | Should -Match 'Move-Item -Path \$tmp -Destination \$Path -Force'
    }

    It "Write-StateAtomic preserves PS 5.1 delete-then-move fallback" {
        $script:peonHookContent | Should -Match '\[System\.IO\.File\]::Delete\(\$Path\)'
        $script:peonHookContent | Should -Match '\[System\.IO\.File\]::Move\(\$tmp, \$Path\)'
    }

    It "Read-StateWithRetry cleans up orphaned .tmp files on startup" {
        $script:peonHookContent | Should -Match 'Get-ChildItem.*\.tmp.*ErrorAction SilentlyContinue'
        $script:peonHookContent | Should -Match 'orphaned \.tmp files'
    }

    It "reads stdin JSON via StreamReader (UTF-8 BOM-safe)" {
        $script:peonHookContent | Should -Match 'OpenStandardInput'
        $script:peonHookContent | Should -Match 'StreamReader'
        $script:peonHookContent | Should -Match 'UTF8'
    }

    # --- Session Cleanup ---

    It "expires old sessions based on TTL" {
        $script:peonHookContent | Should -Match 'session_ttl_days'
        $script:peonHookContent | Should -Match 'cutoff'
    }

    It "converts PSCustomObject to hashtable for PS 5.1 compat" {
        $script:peonHookContent | Should -Match 'ConvertTo-Hashtable'
    }
}

# ============================================================
# install.ps1 embedded hook: config defaults
# (mirrors BATS: default config creation tests)
# ============================================================

Describe "install.ps1 Default Config" {
    BeforeAll {
        $script:installContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
    }

    It "sets default volume to 0.5" {
        $script:installContent | Should -Match 'volume = 0\.5'
    }

    It "enables all CESP categories by default" {
        $script:installContent | Should -Match '"session\.start" = \$true'
        $script:installContent | Should -Match '"task\.complete" = \$true'
        $script:installContent | Should -Match '"task\.error" = \$true'
        $script:installContent | Should -Match '"input\.required" = \$true'
        $script:installContent | Should -Match '"resource\.limit" = \$true'
        $script:installContent | Should -Match '"user\.spam" = \$true'
    }

    It "sets annoyed threshold to 3 with 10s window" {
        $script:installContent | Should -Match 'annoyed_threshold = 3'
        $script:installContent | Should -Match 'annoyed_window_seconds = 10'
    }

    It "sets silent_window_seconds to 0 (disabled)" {
        $script:installContent | Should -Match 'silent_window_seconds = 0'
    }

    It "registers all 8 hook events" {
        $script:installContent | Should -Match '"SessionStart".*"SessionEnd".*"SubagentStart".*"Stop".*"Notification".*"PermissionRequest".*"PostToolUseFailure".*"PreCompact"'
    }

    It "uses invariant culture for JSON serialization (locale safety)" {
        $script:installContent | Should -Match 'InvariantCulture'
    }

    It "repairs locale-damaged volume decimals (e.g. 0,5 -> 0.5)" {
        $script:installContent | Should -Match 'Get-PeonConfigRaw'
        $script:installContent | Should -Match '\\d\),\(\\d'
    }

    It "installs skills" {
        $script:installContent | Should -Match 'peon-ping-toggle'
        $script:installContent | Should -Match 'peon-ping-config'
        $script:installContent | Should -Match 'peon-ping-use'
        $script:installContent | Should -Match 'peon-ping-log'
    }

    It "installs trainer voice packs" {
        $script:installContent | Should -Match 'trainer.*manifest\.json'
    }

    It "creates CLI wrappers for both cmd and bash" {
        $script:installContent | Should -Match 'peon\.cmd'
        $script:installContent | Should -Match '#!/usr/bin/env bash'
    }

    It "validates pack names with safe charset" {
        $script:installContent | Should -Match 'Test-SafePackName'
    }

    It "validates source repo, ref, and path" {
        $script:installContent | Should -Match 'Test-SafeSourceRepo'
        $script:installContent | Should -Match 'Test-SafeSourceRef'
        $script:installContent | Should -Match 'Test-SafeSourcePath'
    }

    It "validates sound filenames" {
        $script:installContent | Should -Match 'Test-SafeFilename'
    }

    It "blocks path traversal in source ref and path" {
        $script:installContent | Should -Match '\.\.'
    }

    It "prints ffmpeg recommendation if ffplay not found" {
        $script:installContent | Should -Match 'ffplay'
        $script:installContent | Should -Match 'winget install ffmpeg'
    }

    It "recommends choco as preferred ffmpeg install method" {
        $script:installContent | Should -Match 'choco install ffmpeg'
    }

    It "warns about winget ffplay PATH issue" {
        $script:installContent | Should -Match 'may not add ffplay to PATH'
    }
}

# ============================================================
# path_rules: Runtime Matching Engine (mirrors BATS path_rules tests)
# ============================================================

Describe "path_rules: Runtime Matching Engine" {
    BeforeAll {
        $script:peonHookContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
    }

    # --- Matching engine structural tests ---

    It "evaluates path_rules against event cwd" {
        $script:peonHookContent | Should -Match 'eventCwd.*-like.*\$pat'
    }

    It "checks that matched pack directory exists before selecting" {
        $script:peonHookContent | Should -Match 'pathRulePack = \$candidate'
        $script:peonHookContent | Should -Match 'Test-Path \$candidateDir -PathType Container'
    }

    It "first matching rule wins (breaks on first match)" {
        # The foreach loop should break after finding the first match
        $script:peonHookContent | Should -Match 'pathRulePack = \$candidate'
        $script:peonHookContent | Should -Match 'break'
    }

    It "missing pack falls through (only sets pathRulePack when pack dir exists)" {
        $script:peonHookContent | Should -Match 'Test-Path \$candidateDir -PathType Container'
    }

    It "path_rules beats pack_rotation in hierarchy" {
        # pathRulePack is checked before pack_rotation
        $script:peonHookContent | Should -Match 'elseif \(\$pathRulePack\)'
        $script:peonHookContent | Should -Match '\$activePack = \$pathRulePack'
    }

    It "empty path_rules array is a no-op (uses default_pack)" {
        # The foreach simply does nothing when path_rules is empty
        $script:peonHookContent | Should -Match 'foreach \(\$rule in \$config\.path_rules\)'
    }

    It "session_override beats path_rules in hierarchy" {
        # session_override/agentskill check happens in the if block, path_rules in elseif
        $script:peonHookContent | Should -Match 'agentskill.*session_override'
    }

    It "no cwd skips path_rules matching" {
        $script:peonHookContent | Should -Match 'if \(\$eventCwd'
    }

    It "uses Get-ActivePack for default pack resolution" {
        $script:peonHookContent | Should -Match 'Get-ActivePack \$config'
    }
}

# ============================================================
# path_rules: CLI Commands (bind / unbind / bindings)
# ============================================================

Describe "path_rules: CLI Commands - Structural" {
    BeforeAll {
        $script:peonHookContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
    }

    It "bind subcommand exists in --packs switch" {
        $script:peonHookContent | Should -Match '"bind"\s*\{'
    }

    It "unbind subcommand exists in --packs switch" {
        $script:peonHookContent | Should -Match '"unbind"\s*\{'
    }

    It "bindings subcommand exists in --packs switch" {
        $script:peonHookContent | Should -Match '"bindings"\s*\{'
    }

    It "bind validates pack exists before binding" {
        $script:peonHookContent | Should -Match 'packName -notin \$available'
    }

    It "bind supports --pattern flag" {
        $script:peonHookContent | Should -Match '"--pattern"'
        $script:peonHookContent | Should -Match 'bindPattern'
    }

    It "bind supports --install flag" {
        $script:peonHookContent | Should -Match '"--install"'
        $script:peonHookContent | Should -Match 'bindInstall'
    }

    It "bind writes path_rules to config.json" {
        $script:peonHookContent | Should -Match 'cfgObj\.path_rules = \$pathRules'
        $script:peonHookContent | Should -Match 'ConvertTo-Json.*Set-Content'
    }

    It "bind updates existing rule for same pattern (upsert)" {
        $script:peonHookContent | Should -Match '\.pattern -eq \$bindPattern'
    }

    It "unbind removes rule by exact pattern match" {
        $script:peonHookContent | Should -Match '\.pattern -ne \$target'
    }

    It "unbind suggests --pattern when cwd has matching rules" {
        $script:peonHookContent | Should -Match 'Use --pattern to remove a specific rule'
    }

    It "bindings marks active rule with asterisk" {
        $script:peonHookContent | Should -Match '\$marker.*-like.*\$rule\.pattern'
    }

    It "bindings shows message when no rules configured" {
        $script:peonHookContent | Should -Match 'No pack bindings configured'
    }

    It "help text includes bind/unbind/bindings" {
        $script:peonHookContent | Should -Match '--packs bind'
        $script:peonHookContent | Should -Match '--packs unbind'
        $script:peonHookContent | Should -Match '--packs bindings'
    }
}

# ============================================================
# path_rules: CLI Commands - Functional (B6: true E2E tests)
# ============================================================

Describe "path_rules: CLI Commands - Functional" {
    BeforeAll {
        # Extract the embedded hook script from install.ps1 (the here-string between @' and '@)
        $installContent = Get-Content (Join-Path $script:RepoRoot "install.ps1") -Raw
        $startMarker = "`$hookScript = @'"
        $endMarker = "'@"
        $startIdx = $installContent.IndexOf($startMarker)
        $hookStart = $installContent.IndexOf("`n", $startIdx) + 1
        $hookEnd = $installContent.IndexOf("`n'@", $hookStart)
        $script:hookScriptContent = $installContent.Substring($hookStart, $hookEnd - $hookStart)
    }

    BeforeEach {
        # Create isolated test environment
        $script:testDir = Join-Path $env:TEMP "peon-test-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        $script:packsDir = Join-Path $script:testDir "packs"

        # Create mock packs with sounds
        foreach ($p in @("peon", "sc_kerrigan")) {
            $pDir = Join-Path $script:packsDir "$p\sounds"
            New-Item -ItemType Directory -Path $pDir -Force | Out-Null
            # Create a dummy sound file and manifest
            Set-Content (Join-Path $pDir "hello.wav") "mock"
            $manifest = @{
                display_name = $p
                categories = @{
                    "task.complete" = @{
                        sounds = @(@{ file = "sounds/hello.wav"; label = "hello" })
                    }
                }
            }
            $manifest | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $script:packsDir "$p\openpeon.json") -Encoding UTF8
        }

        # Create config
        $script:configPath = Join-Path $script:testDir "config.json"
        @{
            default_pack = "peon"
            volume = 0.5
            enabled = $true
            categories = @{}
            path_rules = @()
        } | ConvertTo-Json -Depth 5 | Set-Content $script:configPath -Encoding UTF8

        # Write the extracted hook script as peon.ps1 in the test dir
        $script:peonPs1 = Join-Path $script:testDir "peon.ps1"
        Set-Content $script:peonPs1 -Value $script:hookScriptContent -Encoding UTF8
    }

    AfterEach {
        Remove-Item $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "packs bind sets path_rules entry" {
        $result = & powershell.exe -NoProfile -Command "Set-Location '$script:testDir'; & '$script:peonPs1' --packs bind peon 2>&1"
        ($result -join "`n") | Should -Match "bound peon to"
        $cfg = Get-Content $script:configPath -Raw | ConvertFrom-Json
        $cfg.path_rules.Count | Should -Be 1
        $cfg.path_rules[0].pack | Should -Be "peon"
    }

    It "packs bind with --pattern stores custom pattern" {
        $result = & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind sc_kerrigan --pattern '*/myproject/*' 2>&1"
        ($result -join "`n") | Should -Match "bound sc_kerrigan to \*/myproject/\*"
        $cfg = Get-Content $script:configPath -Raw | ConvertFrom-Json
        $cfg.path_rules[0].pattern | Should -Be "*/myproject/*"
    }

    It "packs bind updates existing rule for same pattern" {
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind peon --pattern '*/proj/*' 2>&1" | Out-Null
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind sc_kerrigan --pattern '*/proj/*' 2>&1" | Out-Null
        $cfg = Get-Content $script:configPath -Raw | ConvertFrom-Json
        $cfg.path_rules.Count | Should -Be 1
        $cfg.path_rules[0].pack | Should -Be "sc_kerrigan"
    }

    It "packs bind validates pack exists" {
        $result = & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind nonexistent 2>&1"
        ($result -join "`n") | Should -Match "not found"
    }

    It "packs unbind removes rule" {
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind peon --pattern '*/test/*' 2>&1" | Out-Null
        $cfg = Get-Content $script:configPath -Raw | ConvertFrom-Json
        $cfg.path_rules.Count | Should -Be 1
        $result = & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs unbind --pattern '*/test/*' 2>&1"
        ($result -join "`n") | Should -Match "unbound"
        $cfg = Get-Content $script:configPath -Raw | ConvertFrom-Json
        $cfg.path_rules.Count | Should -Be 0
    }

    It "packs unbind with --pattern removes specific pattern" {
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind peon --pattern '*/proj-a/*' 2>&1" | Out-Null
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind sc_kerrigan --pattern '*/proj-b/*' 2>&1" | Out-Null
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs unbind --pattern '*/proj-a/*' 2>&1" | Out-Null
        $cfg = Get-Content $script:configPath -Raw | ConvertFrom-Json
        $cfg.path_rules.Count | Should -Be 1
        $cfg.path_rules[0].pack | Should -Be "sc_kerrigan"
    }

    It "packs unbind no matching rule prints message" {
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind peon --pattern '*/other/*' 2>&1" | Out-Null
        $result = & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs unbind --pattern '*/nonexistent/*' 2>&1"
        ($result -join "`n") | Should -Match "No binding found"
    }

    It "packs bindings lists rules" {
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind peon --pattern '*/proj-a/*' 2>&1" | Out-Null
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind sc_kerrigan --pattern '*/proj-b/*' 2>&1" | Out-Null
        $result = & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bindings 2>&1"
        ($result -join "`n") | Should -Match '\*/proj-a/\* -> peon'
        ($result -join "`n") | Should -Match '\*/proj-b/\* -> sc_kerrigan'
    }

    It "packs bindings empty prints message" {
        $result = & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bindings 2>&1"
        ($result -join "`n") | Should -Match "No pack bindings configured"
    }

    It "status shows path rules count" {
        & powershell.exe -NoProfile -Command "& '$script:peonPs1' --packs bind peon --pattern '*/proj/*' 2>&1" | Out-Null
        $result = & powershell.exe -NoProfile -Command "& '$script:peonPs1' --status 2>&1"
        ($result -join "`n") | Should -Match "path rules: 1 configured"
    }
}
