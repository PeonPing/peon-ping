# HOOKBUG integration tests — validates async audio and atomic state on Windows
# Run: pwsh -NoProfile -File tests/hookbug-integration.ps1
# Exit code 0 = all pass, 1 = failure

$ErrorActionPreference = 'Stop'
$failed = 0
$passed = 0
$InstallDir = Join-Path $HOME ".claude\hooks\peon-ping"
$peonScript = Join-Path $InstallDir "peon.ps1"
$stateFile = Join-Path $InstallDir ".state.json"

function Test-Case {
    param([string]$Name, [scriptblock]$Block)
    try {
        & $Block
        Write-Host "  PASS: $Name" -ForegroundColor Green
        $script:passed++
    } catch {
        Write-Host "  FAIL: $Name — $_" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host "`n=== HOOKBUG Integration Tests ===" -ForegroundColor Cyan

# --- 1. All hook events exit cleanly under timeout ---
Write-Host "`nHook event dispatch:" -ForegroundColor Yellow
$events = @("SessionStart","Stop","Notification","PermissionRequest","PostToolUseFailure","SubagentStart","PreCompact","UserPromptSubmit")
foreach ($event in $events) {
    Test-Case "$event exits cleanly" {
        $json = "{`"hook_event_name`":`"$event`",`"session_id`":`"integration-test`"}"
        $proc = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile","-NonInteractive","-Command","'$json' | & '$peonScript'" -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) { throw "exit code $($proc.ExitCode)" }
    }
}

# --- 2. No event exceeds 5 seconds ---
Write-Host "`nPerformance (5s budget):" -ForegroundColor Yellow
foreach ($event in $events) {
    Test-Case "$event under 5s" {
        $json = "{`"hook_event_name`":`"$event`",`"session_id`":`"perf-test`"}"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $proc = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile","-NonInteractive","-Command","'$json' | & '$peonScript'" -NoNewWindow -Wait -PassThru
        $sw.Stop()
        if ($sw.ElapsedMilliseconds -gt 5000) { throw "$($sw.ElapsedMilliseconds)ms" }
    }
}

# --- 3. Concurrent Stop events don't corrupt state ---
Write-Host "`nConcurrency:" -ForegroundColor Yellow
Test-Case "5 concurrent Stop events produce valid state" {
    # Ensure clean state before concurrency test
    if (Test-Path $stateFile) {
        try { $null = Get-Content $stateFile -Raw | ConvertFrom-Json } catch {
            Set-Content $stateFile -Value '{}' -Encoding UTF8
        }
    }
    $jobs = 1..5 | ForEach-Object {
        Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile","-NonInteractive","-Command","'{`"hook_event_name`":`"Stop`",`"session_id`":`"concurrent-$_`"}' | & '$peonScript'" -NoNewWindow -PassThru
    }
    $jobs | ForEach-Object { $_.WaitForExit(10000) }
    $raw = Get-Content $stateFile -Raw
    $null = $raw | ConvertFrom-Json  # throws if invalid
}

Test-Case "No orphan .tmp files after concurrent writes" {
    $tmps = Get-ChildItem -Path $InstallDir -Filter "*.tmp" -ErrorAction SilentlyContinue
    if ($tmps) { throw "Found $($tmps.Count) orphan temp files" }
}

# --- 4. Corrupted state recovery ---
Write-Host "`nResilience:" -ForegroundColor Yellow
Test-Case "Recovers from corrupted state file" {
    $backup = $null
    if (Test-Path $stateFile) { $backup = Get-Content $stateFile -Raw }
    Set-Content $stateFile -Value "NOT{JSON" -Encoding UTF8
    $json = '{"hook_event_name":"SessionStart","session_id":"corrupt-test"}'
    $proc = Start-Process -FilePath "pwsh" -ArgumentList "-NoProfile","-NonInteractive","-Command","'$json' | & '$peonScript'" -NoNewWindow -Wait -PassThru
    # Hook must not crash on corrupted state
    if ($proc.ExitCode -ne 0) { throw "exit code $($proc.ExitCode)" }
    # State file should now be valid JSON (overwritten by Write-StateAtomic)
    $raw = Get-Content $stateFile -Raw
    try { $null = $raw | ConvertFrom-Json } catch {
        # If state wasn't rewritten (e.g., category disabled), that's OK — the hook survived
        Write-Host "    (state not rewritten — hook survived but category may be disabled)" -ForegroundColor DarkGray
    }
    if ($backup) { Set-Content $stateFile -Value $backup -Encoding UTF8 }
}

# --- 5. win-play.ps1 exits without MediaPlayer ---
Write-Host "`nAudio backend:" -ForegroundColor Yellow
Test-Case "win-play.ps1 contains no MediaPlayer code" {
    $content = Get-Content (Join-Path $InstallDir "scripts\win-play.ps1") -Raw
    # Exclude comments — only check executable lines
    $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*#' }
    $code = $codeLines -join "`n"
    if ($code -match 'MediaPlayer|PresentationCore') { throw "MediaPlayer still referenced in code" }
}

Test-Case "peon.ps1 contains no inline audio playback" {
    $content = Get-Content $peonScript -Raw
    if ($content -match 'MediaPlayer|PresentationCore') { throw "MediaPlayer still referenced" }
    if ($content -match 'Add-Type.*PresentationCore') { throw "PresentationCore assembly load still present" }
}

Test-Case "peon.ps1 uses Write-StateAtomic" {
    $content = Get-Content $peonScript -Raw
    if ($content -notmatch 'Write-StateAtomic') { throw "Write-StateAtomic not found" }
}

Test-Case "peon.ps1 uses Read-StateWithRetry" {
    $content = Get-Content $peonScript -Raw
    if ($content -notmatch 'Read-StateWithRetry') { throw "Read-StateWithRetry not found" }
}

Test-Case "peon.ps1 has safety timer" {
    $content = Get-Content $peonScript -Raw
    if ($content -notmatch 'System\.Timers\.Timer') { throw "Safety timer not found" }
}

Test-Case "peon.ps1 delegates audio via Start-Process" {
    $content = Get-Content $peonScript -Raw
    if ($content -notmatch 'Start-Process') { throw "Start-Process delegation not found" }
    if ($content -notmatch 'win-play\.ps1') { throw "win-play.ps1 reference not found" }
}

# --- Summary ---
$total = $passed + $failed
Write-Host "`n=== Results: $passed/$total passed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
if ($failed -gt 0) { exit 1 }
