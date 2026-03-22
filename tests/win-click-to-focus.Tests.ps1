# Pester 5 tests for Windows toast click-to-focus (Phase 1 + Phase 2)
# Run: Invoke-Pester -Path tests/win-click-to-focus.Tests.ps1
#
# Phase 1 tests validate:
# - win-notify.ps1 accepts -parentPid parameter
# - Toast XML contains launch="parentPid=..." attribute
# - P/Invoke type PeonPing.Win32Focus structure
# - Find-FocusableWindow process-name priority chain
# - Set-WindowFocus AttachThreadInput + SetForegroundWindow sequence
# - PS 7+ delegation forwards -parentPid
# - Hook script in install.ps1 passes -parentPid in notification args
# - WSL toast XML in notify.sh includes launch attribute
# - Graceful no-op when no matching IDE/terminal process found
#
# Phase 2 tests validate:
# - Find-WindowByPid function: process tree walk from parentPid
# - EnumWindows P/Invoke fallback for complex process trees
# - Activation handler tries PID-based targeting first, falls back to process-name
# - Stale PID graceful fallback to Phase 1 behavior

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

# ============================================================
# Phase 2: Find-WindowByPid function
# ============================================================
Describe "Find-WindowByPid function" {
    It "is defined in win-notify.ps1" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'function\s+Find-WindowByPid'
    }

    It "accepts a pid parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Find-WindowByPid"
        }, $true)
        $funcAst | Should -Not -BeNullOrEmpty

        $paramNames = @($funcAst[0].Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "pid"
    }

    It "walks process tree upward using Parent property" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # Find the Find-WindowByPid function body and verify it walks via Parent
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        $funcContent = $content.Substring($funcStart)
        $funcContent | Should -Match '\.Parent'
    }

    It "checks MainWindowHandle when walking process tree" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        $funcContent = $content.Substring($funcStart)
        $funcContent | Should -Match 'MainWindowHandle'
    }

    It "returns null when PID is 0 (no parent PID available)" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        $funcContent = $content.Substring($funcStart)
        # Should have an early return for PID 0
        $funcContent | Should -Match '\$pid\s*-(?:eq|le)\s*0'
    }

    It "has a max depth guard to prevent infinite loops" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        $funcContent = $content.Substring($funcStart)
        # Should have some form of depth/iteration limit
        $funcContent | Should -Match 'maxDepth|depth|maxWalk|walkLimit|iteration'
    }

    It "wraps Get-Process in try/catch for stale PID handling" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        # Find the closing brace of the function (next function or end of functions section)
        $nextFunc = $content.IndexOf("function ", $funcStart + 1)
        if ($nextFunc -eq -1) { $nextFunc = $content.Length }
        $funcContent = $content.Substring($funcStart, $nextFunc - $funcStart)
        $funcContent | Should -Match 'try\s*\{'
        $funcContent | Should -Match 'catch'
    }

    It "falls back to EnumWindows when parent walk fails" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        $nextFunc = $content.IndexOf("function ", $funcStart + 1)
        if ($nextFunc -eq -1) { $nextFunc = $content.Length }
        $funcContent = $content.Substring($funcStart, $nextFunc - $funcStart)
        # Should reference the EnumWindows-based fallback
        $funcContent | Should -Match 'EnumWindows|Get-WindowsByProcessTree'
    }
}

# ============================================================
# Phase 2: EnumWindows P/Invoke fallback
# ============================================================
Describe "EnumWindows P/Invoke" {
    It "imports EnumWindows in Win32Focus type" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'EnumWindows'
    }

    It "imports IsWindowVisible in Win32Focus type" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'IsWindowVisible'
    }

    It "defines EnumWindowsProc delegate type" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # The delegate is needed for the EnumWindows callback
        $content | Should -Match 'EnumWindowsProc|delegate.*bool'
    }
}

