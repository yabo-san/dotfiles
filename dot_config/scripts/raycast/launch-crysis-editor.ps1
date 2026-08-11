#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Crysis Sandbox 2 Editor
# @raycast.mode silent
# @raycast.packageName Crysis
# @raycast.icon 🎮
# @raycast.description Launch Crysis Sandbox 2 Editor (Bin32 + DX9, the stable combo)

$editorPath = "F:\SteamLibrary\steamapps\common\Crysis\Bin32\EditorLauncher.exe"
$workingDir = "F:\SteamLibrary\steamapps\common\Crysis\Bin32"

if (!(Test-Path $editorPath)) {
    Write-Host "EditorLauncher.exe not found at: $editorPath" -ForegroundColor Red
    exit 1
}

Start-Process -FilePath $editorPath -ArgumentList "-dx9" -WorkingDirectory $workingDir -Verb RunAs
