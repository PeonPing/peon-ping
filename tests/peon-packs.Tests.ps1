# Pester 5 tests for peon.ps1 pack selection logic
# Run: Invoke-Pester -Path tests/peon-packs.Tests.ps1
#
# These tests validate:
# - Get-ActivePack fallback chain (default_pack -> active_pack -> "peon")
# - session_override + path_rules interaction in pack resolution
# - path_rules fallback when session pack is missing
# - session_override fallback paths use Get-ActivePack (not raw config)

BeforeAll {
    # Use shared test harness for hook extraction (B3: DRY compliance)
    . $PSScriptRoot/windows-setup.ps1

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:InstallPs1 = Join-Path $script:RepoRoot "install.ps1"
    $script:EmbeddedHook = Extract-PeonHookScript -InstallPath $script:InstallPs1
}

# ============================================================
# Get-ActivePack fallback chain
# ============================================================

Describe "Get-ActivePack fallback chain" {
    BeforeAll {
        # Extract the Get-ActivePack function from the embedded hook
        $fnMatch = [regex]::Match($script:EmbeddedHook, '(?ms)^function Get-ActivePack\(\$config\)\s*\{.*?\n\}')
        if (-not $fnMatch.Success) { throw "Could not extract Get-ActivePack from embedded hook" }
        # Define the function in this scope
        Invoke-Expression $fnMatch.Value
    }

    It "returns default_pack when present" {
        $cfg = [pscustomobject]@{ default_pack = "glados"; active_pack = "peon" }
        Get-ActivePack $cfg | Should -Be "glados"
    }

    It "falls back to active_pack when default_pack is absent" {
        $cfg = [pscustomobject]@{ active_pack = "peasant" }
        Get-ActivePack $cfg | Should -Be "peasant"
    }

    It "falls back to 'peon' when both keys are absent" {
        $cfg = [pscustomobject]@{}
        Get-ActivePack $cfg | Should -Be "peon"
    }

    It "prefers default_pack over active_pack" {
        $cfg = [pscustomobject]@{ default_pack = "murloc"; active_pack = "peasant" }
        Get-ActivePack $cfg | Should -Be "murloc"
    }
}

# ============================================================
# session_override + path_rules interaction (static analysis)
# ============================================================

Describe "session_override + path_rules + ide_rules interaction" {
    BeforeAll {
        # Grab the pack selection block from the embedded hook (lines between
        # "# --- Pick a sound ---" and "$packDir =")
        $pickMatch = [regex]::Match(
            $script:EmbeddedHook,
            '(?ms)# --- Pick a sound ---.*?(?=\$packDir\s*=)'
        )
        if (-not $pickMatch.Success) { throw "Could not extract pack selection block" }
        $script:PackSelectionBlock = $pickMatch.Value
    }

    It "session_override mode falls through to pathRulePack then ideRulePack then defaultPack" {
        $script:PackSelectionBlock | Should -Match 'if \(\$pathRulePack\) \{ \$pathRulePack \} elseif \(\$ideRulePack\) \{ \$ideRulePack \} else \{ \$defaultPack \}'
    }

    It "path_rules evaluation runs before session_override check" {
        $pathRulesIdx = $script:PackSelectionBlock.IndexOf('# --- Path rules and IDE rules')
        $sessionIdx = $script:PackSelectionBlock.IndexOf('session_override')
        $pathRulesIdx | Should -BeLessThan $sessionIdx
        $pathRulesIdx | Should -BeGreaterOrEqual 0
    }

    It "ide_rules evaluation runs after path_rules and before rotation" {
        $pathIdx = $script:PackSelectionBlock.IndexOf('$pathRules = $config.path_rules')
        $ideIdx = $script:PackSelectionBlock.IndexOf('$ideRules = $config.ide_rules')
        $rotIdx = $script:PackSelectionBlock.IndexOf('$config.pack_rotation.Count -gt 0')
        $pathIdx | Should -BeLessThan $ideIdx
        $ideIdx | Should -BeLessThan $rotIdx
    }

    It "session pack takes priority over path_rules when session pack is valid" {
        $script:PackSelectionBlock | Should -Match '\$activePack = \$candidate'
    }

    It "falls through to path_rules then ide_rules when session pack directory is missing" {
        $script:PackSelectionBlock | Should -Match 'Pack missing, fall through hierarchy: path_rules > ide_rules > default_pack'
    }

    It "pathRulePack wins over ideRulePack rotation and default_pack when not in session_override mode" {
        $script:PackSelectionBlock | Should -Match 'elseif \(\$pathRulePack\)'
        $script:PackSelectionBlock | Should -Match 'Path rule wins over IDE rules, rotation, and default'
    }

    It "exclude_dirs can skip path_rules entirely" {
        $script:PackSelectionBlock | Should -Match '\$pathRuleExcluded = \$null'
        $script:PackSelectionBlock | Should -Match 'Test-PathRuleMatch \$cwd \$excludePattern'
        $script:PackSelectionBlock | Should -Match '-and -not \$pathRuleExcluded'
    }
}

