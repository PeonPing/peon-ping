# Pester tests for Windows PowerShell adapters (.ps1)
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

$RepoRoot = Split-Path $PSScriptRoot -Parent
$AdaptersDir = Join-Path $RepoRoot "adapters"

# ============================================================
# Syntax validation
# ============================================================

Describe "PowerShell Syntax Validation" {
    $categoryA = @("codex", "gemini", "copilot", "windsurf", "kiro", "openclaw")
    $categoryB = @("amp", "antigravity", "kimi")
    $categoryC = @("opencode", "kilo")
    $allAdapters = $categoryA + $categoryB + $categoryC

    foreach ($name in $allAdapters) {
        It "adapters/$name.ps1 has valid PowerShell syntax" {
            $path = Join-Path $AdaptersDir "$name.ps1"
            $path | Should Exist
            $content = Get-Content $path -Raw
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
            $errors.Count | Should Be 0
        }
    }
}

# ============================================================
# Security: no ExecutionPolicy Bypass
# ============================================================

Describe "No ExecutionPolicy Bypass" {
    $allAdapters = @("codex", "gemini", "copilot", "windsurf", "kiro", "openclaw",
                     "amp", "antigravity", "kimi", "opencode", "kilo")

    foreach ($name in $allAdapters) {
        It "adapters/$name.ps1 does not use ExecutionPolicy Bypass" {
            $path = Join-Path $AdaptersDir "$name.ps1"
            $content = Get-Content $path -Raw
            $content | Should Not Match "ExecutionPolicy Bypass"
        }
    }

    It "install.ps1 does not use ExecutionPolicy Bypass" {
        $path = Join-Path $RepoRoot "install.ps1"
        $content = Get-Content $path -Raw
        $content | Should Not Match "ExecutionPolicy Bypass"
    }
}

# ============================================================
# Category A: Simple Event Translators
# ============================================================

Describe "Category A: Codex Adapter" {
    $script = Join-Path $AdaptersDir "codex.ps1"
    $content = Get-Content $script -Raw

    It "accepts Event parameter" {
        $content | Should Match 'param\('
        $content | Should Match '\[string\]\$Event'
    }

    It "maps agent-turn-complete to Stop" {
        $content | Should Match '"agent-turn-complete".*"complete".*"done"'
        $content | Should Match '\$mapped = "Stop"'
    }

    It "maps start/session-start to SessionStart" {
        $content | Should Match '"start".*"session-start"'
        $content | Should Match '\$mapped = "SessionStart"'
    }

    It "maps permission events to Notification with permission_prompt" {
        $content | Should Match 'permission'
        $content | Should Match '\$ntype = "permission_prompt"'
    }

    It "pipes JSON to peon.ps1" {
        $content | Should Match 'peon\.ps1'
        $content | Should Match 'ConvertTo-Json'
    }
}

Describe "Category A: Gemini Adapter" {
    $script = Join-Path $AdaptersDir "gemini.ps1"
    $content = Get-Content $script -Raw

    It "accepts EventType parameter" {
        $content | Should Match '\[string\]\$EventType'
    }

    It "maps SessionStart to SessionStart" {
        $content | Should Match '"SessionStart"\s*\{[^}]*\$mapped = "SessionStart"'
    }

    It "maps AfterAgent to Stop" {
        $content | Should Match '"AfterAgent"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "maps AfterTool with non-zero exit to PostToolUseFailure" {
        $content | Should Match 'PostToolUseFailure'
    }

    It "reads JSON from stdin" {
        $content | Should Match 'IsInputRedirected'
        $content | Should Match 'StreamReader'
    }

    It "returns empty JSON object to Gemini" {
        $content | Should Match 'Write-Output "\{\}"'
    }
}

Describe "Category A: Copilot Adapter" {
    $script = Join-Path $AdaptersDir "copilot.ps1"
    $content = Get-Content $script -Raw

    It "maps sessionStart to SessionStart" {
        $content | Should Match '"sessionStart"\s*\{[^}]*\$mapped = "SessionStart"'
    }

    It "maps postToolUse to Stop" {
        $content | Should Match '"postToolUse"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "maps errorOccurred to PostToolUseFailure" {
        $content | Should Match '"errorOccurred"\s*\{[^}]*\$mapped = "PostToolUseFailure"'
    }

    It "handles first userPromptSubmitted as SessionStart" {
        $content | Should Match 'copilot-session'
        $content | Should Match '\$mapped = "SessionStart"'
    }

    It "handles subsequent userPromptSubmitted as UserPromptSubmit" {
        $content | Should Match '\$mapped = "UserPromptSubmit"'
    }

    It "exits gracefully for sessionEnd" {
        $content | Should Match '"sessionEnd"'
        $content | Should Match 'exit 0'
    }

    It "exits gracefully for preToolUse (too noisy)" {
        $content | Should Match '"preToolUse"'
    }
}

