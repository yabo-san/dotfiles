# Raycast Script Command (Windows / PowerShell)
# Name the monitor you're currently focused on. Point at a screen, run this, type
# "crt" - done. Everything else (place_game_window.py, evict/restore-crt, Playnite
# yabo:display= tags) refers to that friendly name, so GDI name drift stops mattering.
#
# WHY: \\.\DISPLAYn names are reassigned by driver resets and display-config changes.
# They already drifted to DISPLAY7/8/9 here, which silently broke evict-crt.ps1 and
# killed the [RC] Display: assignments on DOOM and The Dark Mod.
#
# Writes into the chezmoi SOURCE (dot_config/monitors.json), not the deployed copy -
# chezmoi stays the source of truth. Run `chezmoi apply` + commit afterwards.

# @raycast.schemaVersion 1
# @raycast.title Label Monitor
# @raycast.mode fullOutput
# @raycast.packageName Monitors
# @raycast.argument1 { "type": "text", "placeholder": "crt / ultrawide / acer" }

# Optional:
# @raycast.icon 🖥️
# @raycast.description Name the focused monitor so scripts can refer to it stably

param(
    [Parameter(Mandatory)] [string] $Label
)

$ErrorActionPreference = 'Stop'

$Label = $Label.Trim().ToLower()
if ($Label -notmatch '^[a-z0-9_-]+$') {
    Write-Host "Label must be letters/digits/dash/underscore (got: '$Label')" -ForegroundColor Red
    exit 1
}

$src = Join-Path $env:USERPROFILE '.local\share\chezmoi\dot_config\monitors.json'
if (-not (Test-Path $src)) { Write-Host "not found: $src" -ForegroundColor Red; exit 1 }

$mons = (glazewm query monitors | ConvertFrom-Json).data.monitors
$focused = $mons | Where-Object { $_.hasFocus } | Select-Object -First 1
if (-not $focused) {
    Write-Host "No monitor reports focus. Click on the screen you want to label, then retry." -ForegroundColor Yellow
    exit 1
}

$json = Get-Content $src -Raw | ConvertFrom-Json

$entry = [ordered]@{
    devicePath = [string]$focused.devicePath
    hardwareId = [string]$focused.hardwareId
    resolution = "$($focused.width)x$($focused.height)"
    note       = "labelled $(Get-Date -Format 'yyyy-MM-dd') from $($focused.deviceName)"
}

# A CRT with no EDID reports 'Default_Monitor' for every such panel - worse than
# useless as an identifier, because it would match the wrong screen. Drop it and
# let resolution carry the match.
if ($entry.hardwareId -eq 'Default_Monitor') { $entry.hardwareId = '' }

$json.monitors | Add-Member -NotePropertyName $Label -NotePropertyValue ([pscustomobject]$entry) -Force
$json | ConvertTo-Json -Depth 10 | Set-Content $src -Encoding UTF8

Write-Host "Labelled '$Label':" -ForegroundColor Green
Write-Host "  deviceName  $($focused.deviceName)   (drifts - not used for matching)" -ForegroundColor DarkGray
Write-Host "  devicePath  $($entry.devicePath)"
Write-Host "  hardwareId  $(if($entry.hardwareId){$entry.hardwareId}else{'(none - CRT with no EDID)'})"
Write-Host "  resolution  $($entry.resolution)"
Write-Host ""
Write-Host "All monitors currently known:" -ForegroundColor Cyan
$json.monitors.PSObject.Properties | ForEach-Object {
    Write-Host ("  {0,-12} {1}" -f $_.Name, $_.Value.note)
}
Write-Host ""
Write-Host "Written to the chezmoi source. Run: chezmoi apply  (then commit)" -ForegroundColor DarkGray