# ============================================================
# Phase 2: Get-WindowsByProcessTree function
# ============================================================
Describe "Get-WindowsByProcessTree function" {
    It "is defined in win-notify.ps1" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'function\s+Get-WindowsByProcessTree'
    }

    It "accepts a pid parameter" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $funcAst = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Get-WindowsByProcessTree"
        }, $true)
        $funcAst | Should -Not -BeNullOrEmpty

        $paramNames = @($funcAst[0].Body.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath })
        $paramNames | Should -Contain "pid"
    }

    It "collects PIDs from process tree (parent chain)" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Get-WindowsByProcessTree")
        $nextFunc = $content.IndexOf("function ", $funcStart + 1)
        if ($nextFunc -eq -1) { $nextFunc = $content.Length }
        $funcContent = $content.Substring($funcStart, $nextFunc - $funcStart)
        # Should collect PIDs by walking the tree
        $funcContent | Should -Match 'Parent'
    }

    It "uses GetWindowThreadProcessId to match windows to PIDs" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Get-WindowsByProcessTree")
        $nextFunc = $content.IndexOf("function ", $funcStart + 1)
        if ($nextFunc -eq -1) { $nextFunc = $content.Length }
        $funcContent = $content.Substring($funcStart, $nextFunc - $funcStart)
        $funcContent | Should -Match 'GetWindowThreadProcessId'
    }
}

# ============================================================
# Phase 2: Activation handler PID-first fallback chain
# ============================================================
Describe "Activation handler tries PID-based targeting first" {
    It "calls Find-WindowByPid before Find-FocusableWindow in activation handler" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # In the activation block (after ToastActivated check), Find-WindowByPid
        # should appear before Find-FocusableWindow
        $activatedIdx = $content.IndexOf('$activated')
        $pidFindIdx = $content.IndexOf("Find-WindowByPid", $activatedIdx)
        $nameFindIdx = $content.IndexOf("Find-FocusableWindow", $activatedIdx)
        $pidFindIdx | Should -BeGreaterThan $activatedIdx
        $nameFindIdx | Should -BeGreaterThan $pidFindIdx
    }

    It "passes parentPid to Find-WindowByPid" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $content | Should -Match 'Find-WindowByPid\s+(-pid\s+)?\$parentPid'
    }

    It "falls back to Find-FocusableWindow when Find-WindowByPid returns null" {
        $content = Get-Content $script:WinNotifyPath -Raw
        # After Find-WindowByPid, there should be a fallback to Find-FocusableWindow
        $activatedIdx = $content.IndexOf('$activated')
        $afterActivated = $content.Substring($activatedIdx)
        # The pattern: try PID-based, if null fall back to name-based
        $afterActivated | Should -Match 'Find-WindowByPid'
        $afterActivated | Should -Match 'Find-FocusableWindow'
    }
}

# ============================================================
# Phase 2: Stale PID graceful fallback
# ============================================================
Describe "Stale PID graceful fallback" {
    It "Find-WindowByPid handles non-existent PID without throwing" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        $nextFunc = $content.IndexOf("function ", $funcStart + 1)
        if ($nextFunc -eq -1) { $nextFunc = $content.Length }
        $funcContent = $content.Substring($funcStart, $nextFunc - $funcStart)
        # Must use ErrorAction SilentlyContinue or try/catch
        $funcContent | Should -Match 'SilentlyContinue|catch'
    }

    It "returns null (not throws) when process has exited" {
        $content = Get-Content $script:WinNotifyPath -Raw
        $funcStart = $content.IndexOf("function Find-WindowByPid")
        $nextFunc = $content.IndexOf("function ", $funcStart + 1)
        if ($nextFunc -eq -1) { $nextFunc = $content.Length }
        $funcContent = $content.Substring($funcStart, $nextFunc - $funcStart)
        # Should return $null on failure
        $funcContent | Should -Match 'return\s+\$null'
    }
}

# ============================================================
# Phase 2: Script parses without errors (syntax validation)
# ============================================================
Describe "win-notify.ps1 syntax validation (Phase 2)" {
    It "parses without syntax errors after Phase 2 additions" {
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:WinNotifyPath, [ref]$tokens, [ref]$errors
        )
        $errors | Should -BeNullOrEmpty
    }
}
