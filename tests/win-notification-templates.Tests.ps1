# Pester 5 tests for Windows notification template resolution engine
# Run: Invoke-Pester -Path tests/win-notification-templates.Tests.ps1
#
# Strategy: Unit-test the template resolution logic in isolation.
# We verify that the template block in install.ps1 (embedded peon.ps1)
# correctly resolves templates given various inputs. Tests simulate the
# variables that peon.ps1 sets before the template resolution block runs,
# then execute the block and check $notifyMsg.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:InstallPs1 = Join-Path $script:RepoRoot "install.ps1"

    # Extract the template resolution block from the embedded peon.ps1
    function Get-TemplateResolutionBlock {
        $content = Get-Content $script:InstallPs1 -Raw
        # Extract between the markers
        if ($content -match '(?s)# --- Notification message template resolution ---(.+?)# --- Desktop notification dispatch ---') {
            return $Matches[1].Trim()
        }
        throw "Template resolution block not found in install.ps1"
    }

    # Build a test scriptblock that sets up variables, runs the template block,
    # and returns $notifyMsg
    function Invoke-TemplateResolution {
        param(
            [hashtable]$ConfigInput = @{},
            [string]$HookEventName = "Stop",
            [string]$CategoryName = "task.complete",
            [string]$NotificationType = "",
            [string]$ProjectName = "myproject",
            [string]$NotifyStatusVal = "done",
            [string]$NotifyMsgVal = "myproject",
            [hashtable]$EventData = @{}
        )

        $tplBlock = Get-TemplateResolutionBlock

        # Build the event properties (mimics ConvertFrom-Json output = PSCustomObject)
        $eventProps = @{}
        foreach ($key in $EventData.Keys) {
            $eventProps[$key] = $EventData[$key]
        }
        if ($NotificationType) {
            $eventProps["notification_type"] = $NotificationType
        }

        # Write config and event JSON to temp files to avoid quoting issues
        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "peon-tpl-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
        try {
            $configPath = Join-Path $tmpDir "config.json"
            $eventPath = Join-Path $tmpDir "event.json"
            $ConfigInput | ConvertTo-Json -Depth 5 | Set-Content -Path $configPath -Encoding UTF8
            $eventProps | ConvertTo-Json -Depth 5 | Set-Content -Path $eventPath -Encoding UTF8

            # Set up variables matching what peon.ps1 has at template resolution time
            # Variable names must match exactly what the template block uses
            $notify = $true
            $hookEvent = $HookEventName
            $category = $CategoryName
            $ntype = $NotificationType
            $project = $ProjectName
            $notifyStatus = $NotifyStatusVal
            $notifyMsg = $NotifyMsgVal
            $config = Get-Content $configPath -Raw | ConvertFrom-Json
            $event = Get-Content $eventPath -Raw | ConvertFrom-Json

            # Execute the template resolution block
            Invoke-Expression $tplBlock

            return $notifyMsg
        } finally {
            Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# Verify template block exists in install.ps1
# ============================================================

Describe "Template Block Presence" {
    It "install.ps1 contains the template resolution block" {
        $content = Get-Content $script:InstallPs1 -Raw
        $content | Should -Match 'Notification message template resolution'
        $content | Should -Match 'tplKeyMap'
    }

    It "template block is syntactically valid PowerShell" {
        { Get-TemplateResolutionBlock } | Should -Not -Throw
        $block = Get-TemplateResolutionBlock
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($block, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

# ============================================================
# Template Resolution Tests
# ============================================================

Describe "Template Resolution: Stop with {summary}" {
    It "includes project and transcript_summary in notification body" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                stop = "{project}: {summary}"
            }
        } -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "myapp" -NotifyMsgVal "myapp" -EventData @{
            transcript_summary = "Fixed the login bug and added tests"
        }
        $result | Should -Be "myapp: Fixed the login bug and added tests"
    }
}

Describe "Template Resolution: Stop without transcript_summary" {
    It "resolves {summary} to empty string when transcript_summary is missing" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                stop = "{project}: {summary}"
            }
        } -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "myapp" -NotifyMsgVal "myapp"
        $result | Should -Be "myapp: "
    }
}

