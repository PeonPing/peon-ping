<#
.SYNOPSIS
    Windows native TTS backend for peon-ping. Speaks stdin text via SAPI5
    (System.Speech.Synthesis). Fire-and-forget: exit code is always 0, all
    errors are contained, and no output is produced during normal hook
    invocations. Debug diagnostics are routed to stderr and gated on
    PEON_DEBUG=1.

.DESCRIPTION
    Invoked from peon.ps1's Invoke-TtsSpeak helper with decoded plain-text
    piped on stdin and voice/rate/volume passed as named parameters. Base64
    encoding lives in Invoke-TtsSpeak (it guards the Start-Process -Command
    boundary) -- bytes arriving here are already UTF-8 text.

    Rate and volume are normalized at the integration layer to platform-
    independent floats (rate: 0.0-2.0 with 1.0 = normal; volume: 0.0-1.0)
    and mapped internally to SAPI5's native units (rate int -10..+10,
    volume int 0..100) with clamping.

    Under PEON_TTS_DRY_RUN=1 the script writes the resolved synthesis
    parameters as JSON to PEON_TTS_TRACE_FILE and skips the Speak call.
    This test hook lets Pester verify behaviour without driving real SAPI.

.PARAMETER InputText
    Pipeline input. Each object piped in becomes a line of the buffer;
    trailing whitespace is trimmed before synthesis. Empty or whitespace-
    only input exits 0 without calling Speak.

.PARAMETER Voice
    SAPI5 voice name (exact match against GetInstalledVoices output) or
    the sentinel string "default" to use the engine default. A requested
    voice that is not installed falls through to the default with a debug
    line when PEON_DEBUG=1. Default: "default".

.PARAMETER Rate
    Float, 0.0-2.0. 1.0 is normal speed, 0.5 is half, 2.0 is double.
    Mapped to SAPI int via [math]::Round((Rate-1.0)*10) and clamped to
    -10..+10. Default: 1.0.

.PARAMETER Vol
    Float, 0.0-1.0. 0.0 is silent, 1.0 is full volume. Mapped to SAPI int
    via [math]::Round(Vol*100) and clamped to 0..100. Default: 0.5.

.PARAMETER ListVoices
    If set, prints installed SAPI voice names to stdout (one per line)
    and exits 0 without reading stdin or calling Speak.

.EXAMPLE
    "hello world" | .\tts-native.ps1 -Voice "Microsoft David" -Rate 1.0 -Vol 0.5

.EXAMPLE
    .\tts-native.ps1 -ListVoices
#>
param(
    [Parameter(ValueFromPipeline = $true)]
    [string]$InputText,
    [string]$Voice = "default",
    [double]$Rate = 1.0,
    [double]$Vol = 0.5,
    [switch]$ListVoices
)

begin {
    $script:PeonDebug = ($env:PEON_DEBUG -eq "1")
    $script:DryRun = ($env:PEON_TTS_DRY_RUN -eq "1")
    $script:TracePath = $env:PEON_TTS_TRACE_FILE

    function Write-DebugLine {
        param([string]$Message)
        if ($script:PeonDebug) {
            [Console]::Error.WriteLine("[tts-native] $Message")
        }
    }

    function Write-Trace {
        param([hashtable]$Fields)
        if (-not $script:DryRun) { return }
        if (-not $script:TracePath) { return }
        try {
            $json = $Fields | ConvertTo-Json -Depth 4 -Compress
            [System.IO.File]::WriteAllText($script:TracePath, ($json + [Environment]::NewLine), (New-Object System.Text.UTF8Encoding $false))
        } catch {
            Write-DebugLine "trace write failed: $_"
        }
    }

    # Load System.Speech. If this fails (PowerShell 7 Core on non-Windows,
    # missing assembly, etc.) fall through to a no-op path. In dry-run mode
    # voice enumeration and synthesis are stubbed so tests work on runners
    # without a real SAPI stack.
    $script:SpeechLoaded = $false
    try {
        Add-Type -AssemblyName System.Speech -ErrorAction Stop
        $script:SpeechLoaded = $true
    } catch {
        Write-DebugLine "failed to load System.Speech: $_"
    }

    # --- -ListVoices short-circuit: runs in begin, exits before process/end ---
    if ($ListVoices) {
        if ($script:SpeechLoaded) {
            try {
                $enumSynth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
                $enumSynth.GetInstalledVoices() | ForEach-Object {
                    [Console]::Out.WriteLine($_.VoiceInfo.Name)
                }
                $enumSynth.Dispose()
            } catch {
                Write-DebugLine "voice enumeration failed: $_"
            }
        }
        exit 0
    }

    $script:Buffer = New-Object System.Text.StringBuilder
}

