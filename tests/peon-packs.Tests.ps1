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

Describe "session_override + path_rules interaction" {
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

    It "session_override mode falls through to pathRulePack when no session assignment exists" {
        # When rotationMode is session_override and session has no pack,
        # the code should check $pathRulePack before $defaultPack
        $script:PackSelectionBlock | Should -Match 'if \(\$pathRulePack\) \{ \$pathRulePack \} else \{ \$defaultPack \}'
    }

    It "path_rules evaluation runs before session_override check" {
        # Path rules block appears before the session_override conditional
        $pathRulesIdx = $script:PackSelectionBlock.IndexOf('# --- Path rules')
        $sessionIdx = $script:PackSelectionBlock.IndexOf('session_override')
        $pathRulesIdx | Should -BeLessThan $sessionIdx
        $pathRulesIdx | Should -BeGreaterOrEqual 0
    }

    It "session pack takes priority over path_rules when session pack is valid" {
        # When session pack exists and directory is valid, $activePack = $candidate
        # (not pathRulePack). The session assignment block sets $activePack directly.
        $script:PackSelectionBlock | Should -Match '\$activePack = \$candidate'
    }

    It "falls through to path_rules when session pack directory is missing" {
        # When session pack candidate directory doesn't exist, code removes
        # the session entry and falls through to pathRulePack or default
        $script:PackSelectionBlock | Should -Match 'Pack missing, fall through hierarchy: path_rules > default_pack'
    }

    It "pathRulePack wins over rotation and default_pack when not in session_override mode" {
        $script:PackSelectionBlock | Should -Match 'elseif \(\$pathRulePack\)'
        $script:PackSelectionBlock | Should -Match 'Path rule wins over rotation and default'
    }
}

# ============================================================
# session_override fallback uses $defaultPack (config parity guard)
# ============================================================

Describe "session_override fallback uses defaultPack" {
    BeforeAll {
        # Extract the session_override block from embedded hook
        $pickMatch = [regex]::Match(
            $script:EmbeddedHook,
            '(?ms)# --- Pick a sound ---.*?(?=\$packDir\s*=)'
        )
        if (-not $pickMatch.Success) { throw "Could not extract pack selection block" }
        $script:PackSelectionBlock = $pickMatch.Value
    }

    It "session_override fallback paths use pathRulePack-or-defaultPack pattern" {
        # Extract only the session_override block
        $soMatch = [regex]::Match(
            $script:PackSelectionBlock,
            '(?ms)if \(\$rotationMode -eq "agentskill".*?(?=\} elseif \(\$pathRulePack\))'
        )
        $soMatch.Success | Should -BeTrue -Because "session_override block should exist"
        $soBlock = $soMatch.Value

        # All fallback paths should use the pathRulePack-or-defaultPack ternary
        $soBlock | Should -Match 'if \(\$pathRulePack\) \{ \$pathRulePack \} else \{ \$defaultPack \}'
    }
}

# ============================================================
# Get-ActivePack parity between installer and embedded hook
# ============================================================

Describe "Get-ActivePack parity" {
    BeforeAll {
        $raw = Get-Content $script:InstallPs1 -Raw
        # Extract both Get-ActivePack definitions
        $matches = [regex]::Matches($raw, '(?ms)^function Get-ActivePack\(\$config\)\s*\{.*?\n\}')
        if ($matches.Count -lt 2) { throw "Expected 2 Get-ActivePack definitions, found $($matches.Count)" }
        $script:InstallerDef = $matches[0].Value
        $script:HookDef = $matches[1].Value
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
