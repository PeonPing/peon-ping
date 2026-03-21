param(
    [Parameter(Mandatory=$true)]
    [string]$path,
    [Parameter(Mandatory=$true)]
    [double]$vol
)

# Diagnostic logging: set PEON_DEBUG=1 to surface silent failure diagnostics on stderr
$peonDebug = $env:PEON_DEBUG -eq "1"

# WAV files: use MediaPlayer with volume control
# (MediaPlayer is WPF/PresentationCore — safe in this detached process, not in the hook itself)
if ($path -match "\.wav$") {
    try {
        Add-Type -AssemblyName PresentationCore
        $player = [System.Windows.Media.MediaPlayer]::new()
        $player.Volume = $vol

        Register-ObjectEvent -InputObject $player -EventName MediaOpened -SourceIdentifier MediaOpened | Out-Null
        Register-ObjectEvent -InputObject $player -EventName MediaFailed -SourceIdentifier MediaFailed | Out-Null
        $player.Open([uri]::new($path))
        $player.Play()

        # Pump WPF dispatcher so MediaOpened/MediaFailed events fire in this console process
        $deadline = [datetime]::UtcNow.AddSeconds(5)
        $failed = $false
        while ([datetime]::UtcNow -lt $deadline) {
            [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
                [System.Windows.Threading.DispatcherPriority]::Background,
                [Action]{ }
            )
            $failEvt = Get-Event -SourceIdentifier MediaFailed -ErrorAction SilentlyContinue
            if ($failEvt) {
                $failed = $true
                if ($peonDebug) { Write-Warning "peon-ping: WAV playback failed for '$path': $($failEvt.SourceEventArgs.ErrorException)" }
                break
            }
            $evt = Get-Event -SourceIdentifier MediaOpened -ErrorAction SilentlyContinue
            if ($evt) { break }
            Start-Sleep -Milliseconds 50
        }

        # Timeout: neither MediaOpened nor MediaFailed fired — treat as failure
        if (-not $failed -and -not $evt) {
            $failed = $true
            if ($peonDebug) { Write-Warning "peon-ping: WAV playback failed for '$path': timed out waiting for media events" }
        }

        # Wait for playback to finish (only if opened successfully)
        if (-not $failed -and $player.NaturalDuration.HasTimeSpan) {
            $secs = $player.NaturalDuration.TimeSpan.TotalSeconds
            Start-Sleep -Seconds ([math]::Ceiling($secs))
        }

        Unregister-Event -SourceIdentifier MediaOpened -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier MediaFailed -ErrorAction SilentlyContinue
        $player.Close()
    } catch {
        if ($peonDebug) { Write-Warning "peon-ping: WAV playback failed for '$path': $_" }
    }
    exit 0
}

# Non-WAV formats (mp3, ogg, etc.): CLI player priority chain
# ffplay -> mpv -> vlc (MediaPlayer only handles WAV above; CLI players for other formats)

# ffplay: volume 0-100 integer scale
$ffplay = Get-Command ffplay -ErrorAction SilentlyContinue
if ($ffplay) {
    $ffVol = [math]::Max(0, [math]::Min(100, [int]($vol * 100)))
    & $ffplay.Source -nodisp -autoexit -volume $ffVol $path 2>$null
    exit 0
}

# mpv: volume 0-100 integer scale
$mpv = Get-Command mpv -ErrorAction SilentlyContinue
if ($mpv) {
    $mpvVol = [math]::Max(0, [math]::Min(100, [int]($vol * 100)))
    & $mpv.Source --no-video --volume=$mpvVol $path 2>$null
    exit 0
}

# vlc: volume 0.0-2.0 gain multiplier (1.0 = 100%)
$vlc = Get-Command vlc -ErrorAction SilentlyContinue
if (-not $vlc) {
    # Check common install locations
    $vlcPaths = @(
        "$env:ProgramFiles\VideoLAN\VLC\vlc.exe",
        "${env:ProgramFiles(x86)}\VideoLAN\VLC\vlc.exe"
    )
    foreach ($p in $vlcPaths) {
        if (Test-Path $p) {
            $vlc = Get-Item $p
            break
        }
    }
}
if ($vlc) {
    $vlcGain = [math]::Round($vol * 2.0, 2).ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $vlcPath = if ($vlc -is [System.Management.Automation.ApplicationInfo]) { $vlc.Source } else { $vlc.FullName }
    & $vlcPath --intf dummy --play-and-exit --gain $vlcGain $path 2>$null
    exit 0
}

# No CLI player found
if ($peonDebug) { Write-Warning "peon-ping: no audio player found for '$path' (tried ffplay, mpv, vlc)" }
exit 0
