#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Chisel Rockwall Editor
# @raycast.mode silent
# @raycast.packageName Chisel
# @raycast.icon 🔨
# @raycast.description Launch Rockwall Editor 

# Raycast command: opens the Rockwall editor for chisel under D/Repos/Chisel

$workingDir = 'D:\REPOS\chisel\Tools\Rockwall'
$editorPath = Join-Path $workingDir 'Rockwall2.exe'

if (!(Test-Path $editorPath)) {
    Write-Host "Rockwall2.exe not found at: $editorPath" -ForegroundColor Red
    exit 1
}

Start-Process -FilePath $editorPath -WorkingDirectory $workingDir
