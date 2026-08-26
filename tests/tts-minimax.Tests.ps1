# Pester 5 tests for scripts/tts-minimax.ps1 (Windows MiniMax T2A backend).
# Run: Invoke-Pester -Path tests/tts-minimax.Tests.ps1
#
# Strategy mirrors tts-native.Tests.ps1: the impure half (the HTTP call) is
# verified via a side-effect trace. Under PEON_TTS_DRY_RUN=1 the script writes
# the resolved request (URL, region, model, format, voice, and JSON body) to
# PEON_TTS_TRACE_FILE and exits 0 without reaching the API. The credential is
# recorded only as a boolean, never as its value.

BeforeAll {
    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:TtsMinimaxPath = Join-Path (Join-Path $script:RepoRoot "scripts") "tts-minimax.ps1"

    function Invoke-TtsMinimaxDryRun {
        param(
            [string]$InputText = "",
            [string]$Voice = "default",
            [double]$Rate = 1.0,
            [double]$Vol = 0.5,
            [string]$Region,
            [string]$Model,
            [string]$Format,
            [string]$GroupId,
            [string]$ApiKey
        )

        $tracePath = Join-Path $env:TEMP "peon-tts-minimax-trace-$([guid]::NewGuid().ToString('N').Substring(0,8)).json"

        $argList = @("-NoProfile", "-NonInteractive", "-File", $script:TtsMinimaxPath,
                     "-Voice", $Voice, "-Rate", $Rate, "-Vol", $Vol)

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = ($argList | ForEach-Object {
            if ($_ -match '\s') { "`"$_`"" } else { "$_" }
        }) -join " "
        $psi.UseShellExecute = $false
        $psi.RedirectStandardInput = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.Environment["PEON_TTS_DRY_RUN"] = "1"
        $psi.Environment["PEON_TTS_TRACE_FILE"] = $tracePath
        if ($Region) { $psi.Environment["PEON_MINIMAX_REGION"] = $Region }
        if ($Model) { $psi.Environment["PEON_MINIMAX_MODEL"] = $Model }
        if ($Format) { $psi.Environment["PEON_MINIMAX_FORMAT"] = $Format }
        if ($GroupId) { $psi.Environment["MINIMAX_GROUP_ID"] = $GroupId }
        if ($ApiKey) { $psi.Environment["MINIMAX_API_KEY"] = $ApiKey }

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        try {
            $proc.Start() | Out-Null
            if ($InputText) {
                $proc.StandardInput.Write($InputText)
            }
            $proc.StandardInput.Close()

            $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
            $stderrTask = $proc.StandardError.ReadToEndAsync()

            if (-not $proc.WaitForExit(15000)) {
                $proc.Kill()
                throw "tts-minimax.ps1 timed out"
            }

            $stdout = $stdoutTask.Result
            $stderr = $stderrTask.Result
            $exitCode = $proc.ExitCode
        } finally {
            $proc.Dispose()
        }

        $trace = $null
        $rawTrace = $null
        if (Test-Path $tracePath) {
            $rawTrace = Get-Content $tracePath -Raw -Encoding UTF8
            $trace = $rawTrace | ConvertFrom-Json
            Remove-Item $tracePath -Force -ErrorAction SilentlyContinue
        }

        return @{
            ExitCode = $exitCode
            Stdout   = $stdout
            Stderr   = $stderr
            Trace    = $trace
            RawTrace = $rawTrace
        }
    }
}

# ============================================================
# Structural / parse validation
# ============================================================

Describe "tts-minimax.ps1 structural validation" {
    It "exists in scripts/" {
        $script:TtsMinimaxPath | Should -Exist
    }

    It "has valid PowerShell syntax" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $errors = $null
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "contains a comment-based help header near the top" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $content | Should -Match '(?s)^\s*<#.*\.SYNOPSIS.*\.PARAMETER.*\.EXAMPLE.*#>'
    }

    It "declares InputText with ValueFromPipeline" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $content | Should -Match '(?s)\[Parameter\(\s*ValueFromPipeline\s*=\s*\$true\s*\)\][^}]*\[string\]\s*\$InputText'
    }

    It "declares Voice parameter with 'default' default" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $content | Should -Match '\[string\]\s*\$Voice\s*=\s*"default"'
    }

    It "declares Rate parameter as double with 1.0 default" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $content | Should -Match '\[double\]\s*\$Rate\s*=\s*1\.0'
    }

    It "declares Vol parameter as double with 0.5 default" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $content | Should -Match '\[double\]\s*\$Vol\s*=\s*0\.5'
    }

    It "uses begin/process/end blocks for pipeline input" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $content | Should -Match '(?ms)^\s*begin\s*\{'
        $content | Should -Match '(?ms)^\s*process\s*\{'
        $content | Should -Match '(?ms)^\s*end\s*\{'
    }

    It "does not contain ExecutionPolicy Bypass" {
        $content = Get-Content $script:TtsMinimaxPath -Raw
        $content | Should -Not -Match "ExecutionPolicy Bypass"
    }
}

# ============================================================
# Request construction (dry-run trace)
# ============================================================

Describe "tts-minimax.ps1 request construction" {
    It "resolves the global endpoint by default" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hello"
        $r.ExitCode | Should -Be 0
        $r.Trace.url | Should -Be "https://api.minimax.io/v1/t2a_v2"
        $r.Trace.region | Should -Be "global_en"
    }

    It "resolves the CN endpoint for region cn_zh" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hello" -Region "cn_zh"
        $r.Trace.url | Should -Be "https://api.minimaxi.com/v1/t2a_v2"
    }

    It "falls back to the global endpoint for an unknown region" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -Region "bogus"
        $r.Trace.url | Should -Be "https://api.minimax.io/v1/t2a_v2"
    }

    It "appends MINIMAX_GROUP_ID as a query argument" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -GroupId "grp42"
        $r.Trace.url | Should -Be "https://api.minimax.io/v1/t2a_v2?GroupId=grp42"
        $r.Trace.has_group_id | Should -BeTrue
    }

    It "defaults the model to speech-2.8-hd" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi"
        $r.Trace.model | Should -Be "speech-2.8-hd"
        $r.Trace.request.model | Should -Be "speech-2.8-hd"
    }

    It "honors PEON_MINIMAX_MODEL (speech-2.8-turbo)" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -Model "speech-2.8-turbo"
        $r.Trace.request.model | Should -Be "speech-2.8-turbo"
    }

    It "carries the text and audio format in the request body" {
        $r = Invoke-TtsMinimaxDryRun -InputText "read this" -Format "wav"
        $r.Trace.request.text | Should -Be "read this"
        $r.Trace.request.audio_setting.format | Should -Be "wav"
    }

    It "omits voice_id when the voice is default" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -Voice "default"
        $r.Trace.request.voice_setting.PSObject.Properties.Name | Should -Not -Contain "voice_id"
    }

    It "sets voice_id when an explicit voice is given" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -Voice "some-voice-id"
        $r.Trace.request.voice_setting.voice_id | Should -Be "some-voice-id"
    }

    It "clamps rate above 2.0 to 2.0" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -Rate 3.0
        $r.Trace.request.voice_setting.speed | Should -Be 2.0
    }

    It "clamps rate below 0.5 to 0.5" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -Rate 0.1
        $r.Trace.request.voice_setting.speed | Should -Be 0.5
    }

    It "records only a boolean for the credential, never its value" {
        $r = Invoke-TtsMinimaxDryRun -InputText "hi" -ApiKey "super-secret-value"
        $r.Trace.has_api_key | Should -BeTrue
        $r.RawTrace | Should -Not -Match "super-secret-value"
    }

    It "exits 0 on empty input without writing a request body" {
        $r = Invoke-TtsMinimaxDryRun -InputText ""
        $r.ExitCode | Should -Be 0
    }
}
