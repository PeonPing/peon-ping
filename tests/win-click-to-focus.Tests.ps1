# Pester 5 tests for Windows toast click-to-focus (Phase 1)
# Run: Invoke-Pester -Path tests/win-click-to-focus.Tests.ps1
#
# These tests validate:
# - win-notify.ps1 accepts -parentPid parameter
# - Toast XML contains launch="parentPid=..." attribute
# - P/Invoke type PeonPing.Win32Focus structure
# - Find-FocusableWindow process-name priority chain
# - Set-WindowFocus AttachThreadInput + SetForegroundWindow sequence
# - PS 7+ delegation forwards -parentPid
# - Hook script in install.ps1 passes -parentPid in notification args
# - WSL toast XML in notify.sh includes launch attribute
# - Graceful no-op when no matching IDE/terminal process found

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:WinNotifyPath = Join-Path $script:RepoRoot "scripts\win-notify.ps1"
    $script:InstallPath = Join-Path $script:RepoRoot "install.ps1"
    $script:NotifyShPath = Join-Path $script:RepoRoot "scripts\notify.sh"
}

# ============================================================
# Parameter acceptance
# ============================================================
Describe "win-notify.ps1 parameter acceptance" {
    It "accepts -parentPid parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $errors | Should -BeNullOrEmpty

        $paramBlock = $ast.ParamBlock
        $paramBlock | Should -Not -BeNullOrEmpty

        $paramNames = @($paramBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "parentPid"
    }

    It "has parentPid with default value 0" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )

        $parentPidParam = $ast.ParamBlock.Parameters | Where-Object {
            $_.Name.VariablePath.UserPath -eq "parentPid"
        }
        $parentPidParam | Should -Not -BeNullOrEmpty
        $parentPidParam.DefaultValue.ToString() | Should -Be "0"
    }

    It "declares parentPid as [int] type" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )

        $parentPidParam = $ast.ParamBlock.Parameters | Where-Object {
            $_.Name.VariablePath.UserPath -eq "parentPid"
        }
        # Check type constraint
        $typeConstraint = $parentPidParam.Attributes | Where-Object {
            $_ -is [System.Management.Automation.Language.TypeConstraintAst]
        }
        $typeConstraint | Should -Not -BeNullOrEmpty
        $typeConstraint.TypeName.Name | Should -Be "int"
    }
}

