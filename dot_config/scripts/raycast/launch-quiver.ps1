#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Quiver
# @raycast.mode silent
# @raycast.packageName Launchers
# @raycast.icon 🏹
# @raycast.description Open Quiver, the GitHub-release game launcher

<#
  Quiver is unpacked by chezmoi from its portable zip
  (.chezmoiexternals/launchers.toml.tmpl) into ~/.local/share/launchers/quiver.
  A portable Velopack build never creates a Start Menu shortcut, and chezmoi
  launchers stay out of the Start Menu on purpose, so Raycast finds it through
  this script instead. QuiverLauncher.exe at the root is Velopack's stub: it
  starts current\QuiverLauncher.exe, and survives Quiver's self-updates.
#>

$exe = Join-Path $env:USERPROFILE '.local\share\launchers\quiver\QuiverLauncher.exe'
if (-not (Test-Path $exe)) {
    Write-Host "Quiver is not installed. Run: chezmoi apply ~/.local/share/launchers/quiver"
    exit 1
}
Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe)
