param(
    [Parameter(Mandatory=$true)]
    [string]$body,
    [Parameter(Mandatory=$true)]
    [string]$title,
    [string]$iconPath,
    [int]$dismissSeconds = 4,
    [int]$parentPid = 0
)

# XML-escape helper: sanitize text for toast XML (mirrors notify.sh _escape_xml)
function Escape-Xml {
    param([string]$text)
    # Strip control characters (U+0000-U+0008, U+000B, U+000C, U+000E-U+001F)
    $text = $text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
    $text = $text.Replace('&', '&amp;')
    $text = $text.Replace('<', '&lt;')
    $text = $text.Replace('>', '&gt;')
    $text = $text.Replace('"', '&quot;')
    $text = $text.Replace("'", '&apos;')
    return $text
}

# --- Win32 P/Invoke for window focus activation ---
# First P/Invoke usage in the codebase (see ADR-001).
# Loaded via Add-Type -MemberDefinition; used by Set-WindowFocus.
Add-Type -MemberDefinition @'
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll")]
    public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("kernel32.dll")]
    public static extern uint GetCurrentThreadId();
'@ -Name Win32Focus -Namespace PeonPing -ErrorAction SilentlyContinue

# --- Focus helper functions ---

function Find-FocusableWindow {
    # Phase 1: process name priority chain
    # Returns the first process with a visible main window, or $null
    $names = @("Code", "Code - Insiders", "Cursor", "Windsurf", "WindowsTerminal", "powershell", "pwsh")
    foreach ($name in $names) {
        $proc = Get-Process -Name $name -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
            Select-Object -First 1
        if ($proc) { return $proc }
    }
    return $null
}

function Set-WindowFocus {
    param([IntPtr]$targetHwnd)
    # AttachThreadInput workaround for SetForegroundWindow restrictions.
    # Windows only allows the foreground process to call SetForegroundWindow.
    # We temporarily attach our thread to the foreground window's input queue.
    $fgHwnd = [PeonPing.Win32Focus]::GetForegroundWindow()
    $fgThreadId = [PeonPing.Win32Focus]::GetWindowThreadProcessId($fgHwnd, [ref]0)
    $curThreadId = [PeonPing.Win32Focus]::GetCurrentThreadId()
    if ($fgThreadId -ne $curThreadId) {
        [PeonPing.Win32Focus]::AttachThreadInput($curThreadId, $fgThreadId, $true) | Out-Null
    }
    [PeonPing.Win32Focus]::SetForegroundWindow($targetHwnd) | Out-Null
    if ($fgThreadId -ne $curThreadId) {
        [PeonPing.Win32Focus]::AttachThreadInput($curThreadId, $fgThreadId, $false) | Out-Null
    }
}

try {
    # PS 7+ cannot load WinRT types via ContentType=WindowsRuntime.
    # Delegate to powershell.exe (5.1) which has native WinRT support.
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $psArgs = @("-NoProfile", "-NonInteractive", "-File", $scriptPath,
                    "-body", $body, "-title", $title, "-dismissSeconds", $dismissSeconds,
                    "-parentPid", $parentPid)
        if ($iconPath) { $psArgs += @("-iconPath", $iconPath) }
        Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -WindowStyle Hidden
        exit 0
    }

    $safeBody = Escape-Xml $body
    $safeTitle = Escape-Xml $title

    # Build icon XML fragment if icon path provided and exists
    $iconXml = ""
    if ($iconPath -and (Test-Path $iconPath -PathType Leaf)) {
        $safeIcon = Escape-Xml $iconPath
        $iconXml = "<image placement=`"appLogoOverride`" src=`"$safeIcon`" />"
    }

    # Toast duration hint: "short" (~7s) or "long" (~25s)
    $duration = if ($dismissSeconds -gt 10) { "long" } else { "short" }

    # Build toast XML with launch attribute for click-to-focus activation (Phase 1 wires parentPid, Phase 2 uses it)
    # Audio silent because peon-ping plays its own sounds
    $toastXml = "<toast launch=`"parentPid=$parentPid`" duration=`"$duration`"><visual><binding template=`"ToastGeneric`"><text>$safeBody</text><text>$safeTitle</text>$iconXml</binding></visual><audio silent=`"true`" /></toast>"

    # Load WinRT types
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

    # APP_ID: PowerShell's AUMID (same as notify.sh WSL path)
    $APP_ID = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml

    # --- Toast activation event loop (click-to-focus) ---
    # Register Activated and Dismissed events before showing the toast.
    # Modeled on win-play.ps1 MediaPlayer event pattern (Register-ObjectEvent + poll loop).
    Register-ObjectEvent -InputObject $toast -EventName Activated -SourceIdentifier ToastActivated | Out-Null
    Register-ObjectEvent -InputObject $toast -EventName Dismissed -SourceIdentifier ToastDismissed | Out-Null

    # Show toast
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)

    # Wait for activation, dismissal, or timeout (dismissSeconds + 5s buffer)
    $deadline = [datetime]::UtcNow.AddSeconds($dismissSeconds + 5)
    while ([datetime]::UtcNow -lt $deadline) {
        $activated = Get-Event -SourceIdentifier ToastActivated -ErrorAction SilentlyContinue
        if ($activated) {
            $proc = Find-FocusableWindow
            if ($proc) { Set-WindowFocus $proc.MainWindowHandle }
            break
        }
        $dismissed = Get-Event -SourceIdentifier ToastDismissed -ErrorAction SilentlyContinue
        if ($dismissed) { break }
        Start-Sleep -Milliseconds 100
    }

    # Cleanup registered events
    Unregister-Event -SourceIdentifier ToastActivated -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier ToastDismissed -ErrorAction SilentlyContinue
} catch {
    # Silent degradation: notifications are best-effort
    exit 0
}