Describe "Template Resolution: PermissionRequest with {tool_name}" {
    It "includes tool_name in notification body" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                permission = "{project} needs {tool_name}"
            }
        } -HookEventName "PermissionRequest" -CategoryName "input.required" -ProjectName "myapp" -NotifyMsgVal "myapp" -NotifyStatusVal "needs approval" -EventData @{
            tool_name = "Bash"
        }
        $result | Should -Be "myapp needs Bash"
    }
}

Describe "Template Resolution: No template configured" {
    It "falls back to original notifyMsg when no notification_templates" {
        $result = Invoke-TemplateResolution -ConfigInput @{} -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "myapp" -NotifyMsgVal "myapp"
        $result | Should -Be "myapp"
    }
}

Describe "Template Resolution: Unknown variable" {
    It "renders unknown {variables} as empty string" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                stop = "{project} {nonexistent} done"
            }
        } -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "myapp" -NotifyMsgVal "myapp"
        $result | Should -Be "myapp  done"
    }
}

Describe "Template Resolution: All five template keys" {
    It "maps Stop (task.complete) -> stop template key" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{ stop = "STOP:{project}" }
        } -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "proj" -NotifyMsgVal "proj"
        $result | Should -Be "STOP:proj"
    }

    It "maps PermissionRequest -> permission template key (overrides category)" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{ permission = "PERM:{project}" }
        } -HookEventName "PermissionRequest" -CategoryName "input.required" -ProjectName "proj" -NotifyMsgVal "proj"
        $result | Should -Be "PERM:proj"
    }

    It "maps task.error -> error template key" {
        $content = Get-Content $script:InstallPs1 -Raw
        $content | Should -Match "'task\.error'\s*=\s*'error'"
    }

    It "maps idle_prompt Notification -> idle template key" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{ idle = "IDLE:{project}" }
        } -HookEventName "Notification" -CategoryName $null -NotificationType "idle_prompt" -ProjectName "proj" -NotifyMsgVal "proj"
        $result | Should -Be "IDLE:proj"
    }

    It "maps elicitation_dialog Notification -> question template key" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{ question = "Q:{project}" }
        } -HookEventName "Notification" -CategoryName "input.required" -NotificationType "elicitation_dialog" -ProjectName "proj" -NotifyMsgVal "proj"
        $result | Should -Be "Q:proj"
    }
}

Describe "Template Resolution: Summary truncation" {
    It "truncates transcript_summary to 120 characters" {
        $longSummary = "A" * 200
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                stop = "{summary}"
            }
        } -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "proj" -NotifyMsgVal "proj" -EventData @{
            transcript_summary = $longSummary
        }
        $result.Length | Should -Be 120
        $result | Should -Be ("A" * 120)
    }
}

Describe "Template Resolution: Special characters" {
    It "handles dots and hyphens in project name and spaces in tool_name" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                permission = "{project} wants {tool_name}"
            }
        } -HookEventName "PermissionRequest" -CategoryName "input.required" -ProjectName "my-app.v2" -NotifyMsgVal "my-app.v2" -EventData @{
            tool_name = "Read File"
        }
        $result | Should -Be "my-app.v2 wants Read File"
    }
}

Describe "Template Resolution: Variable substitution completeness" {
    It "resolves {status} variable" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                stop = "{status}"
            }
        } -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "proj" -NotifyMsgVal "proj" -NotifyStatusVal "done"
        $result | Should -Be "done"
    }

    It "resolves {event} variable" {
        $result = Invoke-TemplateResolution -ConfigInput @{
            notification_templates = @{
                stop = "{event}"
            }
        } -HookEventName "Stop" -CategoryName "task.complete" -ProjectName "proj" -NotifyMsgVal "proj"
        $result | Should -Be "Stop"
    }
}
