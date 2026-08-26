<#
.SYNOPSIS
    Windows MiniMax speech (T2A) TTS backend for peon-ping. Synthesizes stdin
    text through the MiniMax text-to-audio (T2A v2) HTTP API, then plays the
    returned audio via scripts/win-play.ps1. Fire-and-forget: the exit code is
    always 0, every error is contained, and no output is produced during
    normal hook invocations. Debug diagnostics go to stderr, gated on
    PEON_DEBUG=1.

.DESCRIPTION
    Invoked from Invoke-TtsSpeak with decoded plain text piped on stdin and
    voice/rate/volume passed as named parameters, matching the calling
    convention in docs/adr/ADR-001-tts-backend-architecture.md. Unlike the
    native SAPI5 backend, this backend produces an audio file over HTTP and
    plays it locally.

    The regional endpoint is selected from PEON_MINIMAX_REGION: "global_en"
    (default) uses api.minimax.io, "cn_zh" uses api.minimaxi.com. The Bearer
    credential comes from MINIMAX_API_KEY; an optional MINIMAX_GROUP_ID is
    appended as a ?GroupId= query argument.

    Under PEON_TTS_DRY_RUN=1 the script writes the resolved request (never the
    credential itself) as JSON to PEON_TTS_TRACE_FILE and skips the network
    call. This test hook lets Pester verify request construction without
    reaching the API.

.PARAMETER InputText
    Pipeline input. Each object piped in becomes a line of the buffer;
    trailing whitespace is trimmed before synthesis. Empty or whitespace-only
    input exits 0 without any request.

.PARAMETER Voice
    MiniMax voice_id, or the sentinel string "default" to let the service pick
    its default voice (voice_id is omitted from the request). Default:
    "default".

.PARAMETER Rate
    Float, 1.0 = normal speed. Mapped to voice_setting.speed and clamped to the
    MiniMax-supported 0.5-2.0 range. Default: 1.0.

.PARAMETER Vol
    Float, 0.0-1.0. Applied at the local player (win-play.ps1), not the API.
    Default: 0.5.

.PARAMETER ListVoices
    If set, exits 0 without a request. MiniMax voices are documented voice_id
    strings rather than a locally enumerable list.

.EXAMPLE
    "hello world" | .\tts-minimax.ps1 -Voice "some-voice-id" -Rate 1.0 -Vol 0.5
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
            [Console]::Error.WriteLine("[tts-minimax] $Message")
        }
    }

    function Write-Trace {
        param([hashtable]$Fields)
        if (-not $script:DryRun) { return }
        if (-not $script:TracePath) { return }
        try {
            $json = $Fields | ConvertTo-Json -Depth 6 -Compress
            Set-Content -Path $script:TracePath -Value $json -Encoding UTF8
        } catch {
            Write-DebugLine "trace write failed: $_"
        }
    }

    function Resolve-Endpoint {
        param([string]$Region)
        switch ($Region) {
            "cn_zh"     { return "https://api.minimaxi.com/v1/t2a_v2" }
            "global_en" { return "https://api.minimax.io/v1/t2a_v2" }
            default     { return "https://api.minimax.io/v1/t2a_v2" }
        }
    }

    # --- -ListVoices short-circuit: runs in begin, exits before process/end ---
    if ($ListVoices) {
        Write-DebugLine "voice enumeration not supported for the MiniMax backend"
        exit 0
    }

    $script:Buffer = New-Object System.Text.StringBuilder
}

process {
    if ($null -ne $InputText -and $InputText.Length -gt 0) {
        [void]$script:Buffer.AppendLine($InputText)
    }
}

end {
    $text = $script:Buffer.ToString().TrimEnd()

    # Fallback: when invoked via `powershell.exe -File tts-minimax.ps1` the
    # pipeline does not bind piped stdin to $InputText -- read the redirected
    # console stream directly so external callers behave like an in-process
    # pipeline.
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

    # Resolve request parameters from the environment.
    $region = if ($env:PEON_MINIMAX_REGION) { $env:PEON_MINIMAX_REGION } else { "global_en" }
    $model = if ($env:PEON_MINIMAX_MODEL) { $env:PEON_MINIMAX_MODEL } else { "speech-2.8-hd" }
    $fmt = if ($env:PEON_MINIMAX_FORMAT) { $env:PEON_MINIMAX_FORMAT } else { "mp3" }
    $apiKey = $env:MINIMAX_API_KEY
    $groupId = $env:MINIMAX_GROUP_ID

    $url = Resolve-Endpoint -Region $region
    if ($groupId) {
        $url = $url + "?GroupId=" + $groupId
    }

    # Clamp speed to the MiniMax-supported range.
    $speed = [math]::Max(0.5, [math]::Min(2.0, $Rate))

    $voiceSetting = @{ speed = $speed }
    if ($Voice -and $Voice -ne "default") {
        $voiceSetting["voice_id"] = $Voice
    }

    $body = [ordered]@{
        model         = $model
        text          = $text
        stream        = $false
        voice_setting = $voiceSetting
        audio_setting = @{ format = $fmt }
    }
    $bodyJson = $body | ConvertTo-Json -Depth 6 -Compress

    if ($script:DryRun) {
        Write-Trace @{
            url          = $url
            region       = $region
            model        = $model
            format       = $fmt
            voice        = $Voice
            rate         = $Rate
            has_api_key  = [bool]$apiKey
            has_group_id = [bool]$groupId
            request      = $body
        }
        exit 0
    }

    if (-not $apiKey) {
        Write-DebugLine "MINIMAX_API_KEY not set -- skipping synthesis"
        exit 0
    }

    # The Authorization header carries the Bearer credential; it is never
    # written to stdout, stderr, or the trace file.
    $headers = @{ Authorization = "Bearer $apiKey" }
    try {
        $resp = Invoke-RestMethod -Uri $url -Method Post -Headers $headers `
            -ContentType "application/json" -Body $bodyJson -TimeoutSec 30
    } catch {
        Write-DebugLine "T2A request failed: $_"
        exit 0
    }

    $statusCode = $null
    if ($resp -and $resp.base_resp) { $statusCode = $resp.base_resp.status_code }
    if ($statusCode -ne 0) {
        Write-DebugLine "base_resp.status_code=$statusCode"
        exit 0
    }

    $audioHex = $null
    if ($resp -and $resp.data) { $audioHex = $resp.data.audio }
    if (-not $audioHex) {
        Write-DebugLine "response contained no audio"
        exit 0
    }

    try {
        $bytes = [byte[]]::new($audioHex.Length / 2)
        for ($i = 0; $i -lt $audioHex.Length; $i += 2) {
            $bytes[[int]($i / 2)] = [Convert]::ToByte($audioHex.Substring($i, 2), 16)
        }
    } catch {
        Write-DebugLine "hex decode failed: $_"
        exit 0
    }

    $tmp = Join-Path $env:TEMP ("peon-tts-minimax-" + [guid]::NewGuid().ToString('N').Substring(0, 8) + "." + $fmt)
    try {
        [System.IO.File]::WriteAllBytes($tmp, $bytes)
    } catch {
        Write-DebugLine "temp write failed: $_"
        exit 0
    }

    try {
        $winPlay = Join-Path $PSScriptRoot "win-play.ps1"
        if (Test-Path $winPlay) {
            & $winPlay -path $tmp -vol $Vol
        } else {
            Write-DebugLine "win-play.ps1 not found at $winPlay"
        }
    } catch {
        Write-DebugLine "playback failed: $_"
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }

    exit 0
}
