# Pester 5 regression test for install.ps1 hook re-registration
# Run: Invoke-Pester -Path tests/install-ps1-hook-rewrite.Tests.ps1
#
# Verifies that when install.ps1 preserves a sibling third-party hook entry
# during update, it does not turn a missing `matcher` property into a literal
# JSON `null`. Claude Code's settings validator rejects null matchers with
# "matcher: Expected string, but received null".

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:InstallPs1 = Join-Path $script:RepoRoot "install.ps1"
}

Describe "install.ps1 hook re-registration" {

    It "extracts the matcher-coalesce pattern unchanged in install.ps1" {
        # Guard against accidental removal of the fix. The coalesce is the
        # whole point of this test file, so make sure the source still has it.
        $content = Get-Content $script:InstallPs1 -Raw
        $content | Should -Match 'if \(\$null -eq \$entry\.matcher\) \{ "" \} else \{ \$entry\.matcher \}'
    }

    It "coalesces missing matcher to empty string when preserving sibling hooks" {
        # Mirror the install.ps1 production code path: read settings.json with
        # ConvertFrom-Json (yields PSCustomObject), iterate existing entries,
        # rebuild them with matcher coalesced to "" when absent.

        # Synthetic settings.json with a third-party hook (e.g. omni's broken
        # async-hook output) that has no matcher property at all.
        $settingsJson = @'
{
  "hooks": {
    "PostToolUseFailure": [
      {
        "hooks": [
          { "type": "command", "command": "third-party.exe --hook", "async": true }
        ]
      }
    ]
  }
}
'@
        $settings = $settingsJson | ConvertFrom-Json

        # Same logic as install.ps1: filter peon hooks (none here), rebuild
        # surviving entries with the coalesce.
        $rebuilt = @($settings.hooks.PostToolUseFailure | ForEach-Object {
            $entry = $_
            $keptHooks = @($entry.hooks | Where-Object {
                -not ($_.command -and ($_.command -match "peon\.(ps1|sh)" -or $_.command -match "notify\.sh"))
            })
            if ($keptHooks.Count -gt 0) {
                $matcherValue = if ($null -eq $entry.matcher) { "" } else { $entry.matcher }
                [PSCustomObject]@{
                    matcher = $matcherValue
                    hooks   = $keptHooks
                }
            }
        } | Where-Object { $_ -ne $null })

        $output = $rebuilt | ConvertTo-Json -Depth 10
        $output | Should -Not -Match '"matcher":\s*null'
        $output | Should -Match '"matcher":\s*""'
        # Sibling hook command preserved
        $output | Should -Match 'third-party\.exe --hook'
    }

    It "preserves a non-empty matcher value (e.g. 'Bash')" {
        $settingsJson = @'
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "third-party.exe --pre-hook" }
        ]
      }
    ]
  }
}
'@
        $settings = $settingsJson | ConvertFrom-Json

        $rebuilt = @($settings.hooks.PreToolUse | ForEach-Object {
            $entry = $_
            $keptHooks = @($entry.hooks | Where-Object {
                -not ($_.command -and ($_.command -match "peon\.(ps1|sh)" -or $_.command -match "notify\.sh"))
            })
            if ($keptHooks.Count -gt 0) {
                $matcherValue = if ($null -eq $entry.matcher) { "" } else { $entry.matcher }
                [PSCustomObject]@{
                    matcher = $matcherValue
                    hooks   = $keptHooks
                }
            }
        } | Where-Object { $_ -ne $null })

        $output = $rebuilt | ConvertTo-Json -Depth 10
        $output | Should -Match '"matcher":\s*"Bash"'
    }
}

Describe "install.ps1 Copilot CLI camelCase fallback" {

    It "embeds a hookName fallback for camelCase-leaky events (peon hook script)" {
        # Guard the upstream-bug shim: GitHub Copilot CLI's permissionRequest
        # event delivers camelCase fields ("hookName", "sessionId", "toolName")
        # even when registered with the PascalCase key, breaking peon's
        # detection. The hook script embedded in install.ps1 must read
        # event.hookName as a fallback when event.hook_event_name is empty.
        $content = Get-Content $script:InstallPs1 -Raw
        $content | Should -Match '\$rawEvent = \$event\.hookName'
    }

    It "registers PermissionRequest in the Copilot CLI camelCase event map" {
        $content = Get-Content $script:InstallPs1 -Raw
        $content | Should -Match '"permissionRequest" = "PermissionRequest"'
    }

    It "extracts session_id from camelCase sessionId fallback" {
        $content = Get-Content $script:InstallPs1 -Raw
        $content | Should -Match 'elseif \(\$event\.sessionId\) \{ \$event\.sessionId \}'
    }
}
