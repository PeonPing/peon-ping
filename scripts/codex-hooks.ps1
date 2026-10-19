# Shared Codex hooks.json editing for the native installer and uninstaller.
# The caller supplies the existing TOML/path helpers. This file has no side effects.

# Read TOML key segments rather than their raw spelling: quoted keys can contain
# dots or Unicode escapes, so a prefix regex cannot distinguish them safely.
function Get-PeonTomlKeyPrefix([string]$Line, [int]$Start = 0) {
    $token = [regex]'\G\s*(?:([A-Za-z0-9_-]+)|"((?:\\.|[^"\\])*)"|''([^'']*)'')\s*'
    $parts = New-Object System.Collections.Generic.List[string]
    $cursor = $Start
    while ($cursor -lt $Line.Length) {
        $match = $token.Match($Line, $cursor)
        if (-not $match.Success) { return $null }
        if ($match.Groups[1].Success) { $value = $match.Groups[1].Value }
        elseif ($match.Groups[3].Success) { $value = $match.Groups[3].Value }
        else {
            try {
                $value = [regex]::Replace($match.Groups[2].Value, '\\(?:u[0-9A-Fa-f]{4}|U[0-9A-Fa-f]{8}|[btnfr"\\])', {
                    param($escape)
                    if ($escape.Value[1] -ceq 'u' -or $escape.Value[1] -ceq 'U') {
                        return [char]::ConvertFromUtf32([Convert]::ToInt32($escape.Value.Substring(2), 16))
                    }
                    switch ($escape.Value.Substring(1)) {
                        'b' { return [string][char]8 }
                        't' { return "`t" }
                        'n' { return "`n" }
                        'f' { return [string][char]12 }
                        'r' { return "`r" }
                        default { return $escape.Value.Substring(1) }
                    }
                })
            } catch { return $null }
        }
        $parts.Add($value)
        $cursor = $match.Index + $match.Length
        if ($cursor -ge $Line.Length) { return $null }
        if ($Line[$cursor] -ne '.') {
            return [PSCustomObject]@{ Parts = @($parts.ToArray()); Delimiter = [string]$Line[$cursor] }
        }
        $cursor++
    }
    return $null
}

# Track string syntax so hook-looking examples and escaped triple quotes are
# never mistaken for actual tables. Depth tracks value containers across lines.
function Get-PeonTomlMultilineState([string]$Line, [string]$State, [ref]$Depth = $null) {
    $cursor = 0
    while ($cursor -lt $Line.Length) {
        if ($State) {
            $end = $Line.IndexOf($State, $cursor, [System.StringComparison]::Ordinal)
            if ($end -lt 0) { return $State }
            if ($State -eq '"""') {
                $slashes = 0
                for ($i = $end - 1; $i -ge 0 -and $Line[$i] -eq [char]92; $i--) { $slashes++ }
                if (($slashes % 2) -eq 1) { $cursor = $end + 1; continue }
            }
            $cursor = $end + 3
            $State = ''
            continue
        }
        $character = $Line[$cursor]
        if ($character -eq '#') { break }
        if ($character -eq '"' -or $character -eq "'") {
            $quote = [string]$character
            if ($cursor + 3 -le $Line.Length -and $Line.Substring($cursor, 3) -eq ($quote * 3)) {
                $State = $quote * 3
                $cursor += 3
                continue
            }
            $cursor++
            while ($cursor -lt $Line.Length) {
                if ($quote -eq '"' -and $Line[$cursor] -eq [char]92) { $cursor += 2; continue }
                if ([string]$Line[$cursor] -eq $quote) { $cursor++; break }
                $cursor++
            }
            continue
        }
        if ($null -ne $Depth) {
            if ($character -eq '[' -or $character -eq '{') { $Depth.Value++ }
            elseif ($character -eq ']' -or $character -eq '}') { $Depth.Value-- }
        }
        $cursor++
    }
    return $State
}

function Test-PeonCodexInlineHooks([string]$Content) {
    $multilineDelimiter = ''
    $atRoot = $true
    $depth = 0
    foreach ($line in ($Content -split "\r?\n")) {
        if (-not $multilineDelimiter -and $depth -eq 0) {
            $header = [regex]::Match($line, '^\s*\[\[?')
            $key = $null
            if ($header.Success) {
                $atRoot = $false
                $key = Get-PeonTomlKeyPrefix $line $header.Length
                if ($null -ne $key -and $key.Delimiter -ne ']') { $key = $null }
            } elseif ($atRoot) {
                $key = Get-PeonTomlKeyPrefix $line
                if ($null -ne $key -and $key.Delimiter -ne '=') { $key = $null }
            }
            if ($null -ne $key -and $key.Parts[0] -ceq 'hooks') {
                # Trust state is configuration, including quoted/dotted keys.
                if ($key.Parts.Count -lt 2 -or $key.Parts[1] -cne 'state') { return $true }
            }
        }
        $multilineDelimiter = Get-PeonTomlMultilineState $line $multilineDelimiter ([ref]$depth)
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
