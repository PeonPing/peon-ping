# Windows Notification Template Resolution Engine

**Date**: 2026-03-24
**Card**: kr62ia
**Status**: Implementation

## Overview

Port the notification template resolution logic from `peon.sh` (Python block, lines 3698-3723) to PowerShell in `peon.ps1` (embedded in `install.ps1`). This achieves feature parity for Windows users.

## Unix Reference Implementation (peon.sh:3698-3723)

The Python block:
1. Maps categories to template keys: `task.complete` -> `stop`, `task.error` -> `error`
2. Applies event-specific overrides: `PermissionRequest` -> `permission`, `idle_prompt` -> `idle`, `elicitation_dialog` -> `question`
3. Looks up template string from `config.notification_templates[key]`
4. Substitutes variables using `format_map()` with a `defaultdict(str)` (unknown vars -> empty string)
5. Truncates `transcript_summary` to 120 chars

## PowerShell Implementation

### Insertion Point

After the sound-picking block closes (`} # end if (-not $skipSound)` at ~line 1342) and before the desktop notification dispatch section (~line 1344). This ensures `$notifyMsg` is overwritten with the resolved template before it reaches `win-notify.ps1`.

### Template Key Mapping

```powershell
$tplKeyMap = @{ 'task.complete' = 'stop'; 'task.error' = 'error' }
$tplKey = if ($category -and $tplKeyMap.ContainsKey($category)) { $tplKeyMap[$category] } else { $null }
# Event-specific overrides
if ($hookEvent -eq 'PermissionRequest') { $tplKey = 'permission' }
if ($ntype -eq 'idle_prompt') { $tplKey = 'idle' }
if ($ntype -eq 'elicitation_dialog') { $tplKey = 'question' }
```

### Variable Substitution

Uses `[regex]::Replace` with a ScriptBlock evaluator (available since PS 2.0):

```powershell
$tplVars = @{
    project   = $project
    summary   = ($summaryRaw).Substring(0, [Math]::Min($summaryRaw.Length, 120))
    tool_name = ($event.tool_name -as [string])
    status    = $notifyStatus
    event     = $hookEvent
}
$notifyMsg = [regex]::Replace($tpl, '\{(\w+)\}', {
    param($m)
    $key = $m.Groups[1].Value
    if ($tplVars.ContainsKey($key)) { $tplVars[$key] } else { "" }
})
```

### Fallback Behavior

- Missing or empty `notification_templates` config: `$notifyMsg` retains its original value (project name)
- Missing template key: no substitution, original `$notifyMsg` preserved
- Unknown `{variable}`: replaced with empty string

## Test Strategy

8 Pester scenarios in `tests/win-notification-templates.Tests.ps1`:

1. Stop with `{summary}` template
2. Stop without `transcript_summary` (resolves to empty)
3. PermissionRequest with `{tool_name}`
4. No template configured (fallback to project name)
5. Unknown variable renders as empty
6. All five template keys map from correct events
7. Summary truncation at 120 chars
8. Special characters in project/tool names
