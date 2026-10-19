# Run with Invoke-Pester -Path tests/codex-config.Tests.ps1.
# Execute the real Codex registration/removal sections with isolated paths.
BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    function Get-ProductionSection([string]$File, [string]$Start, [string]$End) {
        $source = [System.IO.File]::ReadAllText((Join-Path $script:RepoRoot $File))
        $first = $source.IndexOf($Start)
        $last = $source.IndexOf($End, $first + $Start.Length)
        if ($first -lt 0 -or $last -lt 0) { throw "Cannot locate production section in $File" }
        return [scriptblock]::Create($source.Substring($first, $last - $first))
    }
    $script:InstallCodexHelper = Get-ProductionSection 'install.ps1' '# --- Install Codex configuration helper ---' '# --- Install the main hook script (PowerShell) ---'
    $script:InstallCodex = Get-ProductionSection 'install.ps1' '# --- Register OpenAI Codex' '# --- Auto-detect deepagents-cli'
    $script:UninstallCodex = Get-ProductionSection 'uninstall.ps1' '# --- Remove OpenAI Codex hooks ---' '# --- Remove skills ---'
    . (Join-Path $script:RepoRoot 'scripts/install-utils.ps1')
    function Invoke-CodexInstall {
        $Local = $false
        $InstallDir = $script:InstallRoot
        $ScriptDir = $script:RepoRoot
        $RepoBase = 'https://example.invalid/never-used'
        & $script:InstallCodexHelper
        & $script:InstallCodex
    }
    function Invoke-CodexUninstall {
        $InstallDir = $script:InstallRoot
        $PSScriptRoot = $script:InstallRoot
        & $script:UninstallCodex
    }
    function Save-Json([string]$Path, $Value) {
        [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding $false))
    }
    function Read-Hooks { Get-Content -LiteralPath $script:HooksFile -Raw | ConvertFrom-Json }
    function Own-Command([string]$Root) { 'powershell -NoProfile -File "' + (Join-Path $Root 'adapters/codex.ps1') + '"' }
}

