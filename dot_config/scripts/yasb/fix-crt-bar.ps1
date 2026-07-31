<#
.SYNOPSIS
  Re-point yasb's CRT bar at whatever GDI device the CRT currently is.

.DESCRIPTION
  The CRT bar has to be targeted by GDI device name (\\.\DISPLAYn) because the
  CRT has NO EDID — it is absent from WmiMonitorID entirely, so it has no
  friendly name to match on the way the LG and the Acer do.

  And GDI numbers DRIFT. Every display-config change renumbers them: a GPU
  disable/re-enable, a driver reset, a game switching modes, a RustDesk session
  attaching. This exact bar has already been DISPLAY3, then DISPLAY9, then
  DISPLAY3 again. Each time it silently stops appearing — yasb does not warn
  about a screen that does not exist, the bar just never shows up.

  So stop hand-editing the number. This resolves the CRT by RESOLUTION (the only
  1024x768 display on this desk), writes that device name into the yasb config,
  and reloads yasb — but only when it actually changed.

  Run it after any display upset, and from startup. Idempotent: a no-op when the
  config already points at the right device.

.PARAMETER Width / Height
  How the CRT is identified. Change these if the CRT is ever replaced.
#>
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
    # Not an error: the CRT is legitimately off or unplugged sometimes, and this
    # runs from startup. Say so and leave the config alone.
    Write-Host "yasb-crt: no ${Width}x${Height} display attached — leaving config alone." -ForegroundColor DarkGray
    exit 0
}

$device = $crt.DeviceName          # e.g. \\.\DISPLAY3

if (-not (Test-Path $ConfigPath)) {
    Write-Host "yasb-crt: no config at $ConfigPath" -ForegroundColor Red
    exit 1
}

# The CRT bar is the ONLY screens: line naming a raw \\.\DISPLAY device — the
# other bars match on friendly EDID names — so that is a safe anchor.
$lines = Get-Content $ConfigPath
$idx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*screens:\s*\[\s*"\\\\\\\\\.\\\\DISPLAY\d+"\s*\]') { $idx = $i; break }
}

if ($idx -lt 0) {
    Write-Host "yasb-crt: could not find the CRT bar's screens: line in $ConfigPath" -ForegroundColor Red
    Write-Host "          (expected a line like: screens: [`"\\\\.\\DISPLAY3`"])" -ForegroundColor DarkGray
    exit 1
}

# YAML double-quoted: every backslash is doubled, so \\.\DISPLAY3 is written
# \\\\.\\DISPLAY3 in the file.
$yamlDevice = $device -replace '\\', '\\'
$current = if ($lines[$idx] -match 'DISPLAY(\d+)') { "\\.\DISPLAY$($Matches[1])" } else { '?' }

if ($current -eq $device) {
    Write-Host "yasb-crt: already pointing at $device — nothing to do." -ForegroundColor DarkGray
    exit 0
}

$indent  = ([regex]::Match($lines[$idx], '^\s*')).Value
$newLine = "${indent}screens: [`"$yamlDevice`"]   # the 4:3 CRT — set by fix-crt-bar.ps1"

Write-Host "yasb-crt: CRT moved $current -> $device" -ForegroundColor Yellow

if ($WhatIfOnly) {
    Write-Host "  would write: $newLine" -ForegroundColor DarkGray
    exit 0
}

$lines[$idx] = $newLine
Set-Content -Path $ConfigPath -Value $lines -Encoding UTF8
Write-Host "  config updated." -ForegroundColor Green

# Reload so the bar comes back now rather than at next login.
$yasbc = 'C:\Program Files\YASB\yasbc.exe'
if (Test-Path $yasbc) {
    & $yasbc reload | Out-Null
    Write-Host "  yasb reloaded." -ForegroundColor Green
} else {
    Write-Host "  yasbc not found — restart yasb manually." -ForegroundColor DarkYellow
}

# The chezmoi source is the thing that survives a re-apply; if only the deployed
# copy is fixed, the next `chezmoi apply` puts the stale number straight back.
$src = "$env:USERPROFILE\.local\share\chezmoi\dot_config\yasb\config.yaml"
if ((Test-Path $src) -and ($src -ne $ConfigPath)) {
    $s = Get-Content $src
    for ($i = 0; $i -lt $s.Count; $i++) {
        if ($s[$i] -match '^\s*screens:\s*\[\s*"\\\\\\\\\.\\\\DISPLAY\d+"\s*\]') {
            $si = ([regex]::Match($s[$i], '^\s*')).Value
            $s[$i] = "${si}screens: [`"$yamlDevice`"]   # the 4:3 CRT — set by fix-crt-bar.ps1"
            Set-Content -Path $src -Value $s -Encoding UTF8
            Write-Host "  chezmoi source updated too (so apply won't undo it)." -ForegroundColor Green
            break
        }
    }
}