Describe "Category A: Windsurf Adapter" {
    $script = Join-Path $AdaptersDir "windsurf.ps1"
    $content = Get-Content $script -Raw

    It "maps post_cascade_response to Stop" {
        $content | Should Match '"post_cascade_response"\s*\{[^}]*\$mapped = "Stop"'
    }

    It "handles pre_user_prompt session detection" {
        $content | Should Match 'windsurf-session'
        $content | Should Match '"pre_user_prompt"'
    }

    It "maps post_write_code to Stop" {
        $content | Should Match '"post_write_code"'
    }

    It "maps post_run_command to Stop" {
        $content | Should Match '"post_run_command"'
    }

    It "drains stdin" {
        $content | Should Match 'IsInputRedirected'
    }
}

Describe "Category A: Kiro Adapter" {
    $script = Join-Path $AdaptersDir "kiro.ps1"
    $content = Get-Content $script -Raw

    It "remaps agentSpawn to SessionStart" {
        $content | Should Match '"agentSpawn"\s*=\s*"SessionStart"'
    }

    It "remaps userPromptSubmit to UserPromptSubmit" {
        $content | Should Match '"userPromptSubmit"\s*=\s*"UserPromptSubmit"'
    }

    It "remaps stop to Stop" {
        $content | Should Match '"stop"\s*=\s*"Stop"'
    }

    It "prefixes session_id with kiro-" {
        $content | Should Match '"kiro-\$sid"'
    }

    It "skips unknown events" {
        $content | Should Match 'if \(-not \$mapped\)'
        $content | Should Match 'exit 0'
    }
}

Describe "Category A: OpenClaw Adapter" {
    $script = Join-Path $AdaptersDir "openclaw.ps1"
    $content = Get-Content $script -Raw

    It "maps session.start to SessionStart" {
        $content | Should Match '"session\.start"'
        $content | Should Match '\$mapped = "SessionStart"'
    }

    It "maps task.complete to Stop" {
        $content | Should Match '"task\.complete"'
        $content | Should Match '\$mapped = "Stop"'
    }

    It "maps task.error to PostToolUseFailure" {
        $content | Should Match '"task\.error"'
        $content | Should Match '\$mapped = "PostToolUseFailure"'
    }

    It "maps input.required to Notification with permission_prompt" {
        $content | Should Match '"input\.required"'
        $content | Should Match '\$ntype = "permission_prompt"'
    }

    It "maps resource.limit to Notification with resource_limit" {
        $content | Should Match '"resource\.limit"'
        $content | Should Match '\$ntype = "resource_limit"'
    }

    It "accepts raw Claude Code event names" {
        $content | Should Match '"SessionStart", "Stop", "Notification"'
    }
}

# ============================================================
# Category B: Filesystem Watcher Adapters
# ============================================================

Describe "Category B: Amp Adapter" {
    $script = Join-Path $AdaptersDir "amp.ps1"
    $content = Get-Content $script -Raw

    It "has Install/Uninstall/Status daemon flags" {
        $content | Should Match '\[switch\]\$Install'
        $content | Should Match '\[switch\]\$Uninstall'
        $content | Should Match '\[switch\]\$Status'
    }

    It "uses FileSystemWatcher" {
        $content | Should Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches T-*.json files" {
        $content | Should Match 'T-\*\.json'
    }

    It "has idle detection logic" {
        $content | Should Match 'IdleSeconds'
        $content | Should Match 'StopCooldown'
    }

    It "checks if thread is waiting for user input" {
        $content | Should Match 'Test-ThreadWaiting'
        $content | Should Match 'tool_use'
    }

    It "has PID file management" {
        $content | Should Match '\.amp-adapter\.pid'
    }

    It "tries Windows-native AMP_DATA_DIR path first" {
        $content | Should Match 'LOCALAPPDATA'
    }
}

Describe "Category B: Antigravity Adapter" {
    $script = Join-Path $AdaptersDir "antigravity.ps1"
    $content = Get-Content $script -Raw

    It "has Install/Uninstall/Status daemon flags" {
        $content | Should Match '\[switch\]\$Install'
        $content | Should Match '\[switch\]\$Uninstall'
        $content | Should Match '\[switch\]\$Status'
    }

    It "uses FileSystemWatcher" {
        $content | Should Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches *.pb files" {
        $content | Should Match '\*\.pb'
    }

    It "has idle detection logic" {
        $content | Should Match 'IdleSeconds'
        $content | Should Match 'StopCooldown'
    }

    It "has PID file management" {
        $content | Should Match '\.antigravity-adapter\.pid'
    }
}