Describe 'Native Windows Codex configuration representation' {
    BeforeEach {
        $script:SavedProfile = $env:USERPROFILE
        $script:SavedCodexHome = $env:CODEX_HOME
        $caseRoot = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $env:USERPROFILE = Join-Path $caseRoot 'profile'
        $env:CODEX_HOME = Join-Path $caseRoot 'codex-custom'
        $script:InstallRoot = Join-Path $caseRoot 'peon-ping'
        $script:OtherRoot = Join-Path $caseRoot 'peon-ping-other'
        $script:HooksFile = Join-Path $env:CODEX_HOME 'hooks.json'
        $script:ConfigFile = Join-Path $env:CODEX_HOME 'config.toml'
        New-Item -ItemType Directory -Path $env:CODEX_HOME, (Join-Path $env:USERPROFILE '.codex'), (Join-Path $script:InstallRoot 'scripts') -Force | Out-Null
        Save-Json $script:HooksFile ([ordered]@{ version = 1; userMetadata = @{ keep = 'root' }; hooks = @{} })
    }
    AfterEach {
        $env:USERPROFILE = $script:SavedProfile
        $env:CODEX_HOME = $script:SavedCodexHome
    }

    It 'reuses CODEX_HOME JSON, preserves metadata and registers native commands once' {
        Save-Json $script:HooksFile ([ordered]@{
            version = 1; userMetadata = @{ keep = 'root' }
            hooks = @{ Stop = @(@{ matcher = 'custom'; extra = @{ keep = 'group' }; hooks = @(@{ type = 'command'; command = 'echo user'; extra = 'handler' }) }) }
        })
        Invoke-CodexInstall
        $first = Get-Content -LiteralPath $script:HooksFile -Raw
        Invoke-CodexInstall
        (Get-Content -LiteralPath $script:HooksFile -Raw) | Should -Be $first
        $doc = Read-Hooks
        $doc.userMetadata.keep | Should -Be 'root'
        $doc.hooks.Stop[0].extra.keep | Should -Be 'group'
        $doc.hooks.Stop[0].hooks[0].extra | Should -Be 'handler'
        @($doc.hooks.PSObject.Properties.Name).Count | Should -Be 7
        @($doc.hooks.Stop).Count | Should -Be 2
        $doc.hooks.Stop[1].hooks[0].command | Should -Match '^powershell -NoProfile -NonInteractive '
        $doc.hooks.SessionStart[0].matcher | Should -Be 'startup|resume|clear'
        $doc.hooks.PreCompact[0].matcher | Should -Be 'manual|auto'
        Test-Path -LiteralPath $script:ConfigFile | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.codex/config.toml') | Should -BeFalse
        Test-Path -LiteralPath (Join-Path $script:InstallRoot 'scripts/codex-hooks.ps1') | Should -BeTrue
    }

    It 'replaces only this installation handlers while retaining sibling installations' {
        Save-Json $script:HooksFile @{ hooks = @{ Stop = @(@{ matcher = 'all'; extra = 'retained'; hooks = @(
            @{ type = 'command'; command = (Own-Command $script:InstallRoot) },
            @{ type = 'command'; commandWindows = (Own-Command $script:OtherRoot) },
            @{ type = 'command'; command = 'echo user' }
        ) }) } }
        Invoke-CodexInstall
        $doc = Read-Hooks
        $doc.hooks.Stop[0].extra | Should -Be 'retained'
        @($doc.hooks.Stop[0].hooks).Count | Should -Be 2
        $doc.hooks.Stop[0].hooks[0].commandWindows | Should -Be (Own-Command $script:OtherRoot)
        $doc.hooks.Stop[0].hooks[1].command | Should -Be 'echo user'
        @($doc.hooks.Stop).Count | Should -Be 2
    }

    It 'removes JSON-only hooks without creating TOML and retains metadata and other installs' {
        Save-Json $script:HooksFile @{ version = 1; hooks = @{ Stop = @(@{ matcher = 'all'; extra = 'retained'; hooks = @(
            @{ type = 'command'; command_windows = (Own-Command $script:InstallRoot) },
            @{ type = 'command'; command = (Own-Command $script:OtherRoot) }
        ) }) } }
        # A packaged uninstaller reads its installed helper.
        if (Test-Path (Join-Path $script:RepoRoot 'scripts/codex-hooks.ps1')) { Copy-Item (Join-Path $script:RepoRoot 'scripts/codex-hooks.ps1') (Join-Path $script:InstallRoot 'scripts/codex-hooks.ps1') }
        Invoke-CodexUninstall
        $doc = Read-Hooks
        $doc.version | Should -Be 1
        $doc.hooks.Stop[0].extra | Should -Be 'retained'
        @($doc.hooks.Stop[0].hooks).Count | Should -Be 1
        $doc.hooks.Stop[0].hooks[0].command | Should -Be (Own-Command $script:OtherRoot)
        Test-Path -LiteralPath $script:ConfigFile | Should -BeFalse
    }

    It 'cleans its legacy TOML hooks before selecting existing JSON' {
        $adapter = (Join-Path $script:InstallRoot 'adapters/codex.ps1').Replace('\', '\\')
        [System.IO.File]::WriteAllText($script:ConfigFile, "model = 'keep'`n[[hooks.Stop]]`n[[hooks.Stop.hooks]]`ntype = 'command'`ncommand = 'powershell -File $adapter'`n")
        Invoke-CodexInstall
        (Get-Content -LiteralPath $script:ConfigFile -Raw).Trim() | Should -Be "model = 'keep'"
        (Read-Hooks).hooks.Stop[0].hooks[0].command | Should -Match '^powershell '
    }

    It 'refuses unrelated mixed representations before changing either file' {
        $toml = "model = 'keep'`n[[hooks.Stop]]`n[[hooks.Stop.hooks]]`ntype = 'command'`ncommand = 'echo user'`n"
        [System.IO.File]::WriteAllText($script:ConfigFile, $toml)
        $json = Get-Content -LiteralPath $script:HooksFile -Raw
        { Invoke-CodexInstall } | Should -Throw '*consolidate*'
        Get-Content -LiteralPath $script:ConfigFile -Raw | Should -Be $toml
        Get-Content -LiteralPath $script:HooksFile -Raw | Should -Be $json
    }

    It 'refuses mixed JSON and <Form> TOML hook keys without writes' -ForEach @(
        @{ Form = 'literal triple quote value'; Toml = "example = '" + '"""' + "'`n[[hooks.Stop]]`n[[hooks.Stop.hooks]]`ntype = 'command'`ncommand = 'echo external'" },
        @{ Form = 'inline comment triple quote'; Toml = 'model = "test" # """' + "`n[[hooks.Stop]]`n[[hooks.Stop.hooks]]`ntype = 'command'`ncommand = 'echo external'" },
        @{ Form = 'quoted tables'; Toml = '[[' + '"hooks".Stop]]' + "`n" + '[[' + '"hooks".Stop.hooks]]' + "`n" + 'type = "command"' + "`n" + 'command = "echo external"' },
        @{ Form = 'dotted root'; Toml = 'hooks.Stop = [{hooks=[{type="command",command="echo external"}]}]' },
        @{ Form = 'escaped table'; Toml = '[["h\u006foks".Stop]]' + "`n" + '[["h\u006foks".Stop.hooks]]' + "`n" + 'type = "command"' + "`n" + 'command = "echo external"' },
        @{ Form = 'escaped dotted root'; Toml = '"h\u006foks".Stop = [{hooks=[{type="command",command="echo external"}]}]' },
        @{ Form = 'UTF32 dotted root'; Toml = '"h\U0000006foks".Stop = [{hooks=[{type="command",command="echo external"}]}]' },
        @{ Form = 'spaced quoted dotted root'; Toml = '"hooks" . "Stop" = [{hooks=[{type="command",command="echo external"}]}]' }
    ) {
        [System.IO.File]::WriteAllText($script:ConfigFile, $Toml)
        $json = Get-Content -LiteralPath $script:HooksFile -Raw
        { Invoke-CodexInstall } | Should -Throw '*consolidate*'
        Get-Content -LiteralPath $script:ConfigFile -Raw | Should -Be $Toml
        Get-Content -LiteralPath $script:HooksFile -Raw | Should -Be $json
    }

    It 'refuses malformed JSON on <Action> without changing TOML or JSON' -ForEach @(@{ Action = 'install' }, @{ Action = 'uninstall' }) {
        [System.IO.File]::WriteAllText($script:ConfigFile, "model = 'keep'`n")
        [System.IO.File]::WriteAllText($script:HooksFile, '{ broken')
        if ($Action -eq 'uninstall') {
            if (Test-Path (Join-Path $script:RepoRoot 'scripts/codex-hooks.ps1')) { Copy-Item (Join-Path $script:RepoRoot 'scripts/codex-hooks.ps1') (Join-Path $script:InstallRoot 'scripts/codex-hooks.ps1') }
        }
        $toml = Get-Content -LiteralPath $script:ConfigFile -Raw
        { if ($Action -eq 'install') { Invoke-CodexInstall } else { Invoke-CodexUninstall } } | Should -Throw '*hooks.json*'
        Get-Content -LiteralPath $script:ConfigFile -Raw | Should -Be $toml
        Get-Content -LiteralPath $script:HooksFile -Raw | Should -Be '{ broken'
    }

    It 'rejects structurally invalid JSON rather than discarding user data' {
        Save-Json $script:HooksFile @{ hooks = @{ Stop = @(@{ hooks = 'not-an-array' }) }; keep = 'data' }
        $json = Get-Content -LiteralPath $script:HooksFile -Raw
        { Invoke-CodexInstall } | Should -Throw '*hooks.json*'
        Get-Content -LiteralPath $script:HooksFile -Raw | Should -Be $json
        Test-Path -LiteralPath $script:ConfigFile | Should -BeFalse
    }

    It 'keeps the existing TOML path when hooks.json is absent' {
        Remove-Item -LiteralPath $script:HooksFile
        [System.IO.File]::WriteAllText($script:ConfigFile, "model = 'keep'`n")
        Invoke-CodexInstall
        Invoke-CodexInstall
        $content = Get-Content -LiteralPath $script:ConfigFile -Raw
        $content | Should -Match "model = 'keep'"
        ([regex]::Matches($content, '\[\[hooks.Stop\]\]')).Count | Should -Be 1
        $content | Should -Match 'command_windows = "powershell '
        Test-Path -LiteralPath $script:HooksFile | Should -BeFalse
    }
    It 'uses the default Codex home when CODEX_HOME is unset' {
        $env:CODEX_HOME = $null
        $script:HooksFile = Join-Path $env:USERPROFILE '.codex/hooks.json'
        Save-Json $script:HooksFile @{ hooks = @{}; keep = 'default-home' }
        Invoke-CodexInstall
        (Read-Hooks).keep | Should -Be 'default-home'
        @((Read-Hooks).hooks.PSObject.Properties.Name).Count | Should -Be 7
        Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.codex/config.toml') | Should -BeFalse
    }

    It 'preserves TOML trust state and multiline hook examples beside JSON' {
        $toml = @'
model = 'keep'
example = """
[[hooks.Stop]]
command = "echo documentation"
"""
[features]
hooks = true
["h\u006foks"."st\u0061te".saved]
enabled = true
trusted_hash = "keep"
'@
        [System.IO.File]::WriteAllText($script:ConfigFile, $toml)
        Invoke-CodexInstall
        Get-Content -LiteralPath $script:ConfigFile -Raw | Should -Be $toml
        @((Read-Hooks).hooks.PSObject.Properties.Name).Count | Should -Be 7
    }

    It 'preserves escaped multiline quote markers containing hook table text' {
        $toml = @'
model = 'keep'
example = """
escaped quotes: \"""
[["hooks".Stop]]
[["hooks".Stop.hooks]]
"""
'@
        [System.IO.File]::WriteAllText($script:ConfigFile, $toml)
        Invoke-CodexInstall
        Get-Content -LiteralPath $script:ConfigFile -Raw | Should -Be $toml
        @((Read-Hooks).hooks.PSObject.Properties.Name).Count | Should -Be 7
    }

    It 'preserves <Form> hooks.state-only root keys beside JSON' -ForEach @(
        @{ Form = 'dotted'; Toml = 'hooks.state.saved = {enabled = true, trusted_hash = "keep"}' },
        @{ Form = 'escaped dotted'; Toml = '"h\u006foks"."st\u0061te".saved = {enabled = true, trusted_hash = "keep"}' }
    ) {
        [System.IO.File]::WriteAllText($script:ConfigFile, $Toml)
        Invoke-CodexInstall
        Get-Content -LiteralPath $script:ConfigFile -Raw | Should -Be $Toml
        @((Read-Hooks).hooks.PSObject.Properties.Name).Count | Should -Be 7
    }

    It 'preserves peon-looking notify examples inside multiline TOML on <Action>' -ForEach @(@{ Action = 'install' }, @{ Action = 'uninstall' }) {
        $example = 'notify = ["powershell", "' + (Join-Path $script:InstallRoot 'adapters/codex.ps1') + '"]'
        $toml = "example = '''`n$example`n'''`n"
        [System.IO.File]::WriteAllText($script:ConfigFile, $toml)
        if ($Action -eq 'install') { Invoke-CodexInstall }
        else {
            Copy-Item (Join-Path $script:RepoRoot 'scripts/codex-hooks.ps1') (Join-Path $script:InstallRoot 'scripts/codex-hooks.ps1')
            Invoke-CodexUninstall
        }
        Get-Content -LiteralPath $script:ConfigFile -Raw | Should -Be $toml
    }

}
