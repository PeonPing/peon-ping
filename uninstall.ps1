# peon-ping Windows Uninstaller
# Removes peon-ping hooks, skills, CLI command, and installation directory
# Usage: powershell -File uninstall.ps1

param(
    [switch]$KeepSounds,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "=== peon-ping uninstaller ===" -ForegroundColor Cyan
Write-Host ""

# --- Paths ---
$DefaultClaudeDir = Join-Path $env:USERPROFILE ".claude"
$DefaultInstallDir = Join-Path $DefaultClaudeDir "hooks\peon-ping"
$ScriptInstallDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$InstallDir = $DefaultInstallDir
if ($ScriptInstallDir -and (Split-Path -Leaf $ScriptInstallDir) -eq "peon-ping" -and (Split-Path -Leaf (Split-Path -Parent $ScriptInstallDir)) -eq "hooks") {
    $InstallDir = $ScriptInstallDir
}
$ClaudeDir = Split-Path -Parent (Split-Path -Parent $InstallDir)
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$SkillsDir = Join-Path $ClaudeDir "skills"
$CliBinDir = Join-Path $env:USERPROFILE ".local\bin"
$CliPath = Join-Path $CliBinDir "peon.cmd"

# --- Check if installed ---
if (-not (Test-Path $InstallDir)) {
    Write-Host "peon-ping is not installed at $InstallDir" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# --- Remove hooks from settings.json ---
if (Test-Path $SettingsFile) {
    Write-Host "Removing peon hooks from settings.json..."

    try {
        $settingsObj = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        $eventsChanged = @()

        if ($settingsObj.hooks) {
            $hooksObj = $settingsObj.hooks
            $eventNames = $hooksObj.PSObject.Properties.Name

            foreach ($event in $eventNames) {
                $entries = @($hooksObj.$event)
                $originalInnerTotal = 0
                foreach ($entry in $entries) { $originalInnerTotal += @($entry.hooks).Count }

                # Strip only peon/notify/hook-handle-use hooks from each matcher
                # entry; keep sibling hooks users registered alongside ours.
                # Drop a matcher entry only if its hooks list becomes empty.
                $filtered = @($entries | ForEach-Object {
                    $entry = $_
                    $keptHooks = @(@($entry.hooks) | Where-Object {
                        -not ($_.command -and ($_.command -match "peon\.ps1" -or $_.command -match "peon\.sh" -or $_.command -match "notify\.sh" -or $_.command -match "hook-handle-use"))
                    })
                    if ($keptHooks.Count -gt 0) {
                        [PSCustomObject]@{
                            matcher = $entry.matcher
                            hooks   = $keptHooks
                        }
                    }
                } | Where-Object { $_ -ne $null })

                $keptInnerTotal = 0
                foreach ($entry in $filtered) { $keptInnerTotal += @($entry.hooks).Count }
                if ($keptInnerTotal -lt $originalInnerTotal) {
                    $eventsChanged += $event
                }

                if ($filtered.Count -gt 0) {
                    $hooksObj.$event = $filtered
                } else {
                    $hooksObj.PSObject.Properties.Remove($event)
                }
            }

            $settingsObj.hooks = $hooksObj
            $settingsObj | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8

            if ($eventsChanged.Count -gt 0) {
                Write-Host "  Removed hooks for: $($eventsChanged -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "  No peon hooks found in settings.json" -ForegroundColor DarkGray
            }
        }
    } catch {
        Write-Host "  Warning: Could not update settings.json: $_" -ForegroundColor Yellow
    }
}

# --- Remove Cursor hooks ---
$CursorDir = Join-Path $env:USERPROFILE ".cursor"
$CursorHooksFile = Join-Path $CursorDir "hooks.json"

if (Test-Path $CursorHooksFile) {
    Write-Host ""
    Write-Host "Removing Cursor hooks..."
    
    try {
        $cursorData = Get-Content $CursorHooksFile -Raw | ConvertFrom-Json
        $eventsChanged = @()
        
        if ($cursorData.hooks) {
            $hooksObj = $cursorData.hooks
            $hooksIsArray = $hooksObj -is [Array]
            
            if ($hooksIsArray) {
                # Flat array format [{event, command}]
                $originalCount = $hooksObj.Count
                $filtered = @($hooksObj | Where-Object {
                    -not ($_.command -and $_.command -match "hook-handle-use")
                })
                if ($filtered.Count -lt $originalCount) {
                    $eventsChanged += "beforeSubmitPrompt"
                }
                $cursorData.hooks = $filtered
            } else {
                # Dict format {event: [{command}]}
                $eventNames = $hooksObj.PSObject.Properties.Name
                foreach ($event in $eventNames) {
                    $entries = @($hooksObj.$event)
                    $originalCount = $entries.Count
                    $filtered = @($entries | Where-Object {
                        -not ($_.command -and $_.command -match "hook-handle-use")
                    })
                    if ($filtered.Count -lt $originalCount) {
                        $eventsChanged += $event
                    }
                    if ($filtered.Count -gt 0) {
                        $hooksObj.$event = $filtered
                    } else {
                        $hooksObj.PSObject.Properties.Remove($event)
                    }
                }
                $cursorData.hooks = $hooksObj
            }
            $cursorData | ConvertTo-Json -Depth 10 | Set-Content $CursorHooksFile -Encoding UTF8
            
            if ($eventsChanged.Count -gt 0) {
                Write-Host "  Removed Cursor hooks for: $($eventsChanged -join ', ')" -ForegroundColor Green
            } else {
                Write-Host "  No peon-ping Cursor hooks found" -ForegroundColor DarkGray
            }
        }
    } catch {
        Write-Host "  Warning: Could not update Cursor hooks.json: $_" -ForegroundColor Yellow
    }
}

# --- Remove GitHub Copilot CLI hooks ---
$CopilotHooksFile = Join-Path $env:USERPROFILE ".copilot\hooks\peon-ping.json"

if (Test-Path $CopilotHooksFile) {
    Write-Host ""
    Write-Host "Removing Copilot CLI hooks..."
    try {
        Remove-Item -Path $CopilotHooksFile -Force
        Write-Host "  Removed $CopilotHooksFile" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Could not remove ${CopilotHooksFile}: $_" -ForegroundColor Yellow
    }
}

# --- Remove OpenAI Codex hooks ---
$CodexConfigFile = Join-Path $env:USERPROFILE ".codex\config.toml"

function Normalize-PeonCodexPath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $normalized = $Value.Trim().Trim('"').Trim("'")
    $normalized = $normalized -replace '\\\\', '\'
    $normalized = $normalized.Replace('\', '/')
    return $normalized.TrimEnd('/')
}

function Get-PeonCodexMarkers([string]$InstallRoot) {
    $markers = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($InstallRoot)) {
        $markers.Add((Normalize-PeonCodexPath $InstallRoot))
    }
    if ($env:USERPROFILE -and $InstallRoot.StartsWith($env:USERPROFILE, [System.StringComparison]::OrdinalIgnoreCase)) {
        $relative = "~" + $InstallRoot.Substring($env:USERPROFILE.Length)
        $markers.Add((Normalize-PeonCodexPath $relative))
    }
    return @($markers | Where-Object { $_ } | Select-Object -Unique)
}

function Get-PeonCodexAdapterMarkers([string]$InstallRoot) {
    $markers = New-Object System.Collections.Generic.List[string]
    $normalizedRoot = Normalize-PeonCodexPath $InstallRoot
    foreach ($adapterName in @("codex.ps1", "codex.sh")) {
        $adapterPath = "$normalizedRoot/adapters/$adapterName"
        foreach ($marker in (Get-PeonCodexMarkers $adapterPath)) {
            $markers.Add($marker)
        }
    }
    return @($markers | Where-Object { $_ } | Select-Object -Unique)
}

function Test-PeonCodexPathToken([string]$Text, [string]$Path) {
    $normalizedText = Normalize-PeonCodexPath $Text
    $normalizedPath = Normalize-PeonCodexPath $Path
    if (-not $normalizedPath) { return $false }
    $pathChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~:/-"
    $start = 0
    while ($true) {
        $idx = $normalizedText.IndexOf($normalizedPath, $start, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -lt 0) { return $false }
        $before = if ($idx -gt 0) { [string]$normalizedText[$idx - 1] } else { "" }
        $afterIdx = $idx + $normalizedPath.Length
        $after = if ($afterIdx -lt $normalizedText.Length) { [string]$normalizedText[$afterIdx] } else { "" }
        $beforeOk = (-not $before) -or ($pathChars.IndexOf($before) -lt 0)
        $afterOk = (-not $after) -or ($pathChars.IndexOf($after) -lt 0)
        if ($beforeOk -and $afterOk) { return $true }
        $start = $idx + 1
    }
}

function Get-PeonCodexBlockInstallDir([string]$Text) {
    $match = [regex]::Match($Text, '(?m)^\s*#\s*install_dir\s*=\s*(.*?)\s*$')
    if (-not $match.Success) { return "" }
    return Normalize-PeonCodexPath $match.Groups[1].Value
}

function Test-PeonCodexTextForInstall([string]$Text, [string]$InstallRoot) {
    if ($Text -notmatch "peon-ping") { return $false }
    if ($Text -notmatch "adapters[\\/]+codex\.(sh|ps1)") { return $false }
    $installMarkers = Get-PeonCodexMarkers $InstallRoot
    $explicitInstallDir = Get-PeonCodexBlockInstallDir $Text
    if ($explicitInstallDir) {
        foreach ($marker in $installMarkers) {
            if ([string]::Equals($explicitInstallDir, $marker, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
        return $false
    }
    foreach ($adapterMarker in (Get-PeonCodexAdapterMarkers $InstallRoot)) {
        if (Test-PeonCodexPathToken $Text $adapterMarker) { return $true }
    }
    return $false
}

function Get-PeonTomlBracketDelta([string]$Line) {
    $delta = 0
    $quote = [char]0
    $escaped = $false
    foreach ($ch in $Line.ToCharArray()) {
        if ($quote -ne [char]0) {
            if ($quote -eq '"' -and $escaped) {
                $escaped = $false
                continue
            }
            if ($quote -eq '"' -and $ch -eq [char]92) {
                $escaped = $true
                continue
            }
            if ($ch -eq $quote) { $quote = [char]0 }
            continue
        }
        if ($ch -eq '"' -or $ch -eq "'") {
            $quote = $ch
        } elseif ($ch -eq '#') {
            break
        } elseif ($ch -eq '[') {
            $delta++
        } elseif ($ch -eq ']') {
            $delta--
        }
    }
    return $delta
}

function Remove-PeonCodexConfigText([string]$Content, [string]$InstallRoot) {
    if ([string]::IsNullOrEmpty($Content)) { return "" }
    $newline = if ($Content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = @($Content -split "\r?\n")
    $structuralLine = New-Object 'bool[]' $lines.Count
    $multilineDelimiter = ""
    for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
        $structuralLine[$lineIndex] = -not $multilineDelimiter
        if ($multilineDelimiter) {
            if ($lines[$lineIndex].Contains($multilineDelimiter)) { $multilineDelimiter = "" }
            continue
        }
        if ($lines[$lineIndex].TrimStart().StartsWith('#')) { continue }
        foreach ($delimiter in @('"""', "'''")) {
            $delimiterCount = ([regex]::Matches($lines[$lineIndex], [regex]::Escape($delimiter))).Count
            if (($delimiterCount % 2) -eq 1) {
                $multilineDelimiter = $delimiter
                break
            }
        }
    }
    $kept = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $parentMatch = if ($structuralLine[$i]) {
            [regex]::Match($line, '^\s*\[\[hooks\.([^\.\]]+)\]\]\s*(?:#.*)?$')
        } else { [System.Text.RegularExpressions.Match]::Empty }
        if ($parentMatch.Success) {
            $eventName = $parentMatch.Groups[1].Value
            $parentLines = New-Object System.Collections.Generic.List[string]
            $parentLines.Add($line)
            while (($i + 1) -lt $lines.Count -and
                ((-not $structuralLine[$i + 1]) -or $lines[$i + 1] -notmatch '^\s*\[\[?[^\]]+\]\]?') -and
                $lines[$i + 1].Trim() -notin @('# peon-ping Codex hooks begin', '# peon-ping Codex hooks end')) {
                $i++
                $parentLines.Add($lines[$i])
            }

            $childBlocks = New-Object System.Collections.Generic.List[object]
            while (($i + 1) -lt $lines.Count -and
                $structuralLine[$i + 1] -and
                $lines[$i + 1] -match "^\s*\[\[hooks\.$([regex]::Escape($eventName))\.hooks\]\]\s*(?:#.*)?$") {
                $i++
                $childLines = New-Object System.Collections.Generic.List[string]
                $childLines.Add($lines[$i])
                while (($i + 1) -lt $lines.Count -and
                    ((-not $structuralLine[$i + 1]) -or $lines[$i + 1] -notmatch '^\s*\[\[?[^\]]+\]\]?') -and
                    $lines[$i + 1].Trim() -notin @('# peon-ping Codex hooks begin', '# peon-ping Codex hooks end')) {
                    $i++
                    $childLines.Add($lines[$i])
                }
                $childBlocks.Add(@($childLines))
            }

            $remainingChildren = New-Object System.Collections.Generic.List[object]
            $removedChild = $false
            foreach ($childBlock in $childBlocks) {
                $childText = @($childBlock | Where-Object {
                    $_.Trim() -match '^command(?:_windows|Windows)?\s*='
                }) -join $newline
                if (Test-PeonCodexTextForInstall $childText $InstallRoot) {
                    $removedChild = $true
                } else {
                    $remainingChildren.Add($childBlock)
                }
            }

            if ((-not $removedChild) -or $remainingChildren.Count -gt 0) {
                foreach ($parentLine in $parentLines) { $kept.Add($parentLine) }
                foreach ($childBlock in $remainingChildren) {
                    foreach ($childLine in $childBlock) { $kept.Add($childLine) }
                }
            }
        } elseif ($line.Trim() -match '^notify\s*=') {
            $blockLines = New-Object System.Collections.Generic.List[string]
            $blockLines.Add($line)
            $balance = Get-PeonTomlBracketDelta $line
            while ($balance -gt 0 -and ($i + 1) -lt $lines.Count) {
                $i++
                $blockLines.Add($lines[$i])
                $balance += Get-PeonTomlBracketDelta $lines[$i]
            }
            $blockText = $blockLines -join "`n"
            if (Test-PeonCodexTextForInstall $blockText $InstallRoot) {
                continue
            }
            foreach ($blockLine in $blockLines) { $kept.Add($blockLine) }
        } else {
            $kept.Add($line)
        }
    }

    # Codex may append its own tables before our legacy end marker. Remove
    # only the marker lines for this install root, never the content between.
    $markerStructuralLine = New-Object 'bool[]' $kept.Count
    $multilineDelimiter = ""
    for ($lineIndex = 0; $lineIndex -lt $kept.Count; $lineIndex++) {
        $markerStructuralLine[$lineIndex] = -not $multilineDelimiter
        if ($multilineDelimiter) {
            if ($kept[$lineIndex].Contains($multilineDelimiter)) { $multilineDelimiter = "" }
            continue
        }
        if ($kept[$lineIndex].TrimStart().StartsWith('#')) { continue }
        foreach ($delimiter in @('"""', "'''")) {
            $delimiterCount = ([regex]::Matches($kept[$lineIndex], [regex]::Escape($delimiter))).Count
            if (($delimiterCount % 2) -eq 1) {
                $multilineDelimiter = $delimiter
                break
            }
        }
    }
    $withoutMarkers = New-Object System.Collections.Generic.List[string]
    $insideTargetMarkers = $false
    for ($i = 0; $i -lt $kept.Count; $i++) {
        $line = $kept[$i]
        if ($markerStructuralLine[$i] -and $line.Trim() -eq '# peon-ping Codex hooks begin') {
            $next = $i + 1
            while ($next -lt $kept.Count -and [string]::IsNullOrWhiteSpace($kept[$next])) { $next++ }
            $markerInstallDir = if ($next -lt $kept.Count) {
                Get-PeonCodexBlockInstallDir ("$line$newline$($kept[$next])")
            } else { "" }
            $isTargetMarker = $false
            foreach ($installMarker in (Get-PeonCodexMarkers $InstallRoot)) {
                if ([string]::Equals($markerInstallDir, $installMarker, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $isTargetMarker = $true
                    break
                }
            }
            if ($isTargetMarker) {
                $insideTargetMarkers = $true
                while (($i + 1) -lt $next) { $i++ }
                $i = $next
                continue
            }
        }
        if ($insideTargetMarkers -and $markerStructuralLine[$i] -and $line.Trim() -eq '# peon-ping Codex hooks end') {
            $insideTargetMarkers = $false
            continue
        }
        $withoutMarkers.Add($line)
    }
    return ($withoutMarkers -join $newline).TrimEnd("`r", "`n")
}

function Set-PeonCodexConfigAtomic([string]$Path, [string]$Content) {
    $directory = Split-Path -Parent $Path
    $leaf = Split-Path -Leaf $Path
    $tempPath = Join-Path $directory ".$leaf.peon-ping-$PID-$([guid]::NewGuid().ToString('N')).tmp"
    $backupPath = "$tempPath.backup"
    try {
        Set-Content -Path $tempPath -Value $Content -Encoding UTF8
        if (Test-Path $Path) {
            [System.IO.File]::Replace($tempPath, $Path, $backupPath)
        } else {
            Move-Item -Path $tempPath -Destination $Path
        }
    } finally {
        Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        Remove-Item -Path $backupPath -Force -ErrorAction SilentlyContinue
    }
}

if (Test-Path $CodexConfigFile) {
    Write-Host ""
    Write-Host "Removing Codex hooks..."
    try {
        $codexContent = Get-Content $CodexConfigFile -Raw
        $originalCodexContent = $codexContent
        $codexNewline = if ($codexContent.Contains("`r`n")) { "`r`n" } else { "`n" }

        $codexContent = Remove-PeonCodexConfigText $codexContent $InstallDir
        if ($codexContent) { $codexContent = "$codexContent$codexNewline" }

        if ($codexContent -ne $originalCodexContent) {
            Set-PeonCodexConfigAtomic $CodexConfigFile $codexContent
            Write-Host "  Removed Codex hooks from $CodexConfigFile" -ForegroundColor Green
        } else {
            Write-Host "  No peon-ping Codex hooks found" -ForegroundColor DarkGray
        }
    } catch {
        Write-Host "  Warning: Could not update ${CodexConfigFile}: $_" -ForegroundColor Yellow
    }
}

# --- Remove skills ---
Write-Host ""
Write-Host "Removing skills..."

$skillsRemoved = 0
foreach ($skillName in @("peon-ping-toggle", "peon-ping-config", "peon-ping-use", "peon-ping-log", "peon-ping-rename")) {
    $skillPath = Join-Path $SkillsDir $skillName
    if (Test-Path $skillPath) {
        Remove-Item -Path $skillPath -Recurse -Force
        Write-Host "  /$skillName" -ForegroundColor DarkGray
        $skillsRemoved++
    }
}

if ($skillsRemoved -gt 0) {
    Write-Host "  Removed $skillsRemoved skill(s)" -ForegroundColor Green
} else {
    Write-Host "  No skills found" -ForegroundColor DarkGray
}

# --- Remove CLI command ---
if (Test-Path $CliPath) {
    Write-Host ""
    Write-Host "Removing CLI command..."
    Remove-Item -Path $CliPath -Force
    Write-Host "  Removed peon.cmd" -ForegroundColor Green
}

# --- Remove install directory ---
if (Test-Path $InstallDir) {
    Write-Host ""

    if ($KeepSounds) {
        Write-Host "Removing installation (keeping sound packs)..."
        # Remove everything except packs directory
        Get-ChildItem -Path $InstallDir | Where-Object { $_.Name -ne "packs" } | Remove-Item -Recurse -Force
        Write-Host "  Removed (packs preserved at $InstallDir\packs)" -ForegroundColor Green
    } else {
        $packsDir = Join-Path $InstallDir "packs"
        $packCount = 0
        $soundCount = 0

        if (Test-Path $packsDir) {
            $packs = Get-ChildItem -Path $packsDir -Directory
            $packCount = $packs.Count
            foreach ($pack in $packs) {
                $sounds = Get-ChildItem -Path (Join-Path $pack.FullName "sounds") -File -ErrorAction SilentlyContinue
                $soundCount += $sounds.Count
            }
        }

        Write-Host "Removing installation directory..."
        if ($packCount -gt 0 -and -not $Force) {
            Write-Host "  This will delete $packCount pack(s) ($soundCount sounds)" -ForegroundColor Yellow
            Write-Host "  Location: $InstallDir" -ForegroundColor DarkGray
            Write-Host ""
            $confirm = Read-Host "  Continue? [Y/n]"

            if ($confirm -match "^[Nn]") {
                Write-Host ""
                Write-Host "Cancelled. To keep sounds, run: .\uninstall.ps1 -KeepSounds" -ForegroundColor Yellow
                exit 0
            }
        }

        Remove-Item -Path $InstallDir -Recurse -Force
        Write-Host "  Removed $InstallDir" -ForegroundColor Green
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== Uninstall complete ===" -ForegroundColor Green
Write-Host "Me go now." -ForegroundColor DarkGray
Write-Host ""

if ($KeepSounds) {
    Write-Host "Your sound packs are still at: $InstallDir\packs" -ForegroundColor Cyan
    Write-Host "To remove them: Remove-Item -Recurse '$InstallDir'" -ForegroundColor DarkGray
    Write-Host ""
}
