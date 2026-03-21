param(
    [Parameter(Mandatory=$true)]
    [string]$body,
    [Parameter(Mandatory=$true)]
    [string]$title,
    [string]$iconPath,
    [int]$dismissSeconds = 4
)

# XML-escape helper: sanitize text for toast XML (mirrors notify.sh _escape_xml)
function Escape-Xml {
    param([string]$text)
    # Strip control characters (U+0000–U+0008, U+000B, U+000C, U+000E–U+001F)
    $text = $text -replace '[\x00-\x08\x0B\x0C\x0E-\x1F]', ''
    $text = $text.Replace('&', '&amp;')
    $text = $text.Replace('<', '&lt;')
    $text = $text.Replace('>', '&gt;')
    $text = $text.Replace('"', '&quot;')
    $text = $text.Replace("'", '&apos;')
    return $text
}

try {
    # PS 7+ cannot load WinRT types via ContentType=WindowsRuntime.
    # Delegate to powershell.exe (5.1) which has native WinRT support.
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $scriptPath = $MyInvocation.MyCommand.Path
        $psArgs = @("-NoProfile", "-NonInteractive", "-File", $scriptPath,
                    "-body", $body, "-title", $title, "-dismissSeconds", $dismissSeconds)
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

    # Build toast XML matching notify.sh format — audio silent because peon-ping plays its own sounds
    $toastXml = "<toast duration=`"$duration`"><visual><binding template=`"ToastGeneric`"><text>$safeBody</text><text>$safeTitle</text>$iconXml</binding></visual><audio silent=`"true`" /></toast>"

    # Load WinRT types
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

    # APP_ID: PowerShell's AUMID (same as notify.sh WSL path)
    $APP_ID = "{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe"

    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($toastXml)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
} catch {
    # Silent degradation: notifications are best-effort
    exit 0
}
