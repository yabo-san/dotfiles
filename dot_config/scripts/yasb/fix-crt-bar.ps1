# Points yasb's CRT bar at the CRT's current DISPLAYn device and reloads yasb. Run at logon by a Startup shortcut.
# The CRT has no EDID, so it is found by resolution, and GDI display numbers change after any display reset.
[CmdletBinding()]
param(
    [int]$Width = 1024,
    [int]$Height = 768,
    [string]$ConfigPath = "$env:USERPROFILE\.config\yasb\config.yaml",
    [switch]$WhatIfOnly
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms

$crt = [System.Windows.Forms.Screen]::AllScreens |
    Where-Object { $_.Bounds.Width -eq $Width -and $_.Bounds.Height -eq $Height } |
    Select-Object -First 1

if (-not $crt) {
    # Not an error: the CRT is sometimes off, and this runs at logon.
    Write-Host "yasb-crt: no ${Width}x${Height} display attached - leaving config alone." -ForegroundColor DarkGray
    exit 0
}

$device = $crt.DeviceName          # e.g. \\.\DISPLAY3

if (-not (Test-Path $ConfigPath)) {
    Write-Host "yasb-crt: no config at $ConfigPath" -ForegroundColor Red
    exit 1
}

# The CRT bar is the only screens: line with a raw DISPLAYn device name; the other bars use EDID names.
# Explicit UTF-8 without BOM: Windows PowerShell 5.1 would otherwise read it as Windows-1252 and garble the icons.
$utf8 = New-Object System.Text.UTF8Encoding $false
$lines = [System.IO.File]::ReadAllLines($ConfigPath, $utf8)
$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*screens:\s*\[\s*"\\\\\\\\\.\\\\DISPLAY\d+"\s*\]') { $idx = $i; break }
}

if ($idx -lt 0) {
    Write-Host "yasb-crt: could not find the CRT bar's screens: line in $ConfigPath" -ForegroundColor Red
    Write-Host "          (expected a line like: screens: [`"\\\\.\\DISPLAY3`"])" -ForegroundColor DarkGray
    exit 1
}

# YAML double-quoted strings double every backslash.
$yamlDevice = $device -replace '\\', '\\'
$current = if ($lines[$idx] -match 'DISPLAY(\d+)') { "\\.\DISPLAY$($Matches[1])" } else { '?' }

if ($current -eq $device) {
    Write-Host "yasb-crt: already pointing at $device - nothing to do." -ForegroundColor DarkGray
    exit 0
}

$indent  = ([regex]::Match($lines[$idx], '^\s*')).Value
$newLine = "${indent}screens: [`"$yamlDevice`"]   # the 4:3 CRT - set by fix-crt-bar.ps1"

Write-Host "yasb-crt: CRT moved $current -> $device" -ForegroundColor Yellow

if ($WhatIfOnly) {
    Write-Host "  would write: $newLine" -ForegroundColor DarkGray
    exit 0
}

$lines[$idx] = $newLine
[System.IO.File]::WriteAllLines($ConfigPath, $lines, $utf8)
Write-Host "  config updated." -ForegroundColor Green

# Reload so the bar comes back now rather than at next login.
$yasbc = 'C:\Program Files\YASB\yasbc.exe'
if (Test-Path $yasbc) {
    & $yasbc reload | Out-Null
    Write-Host "  yasb reloaded." -ForegroundColor Green
} else {
    Write-Host "  yasbc not found - restart yasb manually." -ForegroundColor DarkYellow
}

# Fix the chezmoi source too, or the next apply puts the stale number back.
$src = "$env:USERPROFILE\.local\share\chezmoi\dot_config\yasb\config.yaml"
if ((Test-Path $src) -and ($src -ne $ConfigPath)) {
    $s = [System.IO.File]::ReadAllLines($src, $utf8)
    for ($i = 0; $i -lt $s.Count; $i++) {
        if ($s[$i] -match '^\s*screens:\s*\[\s*"\\\\\\\\\.\\\\DISPLAY\d+"\s*\]') {
            $si = ([regex]::Match($s[$i], '^\s*')).Value
            $s[$i] = "${si}screens: [`"$yamlDevice`"]   # the 4:3 CRT - set by fix-crt-bar.ps1"
            [System.IO.File]::WriteAllLines($src, $s, $utf8)
            Write-Host "  chezmoi source updated too (so apply won't undo it)." -ForegroundColor Green
            break
        }
    }
}
