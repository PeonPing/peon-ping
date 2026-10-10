# Native installer behavior. All downloads and files stay inside the test sandbox.
BeforeAll {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
}

Describe "OpenCode and Kilo plugin installer discovery" {
    BeforeEach {
        $SavedProfile = $env:USERPROFILE
        $SavedXdg = $env:XDG_CONFIG_HOME
        $SavedAppData = $env:LOCALAPPDATA
        # TestDrive persists across It blocks. Give each installer a fresh root.
        $Sandbox = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $env:USERPROFILE = Join-Path $Sandbox "home"
        $env:XDG_CONFIG_HOME = $null
        $env:LOCALAPPDATA = Join-Path $Sandbox "unexpected-appdata"
        New-Item -ItemType Directory -Force -Path (Join-Path $env:USERPROFILE ".openpeon\packs\peon") | Out-Null
        Mock Invoke-WebRequest {
            param($Uri, $OutFile)
            $content = "export default { id: 'fixture-plugin' }"
            if ($OutFile) {
                [System.IO.File]::WriteAllText($OutFile, $content)
            } else {
                [pscustomobject]@{ Content = $content }
            }
        }
    }

    AfterEach {
        $env:USERPROFILE = $SavedProfile
        $env:XDG_CONFIG_HOME = $SavedXdg
        $env:LOCALAPPDATA = $SavedAppData
    }

    It "OpenCode installs under .config even when LOCALAPPDATA exists" {
        & (Join-Path $RepoRoot "adapters\opencode.ps1")
        $plugin = Join-Path $env:USERPROFILE ".config\opencode\plugins\peon-ping.ts"
        $plugin | Should -Exist
        Get-Content $plugin -Raw | Should -Match "fixture-plugin"
        Test-Path (Join-Path $env:LOCALAPPDATA "opencode\plugins\peon-ping.ts") | Should -BeFalse
        # Pester owns the call history across the invoked script's scope.
        Should -Invoke Invoke-WebRequest -Exactly -Times 1 -Scope It -ParameterFilter {
            $Uri -match '^https://raw\.githubusercontent\.com/PeonPing/peon-ping/main/adapters/opencode/peon-ping-v\d+\.ts$'
        }
    }

    It "OpenCode honors XDG_CONFIG_HOME" {
        $env:XDG_CONFIG_HOME = Join-Path $Sandbox "custom-config"
        & (Join-Path $RepoRoot "adapters\opencode.ps1")
        Join-Path $env:XDG_CONFIG_HOME "opencode\plugins\peon-ping.ts" | Should -Exist
        Test-Path (Join-Path $env:USERPROFILE ".config\opencode\plugins\peon-ping.ts") | Should -BeFalse
    }

    It "Kilo downloads its dedicated v1 plugin without OpenCode text patching" {
        & (Join-Path $RepoRoot "adapters\kilo.ps1")
        $plugin = Join-Path $env:LOCALAPPDATA "kilo\plugins\peon-ping.ts"
        $plugin | Should -Exist
        (Get-Content $plugin -Raw).Trim() | Should -Be "export default { id: 'fixture-plugin' }"
        Should -Invoke Invoke-WebRequest -Exactly -Times 1 -Scope It -ParameterFilter {
            $Uri -eq "https://raw.githubusercontent.com/PeonPing/peon-ping/main/adapters/kilo/peon-ping.ts"
        }
    }
}