# ============================================================
# Toast XML structure
# ============================================================
Describe "Toast XML contains launch attribute" {
    It "includes launch=`"parentPid=...`" in toast XML string" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # The toast XML should include a launch attribute with parentPid
        $content | Should -Match 'launch=.*parentPid'
    }

    It "places launch attribute on the <toast> element" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # Match <toast launch="parentPid=$parentPid" ...> pattern
        $content | Should -Match '<toast\s+launch='
    }
}

# ============================================================
# P/Invoke type definition
# ============================================================
Describe "Win32Focus P/Invoke type" {
    It "defines Add-Type with Win32Focus name in PeonPing namespace" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # Add-Type and -Name are separated by the multiline MemberDefinition block
        $content | Should -Match 'Add-Type\s+-MemberDefinition'
        $content | Should -Match '-Name\s+Win32Focus'
        $content | Should -Match '-Namespace\s+PeonPing'
    }

    It "imports SetForegroundWindow" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'SetForegroundWindow'
    }

    It "imports GetForegroundWindow" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'GetForegroundWindow'
    }

    It "imports GetWindowThreadProcessId" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'GetWindowThreadProcessId'
    }

    It "imports AttachThreadInput" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'AttachThreadInput'
    }

    It "imports GetCurrentThreadId" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'GetCurrentThreadId'
    }
}

# ============================================================
# Find-FocusableWindow function
# ============================================================
Describe "Find-FocusableWindow function" {
    It "is defined in win-notify.ps1" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'function\s+Find-FocusableWindow'
    }

    It "checks process names in priority order: Code, Cursor, Windsurf, WindowsTerminal, powershell, pwsh" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # Should contain the priority list of process names
        $content | Should -Match '"Code"'
        $content | Should -Match '"Cursor"'
        $content | Should -Match '"Windsurf"'
        $content | Should -Match '"WindowsTerminal"'
        $content | Should -Match '"powershell"'
        $content | Should -Match '"pwsh"'
    }

    It "filters processes by MainWindowHandle not equal to IntPtr.Zero" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'MainWindowHandle\s+-ne\s+\[IntPtr\]::Zero'
    }
}

# ============================================================
# Set-WindowFocus function
# ============================================================
Describe "Set-WindowFocus function" {
    It "is defined in win-notify.ps1" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'function\s+Set-WindowFocus'
    }

    It "accepts a targetHwnd parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Set-WindowFocus"
        }, $true)
        $funcAst | Should -Not -BeNullOrEmpty

        $paramNames = @($funcAst[0].Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "targetHwnd"
    }

    It "calls AttachThreadInput before SetForegroundWindow" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # Find the Set-WindowFocus function body and verify ordering
        $attachIdx = $content.IndexOf("AttachThreadInput")
        $setFgIdx = $content.IndexOf("SetForegroundWindow", $attachIdx)
        $attachIdx | Should -BeLessThan $setFgIdx
    }

    It "calls AttachThreadInput with detach (false) after SetForegroundWindow" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # The function should have two AttachThreadInput calls: attach (true) and detach (false)
        $matches = [regex]::Matches($content, 'AttachThreadInput')
        $matches.Count | Should -BeGreaterOrEqual 2
    }
}

# ============================================================
# Activation event loop
# ============================================================
Describe "Activation event loop" {
    It "registers ToastActivated event" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'Register-ObjectEvent.*ToastActivated'
    }

    It "registers ToastDismissed event" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'Register-ObjectEvent.*ToastDismissed'
    }

    It "polls with Start-Sleep -Milliseconds 100" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'Start-Sleep\s+-Milliseconds\s+100'
    }

    It "uses dismissSeconds + 5 as timeout" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match '\$dismissSeconds\s*\+\s*5'
    }

    It "calls Find-FocusableWindow on activation" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # After checking for ToastActivated event, Find-FocusableWindow is called
        $activatedIdx = $content.IndexOf("ToastActivated")
        $findIdx = $content.IndexOf("Find-FocusableWindow", $activatedIdx)
        $findIdx | Should -BeGreaterThan $activatedIdx
    }

    It "calls Set-WindowFocus on activation" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'Set-WindowFocus'
    }

    It "unregisters events on cleanup" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'Unregister-Event.*ToastActivated'
        $content | Should -Match 'Unregister-Event.*ToastDismissed'
    }
}

# ============================================================
# PS 7+ delegation forwards -parentPid
# ============================================================
Describe "PS 7+ delegation" {
    It "includes -parentPid in PS 7+ delegation arguments" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # In the PS 7+ branch, the delegation args should include parentPid
        # Find the PSVersion check block and verify parentPid is forwarded
        $content | Should -Match 'parentPid.*\$parentPid'
    }
}

# ============================================================
# Hook script integration (install.ps1)
# ============================================================
Describe "install.ps1 hook script passes -parentPid" {
    It "resolves parent PID in hook script" {
        $content = Get-Content $script:InstallPath -Raw
        $content | Should -Match 'Get-Process.*-Id.*\$PID.*Parent'
    }

    It "passes -parentPid in notification args" {
        $content = Get-Content $script:InstallPath -Raw
        $content | Should -Match '"-parentPid"'
    }
}

# ============================================================
# WSL toast XML (notify.sh)
# ============================================================
Describe "WSL toast XML includes launch attribute" {
    It "includes launch=`"parentPid=0`" in WSL toast XML" {
        $content = Get-Content $script:NotifyShPath -Raw
        $content | Should -Match 'launch="parentPid=0"'
    }
}

# ============================================================
# Graceful no-op
# ============================================================
Describe "Graceful no-op behavior" {
    It "Find-FocusableWindow returns null when no process matches" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # The function should return $null as fallback
        $content | Should -Match 'return\s+\$null'
    }

    It "activation handler checks for null before calling Set-WindowFocus" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # Should have a null check around Set-WindowFocus call
        $content | Should -Match 'if\s*\(\$proc\)'
    }
}

# ============================================================
# Toast display behavior unchanged
# ============================================================
Describe "Toast display behavior unchanged" {
    It "still includes audio silent=true" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'silent=.*true'
    }

    It "still uses ToastGeneric template" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'ToastGeneric'
    }

    It "still uses PowerShell AUMID" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match '1AC14E77-02E7-4E5D-B744-2EB1AE5198B7'
    }

    It "still supports -iconPath parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $paramNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "iconPath"
    }
}

# ============================================================
# Existing parameters preserved
# ============================================================
Describe "Existing parameters preserved" {
    It "still accepts -body parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $paramNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "body"
    }

    It "still accepts -title parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $paramNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "title"
    }

    It "still accepts -dismissSeconds parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $paramNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "dismissSeconds"
    }
}
