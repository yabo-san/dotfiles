<#
.SYNOPSIS
  Make sure RetroArch's config points at the CRT.

.DESCRIPTION
  RetroArch chooses its screen with video_monitor_index in retroarch.cfg: a 1-based
  position in the Windows monitor enumeration. That position drifts with the same
  events that renumber \\.\DISPLAYn (a GPU reset, the DP-to-VGA adapter dropping
  out and being replugged, a primary change). Wild Guns opened on the Acer on
  2026-10-03 because the CRT had moved from 2 to 3 (CHG0030446).

  This resolves the CRT by its resolution, the only stable fact about an EDID-less
  monitor, and rewrites the index when it differs. Same idea and same trigger as
  yasb's fix-crt-bar.ps1: runs at logon from the startup shortcut, and by hand
  (Raycast "Bind CRT") after a display upset. Skipped while RetroArch is running,
  because it rewrites retroarch.cfg on exit and would undo the change.

  Touches no display setting. Reads the layout, edits one line in one text file.

.PARAMETER Width / Height
  How the CRT is identified. Change these if the CRT is ever replaced.
#>
[CmdletBinding()]
param(
    [int]$Width = 1024,
    [int]$Height = 768,
    [string]$ConfigPath = (Join-Path ${env:ProgramFiles(x86)} 'Steam\steamapps\common\RetroArch\retroarch.cfg'),
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ConfigPath)) {
    Write-Host "retroarch-crt: no retroarch.cfg at $ConfigPath - nothing to do." -ForegroundColor DarkGray
    exit 0
}

if (Get-Process retroarch -ErrorAction SilentlyContinue) {
    Write-Host "retroarch-crt: RetroArch is running - leaving its config alone (it rewrites the file on exit)." -ForegroundColor DarkGray
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
$screens = [System.Windows.Forms.Screen]::AllScreens
$index = 0
for ($i = 0; $i -lt $screens.Count; $i++) {
    if ($screens[$i].Bounds.Width -eq $Width -and $screens[$i].Bounds.Height -eq $Height) { $index = $i + 1; break }
}

if ($index -eq 0) {
    # Not an error: the CRT is legitimately off or unplugged sometimes, and this runs from startup.
    Write-Host "retroarch-crt: no ${Width}x${Height} display attached - leaving config alone." -ForegroundColor DarkGray
    exit 0
}

$text = [System.IO.File]::ReadAllText($ConfigPath)
$current = if ($text -match '(?m)^video_monitor_index = "(\d+)"') { [int]$Matches[1] } else { -1 }

if ($current -eq $index) {
    Write-Host "retroarch-crt: video_monitor_index already $index - nothing to do." -ForegroundColor DarkGray
    exit 0
}

Write-Host "retroarch-crt: CRT is monitor $index (config said $current)" -ForegroundColor Yellow
if ($WhatIfOnly) {
    Write-Host "  would set video_monitor_index = `"$index`"" -ForegroundColor DarkGray
    exit 0
}

$new = [regex]::Replace($text, '(?m)^video_monitor_index = "\d+"', ('video_monitor_index = "{0}"' -f $index))
[System.IO.File]::WriteAllText($ConfigPath, $new)
Write-Host "  retroarch.cfg updated." -ForegroundColor Green
