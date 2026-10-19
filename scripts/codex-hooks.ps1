# Shared Codex hooks.json editing for the native installer and uninstaller.
# The caller supplies the existing TOML/path helpers. This file has no side effects.

function Test-PeonCodexInlineHooks([string]$Content) {
    $multilineDelimiter = ''
    $atRoot = $true
    foreach ($line in ($Content -split "\r?\n")) {
        if ($multilineDelimiter) {
            if ($line.Contains($multilineDelimiter)) { $multilineDelimiter = '' }
            continue
        }
        if ($line.TrimStart().StartsWith('#')) { continue }
        if ($line -match '^\s*\[') {
            $atRoot = $false
            # Codex's trust state is configuration, not an inline hook definition.
            if ($line -match '^\s*\[\s*(?:hooks|"hooks"|''hooks'')\s*\.\s*(?:state|"state"|''state'')\s*(?:\.|\])') { continue }
            if ($line -match '^\s*\[\[?\s*(?:hooks|"hooks"|''hooks'')\s*(?:\.|\])') { return $true }
        }
        if ($atRoot -and $line -match '^\s*(?:hooks|"hooks"|''hooks'')\s*(?:=|\.)') { return $true }
        foreach ($delimiter in @('"""', "'''")) {
            if ((([regex]::Matches($line, [regex]::Escape($delimiter))).Count % 2) -eq 1) {
                $multilineDelimiter = $delimiter
                break
            }
        }
    }
    return $false
}

function Get-PeonCodexJsonContent {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [string]$Command = '',
        [object[]]$Events = @()
    )
    $original = [System.IO.File]::ReadAllText($Path)
    try {
        $document = ConvertFrom-Json -InputObject (Remove-Utf8Bom $original) -ErrorAction Stop
    } catch {
        throw "Cannot update Codex hooks.json at ${Path}: invalid JSON. Repair the file and retry. $($_.Exception.Message)"
    }
    if ($null -eq $document -or $document -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Cannot update Codex hooks.json at ${Path}: expected a JSON object."
    }
    $hooksProperty = $document.PSObject.Properties['hooks']
    if ($null -ne $hooksProperty -and $hooksProperty.Value -isnot [System.Management.Automation.PSCustomObject]) {
        throw "Cannot update Codex hooks.json at ${Path}: hooks must be an object."
    }
    if ($null -eq $hooksProperty) {
        if (-not $Command) { return $original }
        $document | Add-Member -MemberType NoteProperty -Name hooks -Value ([PSCustomObject]@{})
    }
    $changed = $false
    foreach ($eventProperty in @($document.hooks.PSObject.Properties)) {
        if ($eventProperty.Value -isnot [Array]) {
            throw "Cannot update Codex hooks.json at ${Path}: event groups must be arrays."
        }
        $keptGroups = New-Object System.Collections.Generic.List[object]
        foreach ($group in $eventProperty.Value) {
            if ($null -eq $group -or $group -isnot [System.Management.Automation.PSCustomObject] -or $group.hooks -isnot [Array]) {
                throw "Cannot update Codex hooks.json at ${Path}: groups must be objects with a hooks array."
            }
            $keptHandlers = New-Object System.Collections.Generic.List[object]
            $removed = $false
            foreach ($handler in $group.hooks) {
                if ($null -eq $handler -or $handler -isnot [System.Management.Automation.PSCustomObject]) {
                    throw "Cannot update Codex hooks.json at ${Path}: handlers must be objects."
                }
                $owned = $false
                if ($handler.type -eq 'command') {
                    foreach ($key in @('command', 'commandWindows', 'command_windows')) {
                        if ($handler.$key -is [string]) {
                            foreach ($marker in (Get-PeonCodexAdapterMarkers $InstallRoot)) {
                                if (Test-PeonCodexPathToken $handler.$key $marker) { $owned = $true; break }
                            }
                        }
                        if ($owned) { break }
                    }
                }
                if ($owned) { $removed = $true; $changed = $true } else { $keptHandlers.Add($handler) }
            }
            if ($keptHandlers.Count -gt 0 -or -not $removed) {
                if ($removed) { $group.hooks = @($keptHandlers.ToArray()) }
                $keptGroups.Add($group)
            }
        }
        if ($keptGroups.Count -gt 0 -or $eventProperty.Value.Count -eq 0) {
            $document.hooks.($eventProperty.Name) = @($keptGroups.ToArray())
        } else {
            $document.hooks.PSObject.Properties.Remove($eventProperty.Name)
        }
    }
    if ($Command) {
        foreach ($event in $Events) {
            $group = [ordered]@{ hooks = @([ordered]@{ type = 'command'; command = $Command; commandWindows = $Command; timeout = 30 }) }
            if ($event.Matcher) { $group.matcher = $event.Matcher }
            $existing = $document.hooks.PSObject.Properties[$event.Name]
            if ($null -ne $existing) {
                $document.hooks.($event.Name) = @($existing.Value) + @([PSCustomObject]$group)
            } else {
                $document.hooks | Add-Member -MemberType NoteProperty -Name $event.Name -Value @([PSCustomObject]$group)
            }
        }
        $changed = $true
    }
    if (-not $changed) { return $original }
    return ($document | ConvertTo-Json -Depth 100)
}
