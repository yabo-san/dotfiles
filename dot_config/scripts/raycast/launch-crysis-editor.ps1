#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Crysis Sandbox 2 Editor
# @raycast.mode silent
# @raycast.packageName Crysis
# @raycast.icon 🎮
# @raycast.description Launch Crysis Sandbox 2 Editor (Bin64, 64-bit address space)

<#
  Base Crysis is the ONLY Sandbox 2 on this machine. Crysis Wars and Warhead
  ship no Editor.exe at all (Wars has a c1-launcher EditorLauncher.exe, but it
  is a ~60KB shim with nothing to load), and the engine builds differ anyway --
  Crysis 1.1.1.6156, Wars 1.1.1.6729, Warhead 1.1.1.711 -- so Editor.exe cannot
  be copied across. c1-launcher's patches are byte-offset specific per build.

  Bin64, not Bin32: Sandbox 2 32-bit runs out of address space on large levels.
  That was the reason to prefer Bin32 until c1-launcher v8 shipped "fix 64-bit
  crashes due to high memory usage" (#84). Use launch-crysis-editor-dx9.ps1 if
  the 64-bit build misbehaves.

  NOT elevated, deliberately. The install dir, Game\Levels and Editor\ are all
  writable as the normal user, and an elevated Sandbox window cannot accept
  drag-and-drop from a non-elevated Explorer (Windows UIPI blocks it) -- which
  is painful in a level editor.

  Requires c1-launcher v8+. v7 crashes on startup inside
  oleacc.AccessibleObjectFromWindow via ToolkitPro (Codejock Xtreme Toolkit)
  whenever any accessibility/UI-automation client pokes the Sandbox window.
  Fixed by ccomrade/c1-launcher#79.
#>

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