Describe "Category B: Kimi Adapter" {
    $script = Join-Path $AdaptersDir "kimi.ps1"
    $content = Get-Content $script -Raw

    It "has Install/Uninstall/Status/Help flags" {
        $content | Should Match '\[switch\]\$Install'
        $content | Should Match '\[switch\]\$Uninstall'
        $content | Should Match '\[switch\]\$Status'
        $content | Should Match '\[switch\]\$Help'
    }

    It "uses FileSystemWatcher" {
        $content | Should Match 'System\.IO\.FileSystemWatcher'
    }

    It "watches wire.jsonl files with subdirectory recursion" {
        $content | Should Match 'wire\.jsonl'
        $content | Should Match 'IncludeSubdirectories.*true'
    }

    It "maps TurnEnd to Stop" {
        $content | Should Match '"TurnEnd".*"Stop"'
    }

    It "maps TurnBegin to SessionStart for new sessions" {
        $content | Should Match '"TurnBegin"'
        $content | Should Match '"SessionStart"'
    }

    It "maps SubagentEvent with TurnBegin to SubagentStart" {
        $content | Should Match '"SubagentEvent"'
        $content | Should Match '"SubagentStart"'
    }

    It "maps CompactionBegin to PreCompact" {
        $content | Should Match '"CompactionBegin".*"PreCompact"'
    }

    It "has /clear detection logic" {
        $content | Should Match 'ClearGraceSeconds'
        $content | Should Match 'lastNewSession'
    }

    It "resolves CWD from workspace hash using MD5" {
        $content | Should Match 'Resolve-KimiCwd'
        $content | Should Match 'MD5'
    }

    It "reads new bytes from wire.jsonl using offset tracking" {
        $content | Should Match 'sessionOffset'
        $content | Should Match 'FileStream'
    }

    It "has PID file management" {
        $content | Should Match '\.kimi-adapter\.pid'
    }
}

# ============================================================
# Category C: Installer Adapters
# ============================================================

Describe "Category C: OpenCode Installer" {
    $script = Join-Path $AdaptersDir "opencode.ps1"
    $content = Get-Content $script -Raw

    It "has Uninstall flag" {
        $content | Should Match '\[switch\]\$Uninstall'
    }

    It "downloads the peon-ping.ts plugin" {
        $content | Should Match 'peon-ping\.ts'
        $content | Should Match 'Invoke-WebRequest'
    }

    It "creates default config.json" {
        $content | Should Match 'config\.json'
        $content | Should Match 'active_pack'
    }

    It "installs default pack from registry" {
        $content | Should Match 'peonping\.github\.io/registry'
    }

    It "uses LOCALAPPDATA for Windows-native path" {
        $content | Should Match 'LOCALAPPDATA'
    }
}

Describe "Category C: Kilo Installer" {
    $script = Join-Path $AdaptersDir "kilo.ps1"
    $content = Get-Content $script -Raw

    It "has Uninstall flag" {
        $content | Should Match '\[switch\]\$Uninstall'
    }

    It "downloads and patches OpenCode plugin for Kilo" {
        $content | Should Match 'peon-ping\.ts'
        $content | Should Match '@kilocode/plugin'
    }

    It "patches config path from opencode to kilo" {
        $content | Should Match '".config", "kilo", "peon-ping"'
    }

    It "creates default config.json" {
        $content | Should Match 'config\.json'
        $content | Should Match 'active_pack'
    }

    It "installs default pack from registry" {
        $content | Should Match 'peonping\.github\.io/registry'
    }
}

# ============================================================
# install.ps1 adapter installation
# ============================================================

Describe "install.ps1 Adapter Installation" {
    $installScript = Join-Path $RepoRoot "install.ps1"
    $content = Get-Content $installScript -Raw

    It "installs adapter scripts to adapters/ directory" {
        $content | Should Match 'Installing adapter scripts'
        $content | Should Match 'adapters'
    }

    It "installs all 11 adapter files" {
        $content | Should Match 'codex\.ps1'
        $content | Should Match 'gemini\.ps1'
        $content | Should Match 'copilot\.ps1'
        $content | Should Match 'windsurf\.ps1'
        $content | Should Match 'kiro\.ps1'
        $content | Should Match 'openclaw\.ps1'
        $content | Should Match 'amp\.ps1'
        $content | Should Match 'antigravity\.ps1'
        $content | Should Match 'kimi\.ps1'
        $content | Should Match 'opencode\.ps1'
        $content | Should Match 'kilo\.ps1'
    }

    It "calls Unblock-File on installed adapters" {
        $content | Should Match 'Unblock-File'
    }

    It "has execution policy detection" {
        $content | Should Match 'Get-ExecutionPolicy'
        $content | Should Match 'Restricted'
    }

    It "handles missing Claude Code gracefully" {
        $content | Should Match 'ClaudeCodeDetected'
        $content | Should Match 'Skipping Claude Code hook registration'
    }
}

# ============================================================
# Cross-cutting: peon.ps1 resolution pattern
# ============================================================

Describe "All adapters resolve peon.ps1 via CLAUDE_PEON_DIR" {
    $allAdapters = @("codex", "gemini", "copilot", "windsurf", "kiro", "openclaw",
                     "amp", "antigravity", "kimi")

    foreach ($name in $allAdapters) {
        It "adapters/$name.ps1 checks CLAUDE_PEON_DIR env var" {
            $path = Join-Path $AdaptersDir "$name.ps1"
            $content = Get-Content $path -Raw
            $content | Should Match 'CLAUDE_PEON_DIR'
        }

        It "adapters/$name.ps1 falls back to ~/.claude/hooks/peon-ping" {
            $path = Join-Path $AdaptersDir "$name.ps1"
            $content = Get-Content $path -Raw
            $content | Should Match '\.claude\\hooks\\peon-ping'
        }
    }
}