# ============================================================
# session_override fallback uses Get-ActivePack (config parity guard)
# ============================================================

Describe "session_override fallback uses Get-ActivePack" {
    BeforeAll {
        # Extract the pack selection block from embedded hook
        $pickMatch = [regex]::Match(
            $script:EmbeddedHook,
            '(?ms)# --- Pick a sound ---.*?(?=\$packDir\s*=)'
        )
        if (-not $pickMatch.Success) { throw "Could not extract pack selection block" }
        $script:PackSelectionBlock = $pickMatch.Value
    }

    It "defaultPack is set via Get-ActivePack (not raw config.active_pack)" {
        # $defaultPack must use Get-ActivePack to respect default_pack config key
        $script:PackSelectionBlock | Should -Match '\$defaultPack = Get-ActivePack \$config'
    }

    It "session_override fallback paths use pathRulePack-or-ideRulePack-or-defaultPack pattern" {
        # Extract only the session_override block
        $soMatch = [regex]::Match(
            $script:PackSelectionBlock,
            '(?ms)if \(\$rotationMode -eq "agentskill".*?(?=\} elseif \(\$pathRulePack\))'
        )
        $soMatch.Success | Should -BeTrue -Because "session_override block should exist"
        $soBlock = $soMatch.Value

        $soBlock | Should -Match 'if \(\$pathRulePack\) \{ \$pathRulePack \} elseif \(\$ideRulePack\) \{ \$ideRulePack \} else \{ \$defaultPack \}'
    }
}

# ============================================================
# Get-ActivePack parity between installer and embedded hook
# ============================================================

Describe "Get-ActivePack parity" {
    BeforeAll {
        # Installer's Get-ActivePack is in scripts/install-utils.ps1 (extracted by augpn7)
        $utilsPath = Join-Path (Join-Path $script:RepoRoot "scripts") "install-utils.ps1"
        $utilsRaw = Get-Content $utilsPath -Raw
        $utilsMatch = [regex]::Match($utilsRaw, '(?ms)^function Get-ActivePack\(\$config\)\s*\{.*?\n\}')
        if (-not $utilsMatch.Success) { throw "Get-ActivePack not found in install-utils.ps1" }
        $script:InstallerDef = $utilsMatch.Value

        # Embedded hook's Get-ActivePack is in the here-string inside install.ps1
        $hookMatch = [regex]::Match($script:EmbeddedHook, '(?ms)^function Get-ActivePack\(\$config\)\s*\{.*?\n\}')
        if (-not $hookMatch.Success) { throw "Get-ActivePack not found in embedded hook" }
        $script:HookDef = $hookMatch.Value
    }

    It "installer and embedded hook have identical Get-ActivePack implementations" {
        $script:InstallerDef | Should -Be $script:HookDef
    }

    It "both check default_pack before active_pack" {
        # default_pack appears on a line before active_pack in the function body
        $iDef = $script:InstallerDef -replace "`r`n", " " -replace "`n", " "
        $hDef = $script:HookDef -replace "`r`n", " " -replace "`n", " "
        $iDef | Should -Match 'default_pack.*active_pack'
        $hDef | Should -Match 'default_pack.*active_pack'
    }
}

# ============================================================
# Windows functional parity for ide_rules and exclude_dirs
# ============================================================