process {
    # Pipeline input arrives here one object at a time. Empty values are
    # skipped so they do not inject blank lines into the buffer.
    if ($null -ne $InputText -and $InputText.Length -gt 0) {
        [void]$script:Buffer.AppendLine($InputText)
    }
}

end {
    $text = $script:Buffer.ToString().TrimEnd()

    # Fallback: if invoked via `powershell.exe -File tts-native.ps1` the
    # PowerShell pipeline does not bind piped stdin to $InputText -- stdin
    # belongs to powershell.exe itself. Read the redirected console stream
    # directly so the DoD smoke test (`"text" | powershell -File ...`) and
    # external callers behave the same as an in-process pipeline.
    if (-not $text) {
        try {
            if ([Console]::IsInputRedirected) {
                $stdin = [Console]::In.ReadToEnd()
                if ($stdin) { $text = $stdin.TrimEnd() }
            }
        } catch {
            Write-DebugLine "stdin read failed: $_"
        }
    }

    if (-not $text) {
        Write-Trace @{ Spoke = $false; Reason = "empty-input" }
        exit 0
    }

    # Unit conversions. Pure arithmetic -- no engine calls yet.
    $sapiRate = [int][math]::Round(($Rate - 1.0) * 10)
    $sapiRate = [math]::Max(-10, [math]::Min(10, $sapiRate))

    $sapiVolume = [int][math]::Round($Vol * 100)
    $sapiVolume = [math]::Max(0, [math]::Min(100, $sapiVolume))

    # Voice resolution. The "default" sentinel means "do not call SelectVoice";
    # any explicit name is looked up in the installed voices list. A miss
    # emits a debug line and falls through to the engine default.
    $selectVoiceCalled = $false
    $selectedVoice = $null
    $installedVoices = @()

    if ($script:SpeechLoaded) {
        try {
            $probe = [System.Speech.Synthesis.SpeechSynthesizer]::new()
            $installedVoices = @($probe.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo.Name })
            $probe.Dispose()
        } catch {
            Write-DebugLine "voice probe failed: $_"
        }
    }

    $voiceToSelect = $null
    if ($Voice -and $Voice -ne "default") {
        if ($installedVoices -contains $Voice) {
            $voiceToSelect = $Voice
            $selectVoiceCalled = $true
            $selectedVoice = $Voice
        } else {
            Write-DebugLine "voice '$Voice' not installed; using default"
        }
    }

    if ($script:DryRun) {
        Write-Trace @{
            Spoke             = $true
            Text              = $text
            SapiRate          = $sapiRate
            SapiVolume        = $sapiVolume
            SelectVoiceCalled = $selectVoiceCalled
            SelectedVoice     = $selectedVoice
            RequestedVoice    = $Voice
        }
        exit 0
    }

    if (-not $script:SpeechLoaded) {
        # Nothing more to do -- Add-Type failed, we already logged the reason.
        exit 0
    }

    try {
        $synth = [System.Speech.Synthesis.SpeechSynthesizer]::new()
        $synth.Rate = $sapiRate
        $synth.Volume = $sapiVolume

        if ($voiceToSelect) {
            try {
                $synth.SelectVoice($voiceToSelect)
            } catch {
                Write-DebugLine "SelectVoice('$voiceToSelect') failed: $_"
            }
        }

        $synth.Speak($text)
        $synth.Dispose()
    } catch {
        Write-DebugLine "SAPI5 synthesis failed: $_"
        # Do not propagate -- hook must not fail on TTS errors.
    }

    exit 0
}
