#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Crysis Sandbox 2 Editor (Bin32 / DX9)
# @raycast.mode silent
# @raycast.packageName Crysis
# @raycast.icon 🎮
# @raycast.description Fallback: Crysis Sandbox 2 Editor, 32-bit with DX9 forced

<#
  Fallback for launch-crysis-editor.ps1 (Bin64). Use this when the 64-bit
  editor misbehaves -- historically the more stable combo, at the cost of a
  32-bit address space that large levels can exhaust.

  -dx9 forces the D3D9 renderer instead of D3D10. Note that a DXVK v3.0.2
  d3d9.dll was in use here as of 11 Aug (see EditorLauncher_d3d9.log) but is no
  longer present in either Bin folder; Crysis Wars\Bin32 has dgVoodoo2 instead.
  If D3D9 behaves oddly, that missing wrapper is the first thing to check.

  Not elevated, same reasoning as the Bin64 script.
#>

$root       = 'F:\SteamLibrary\steamapps\common\Crysis'
$workingDir = Join-Path $root 'Bin32'
$editorPath = Join-Path $workingDir 'EditorLauncher.exe'

if (!(Test-Path $editorPath)) {
    Write-Host "EditorLauncher.exe not found at: $editorPath" -ForegroundColor Red
    exit 1
}

if (!(Test-Path (Join-Path $workingDir 'Editor.exe'))) {
    Write-Host "Editor.exe missing from $workingDir - EditorLauncher has nothing to load." -ForegroundColor Red
    exit 1
}

Start-Process -FilePath $editorPath -ArgumentList '-dx9' -WorkingDirectory $workingDir