Describe "Windows CLI + runtime parity for ide_rules and exclude_dirs" {
    BeforeEach {
        $script:Env = New-PeonTestEnvironment -ConfigOverrides @{
            default_pack = "peon"
            path_rules   = @()
            exclude_dirs = @()
            ide_rules    = @()
        }
        $script:TestDir = $script:Env.TestDir
        $script:PeonPath = $script:Env.PeonPath
        $script:WorktreesDir = Join-Path $script:TestDir "worktrees"
        $script:ProjectDir = Join-Path $script:WorktreesDir "project-a"
        New-Item -ItemType Directory -Path $script:ProjectDir -Force | Out-Null
        # Canonicalize to the long-path form. On GH Windows runners $env:TEMP
        # resolves to a short-name path (C:\Users\RUNNER~1\...). Resolve-Path
        # preserves 8.3 short names, but Set-Location + $PWD.Path expands them
        # to the long form — which is what peon.ps1 sees when the spawned shell
        # does Set-Location. Use the Set-Location round-trip so config values
        # and $PWD.Path stay in the same form.
        Push-Location -LiteralPath $script:WorktreesDir
        $script:WorktreesDir = $PWD.Path
        Pop-Location
        Push-Location -LiteralPath $script:ProjectDir
        $script:ProjectDir = $PWD.Path
        Pop-Location
    }

    AfterEach {
        if (Test-Path Env:PEON_IDE) {
            Remove-Item Env:PEON_IDE -ErrorAction SilentlyContinue
        }
        if ($script:TestDir) {
            Remove-PeonTestEnvironment -TestDir $script:TestDir
        }
    }

    It "packs ide-bind stores an ide_rules entry" {
        $result = & powershell.exe -NoProfile -Command "& '$script:PeonPath' --packs ide-bind codex sc_kerrigan 2>&1"
        ($result -join "`n") | Should -Match "bound sc_kerrigan to IDE codex"

        $cfg = Get-PeonConfig -TestDir $script:TestDir
        $cfg.ide_rules.Count | Should -Be 1
        $cfg.ide_rules[0].ide | Should -Be "codex"
        $cfg.ide_rules[0].pack | Should -Be "sc_kerrigan"
    }

    It "packs exclude add stores an exclude_dirs entry" {
        $result = & powershell.exe -NoProfile -Command "& '$script:PeonPath' --packs exclude add '$script:WorktreesDir' 2>&1"
        ($result -join "`n") | Should -Match "excluded path rule matching"

        $cfg = Get-PeonConfig -TestDir $script:TestDir
        $cfg.exclude_dirs.Count | Should -Be 1
        $cfg.exclude_dirs[0] | Should -Be $script:WorktreesDir
    }

    It "runtime uses ide_rules when source matches and no path_rule applies" {
        $cfg = Get-PeonConfig -TestDir $script:TestDir
        $cfg.ide_rules = @([pscustomobject]@{ ide = "codex"; pack = "sc_kerrigan" })
        $cfg | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:TestDir "config.json") -Encoding UTF8

        $payload = @{
            hook_event_name = "Stop"
            session_id      = "codex-session-001"
            source          = "codex"
            cwd             = (Join-Path $script:TestDir "project")
        } | ConvertTo-Json -Compress

        $result = Invoke-PeonHook -TestDir $script:TestDir -JsonPayload $payload
        $result.ExitCode | Should -Be 0
        ($result.AudioLog -join "`n") | Should -Match 'packs[\\/]sc_kerrigan[\\/]sounds'
    }

    It "runtime skips path_rules under exclude_dirs and still applies ide_rules" {
        $cfg = Get-PeonConfig -TestDir $script:TestDir
        $cfg.path_rules = @([pscustomobject]@{ pattern = $script:WorktreesDir; pack = "peon" })
        $cfg.exclude_dirs = @($script:WorktreesDir)
        $cfg.ide_rules = @([pscustomobject]@{ ide = "codex"; pack = "sc_kerrigan" })
        $cfg | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:TestDir "config.json") -Encoding UTF8

        $payload = @{
            hook_event_name = "Stop"
            session_id      = "codex-session-002"
            source          = "codex"
            cwd             = $script:ProjectDir
        } | ConvertTo-Json -Compress

        $result = Invoke-PeonHook -TestDir $script:TestDir -JsonPayload $payload
        $result.ExitCode | Should -Be 0
        ($result.AudioLog -join "`n") | Should -Match 'packs[\\/]sc_kerrigan[\\/]sounds'
    }

    It "status --verbose shows IDE rule and excluded path context" {
        $cfg = Get-PeonConfig -TestDir $script:TestDir
        $cfg.path_rules = @([pscustomobject]@{ pattern = $script:WorktreesDir; pack = "peon" })
        $cfg.exclude_dirs = @($script:WorktreesDir)
        $cfg.ide_rules = @([pscustomobject]@{ ide = "codex"; pack = "sc_kerrigan" })
        $cfg | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $script:TestDir "config.json") -Encoding UTF8

        $result = & powershell.exe -NoProfile -Command "`$env:PEON_IDE='codex'; Set-Location -LiteralPath '$script:ProjectDir'; & '$script:PeonPath' --status --verbose 2>&1"
        $output = $result -join "`n"
        $output | Should -Match "IDE source \(status\): codex"
        $output | Should -Match "path rules: 1 configured"
        $output | Should -Match "excluded paths: 1 configured"
        $output | Should -Match "active IDE rule: codex -> sc_kerrigan"
    }
}
