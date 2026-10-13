#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Crysis Sandbox 2 Editor
# @raycast.mode silent
# @raycast.packageName Crysis
# @raycast.icon 🎮
# @raycast.description Launch Crysis Sandbox 2 Editor (Bin64, 64-bit address space)

# Raycast command: opens the Crysis Sandbox 2 editor (64-bit) through c1-launcher.
# Needs c1-launcher v8+ (v7 crashes in oleacc). Not elevated, so drag-and-drop from Explorer works.

$root       = 'F:\SteamLibrary\steamapps\common\Crysis'
$workingDir = Join-Path $root 'Bin64'
$editorPath = Join-Path $workingDir 'EditorLauncher.exe'

if (!(Test-Path $editorPath)) {
    Write-Host "EditorLauncher.exe not found at: $editorPath" -ForegroundColor Red
    exit 1
}

if (!(Test-Path (Join-Path $workingDir 'Editor.exe'))) {
    Write-Host "Editor.exe missing from $workingDir - EditorLauncher has nothing to load." -ForegroundColor Red
    exit 1
}

$ver = (Get-Item $editorPath).VersionInfo.FileVersion
if ($ver -match 'v([0-9]+)' -and [int]$Matches[1] -lt 8) {
    Write-Host "EditorLauncher is $ver - v8+ required (v7 crashes in oleacc). Update from ccomrade/c1-launcher." -ForegroundColor Yellow
}

Start-Process -FilePath $editorPath -WorkingDirectory $workingDir
