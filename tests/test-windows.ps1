# Simple test script for peon-ping Windows installation
# Usage: powershell -ExecutionPolicy Bypass -File .\test-windows.ps1

$ErrorActionPreference = "Continue"

Write-Host "=== peon-ping Windows Test Suite ===" -ForegroundColor Cyan
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Item {
    param([string]$Name, [scriptblock]$Check)
    Write-Host -NoNewline "Testing: $Name... "
    try {
        $result = & $Check
        if ($result) {
            Write-Host "PASS" -ForegroundColor Green
            $script:testsPassed++
        } else {
            Write-Host "FAIL" -ForegroundColor Red
            $script:testsFailed++
        }
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Red
        $script:testsFailed++
    }
}

# Test 1: Python is installed
Test-Item "Python installation" {
    $null -ne (Get-Command python -ErrorAction SilentlyContinue) -or
    $null -ne (Get-Command python3 -ErrorAction SilentlyContinue)
}

# Test 2: Claude directory exists
Test-Item "Claude Code directory" {
    Test-Path "$env:USERPROFILE\.claude"
}

# Test 3: PowerShell version
Test-Item "PowerShell version >= 5.1" {
    $PSVersionTable.PSVersion.Major -ge 5
}

# Test 4: .NET assemblies can be loaded
Test-Item "System.Windows.Media assembly" {
    try {
        Add-Type -AssemblyName PresentationCore
        $true
    } catch {
        $false
    }
}

Test-Item "System.Windows.Forms assembly" {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $true
    } catch {
        $false
    }
}

# Test 5: If installed, check installation files
if (Test-Path "$env:USERPROFILE\.claude\hooks\peon-ping") {
    Write-Host ""
    Write-Host "Installation detected. Checking files..." -ForegroundColor Yellow

    Test-Item "peon.ps1 exists" {
        Test-Path "$env:USERPROFILE\.claude\hooks\peon-ping\peon.ps1"
    }

    Test-Item "config.json exists" {
        Test-Path "$env:USERPROFILE\.claude\hooks\peon-ping\config.json"
    }

    Test-Item "config.json is valid JSON" {
        try {
            $config = Get-Content "$env:USERPROFILE\.claude\hooks\peon-ping\config.json" -Raw | ConvertFrom-Json
            $null -ne $config
        } catch {
            $false
        }
    }

    Test-Item "Sound packs directory exists" {
        Test-Path "$env:USERPROFILE\.claude\hooks\peon-ping\packs"
    }

    Test-Item "Default pack (peon) has sounds" {
        $soundDir = "$env:USERPROFILE\.claude\hooks\peon-ping\packs\peon\sounds"
        if (Test-Path $soundDir) {
            $sounds = Get-ChildItem -Path $soundDir -Filter *.* | Where-Object { $_.Extension -in @('.wav','.mp3','.ogg') }
            $sounds.Count -gt 0
        } else {
            $false
        }
    }

    Test-Item "settings.json has hooks configured" {
        try {
            $settings = Get-Content "$env:USERPROFILE\.claude\settings.json" -Raw -ErrorAction Stop | ConvertFrom-Json
            $hooks = $settings.hooks
            $null -ne $hooks.SessionStart -or $null -ne $hooks.Stop
        } catch {
            $false
        }
    }

    Test-Item "peon function in PowerShell profile" {
        if (Test-Path $PROFILE) {
            $profileContent = Get-Content $PROFILE -Raw
            $profileContent -match "function peon"
        } else {
            $false
        }
    }

    # Test peon command
    Write-Host ""
    Write-Host "Testing peon command..." -ForegroundColor Yellow

    # Source the profile if it exists
    if (Test-Path $PROFILE) {
        . $PROFILE 2>$null
    }

    Test-Item "peon --help works" {
        try {
            powershell.exe -ExecutionPolicy Bypass -Command "$env:USERPROFILE\.claude\hooks\peon-ping\peon.ps1 --help" 2>$null | Out-Null
            $LASTEXITCODE -eq 0
        } catch {
            $false
        }
    }

    Test-Item "peon --status works" {
        try {
            $output = powershell.exe -ExecutionPolicy Bypass -Command "$env:USERPROFILE\.claude\hooks\peon-ping\peon.ps1 --status" 2>$null
            $output -match "peon-ping:"
        } catch {
            $false
        }
    }

    Test-Item "peon --packs works" {
        try {
            $output = powershell.exe -ExecutionPolicy Bypass -Command "$env:USERPROFILE\.claude\hooks\peon-ping\peon.ps1 --packs" 2>$null
            $null -ne $output
        } catch {
            $false
        }
    }
} else {
    Write-Host ""
    Write-Host "peon-ping not installed. Skipping installation tests." -ForegroundColor Yellow
}

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor Red

if ($testsFailed -eq 0) {
    Write-Host ""
    Write-Host "All tests passed! OK" -ForegroundColor Green
    if (-not (Test-Path "$env:USERPROFILE\.claude\hooks\peon-ping")) {
        Write-Host ""
        Write-Host "Ready to install peon-ping:" -ForegroundColor Yellow
        Write-Host "  irm https://raw.githubusercontent.com/tonyyont/peon-ping/main/install.ps1 | iex"
    }
    exit 0
} else {
    Write-Host ""
    Write-Host "Some tests failed. Please check the errors above." -ForegroundColor Red
    exit 1
}
