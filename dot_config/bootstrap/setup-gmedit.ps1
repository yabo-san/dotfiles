#!/usr/bin/env pwsh
# setup-gmedit.ps1 — painless, RE-RUNNABLE GMEdit + Constructor install.
# Run it again any time to update Constructor / repair the install.
#
# Automates everything that CAN be: extract, Start Menu shortcut, plugin clone/update,
# runtime check. The only manual bits are inherent:
#   - GMEdit itself has no package/GitHub-release, so you download the zip once.
#   - GameMaker runtimes are account-gated (IDE feed), so installing a specific
#     runtime is an IDE click.
#
#   GMEdit itself is normally installed via the Playnite extension (it pulls the
#   build from itch.io), so this script's main job is the Constructor plugin +
#   runtime check — those work no matter WHERE GMEdit.exe lives (the plugin folder
#   is user-data under %APPDATA%\AceGM\GMEdit, independent of the install path).
#   The -Zip extraction below is just a fallback for a manual zip install.
#
#   Usage:  pwsh setup-gmedit.ps1                 (Constructor + runtime; extracts a
#                                                  Downloads zip only if GMEdit missing)
#           pwsh setup-gmedit.ps1 -Zip <zip>      (force-install GMEdit from a zip)
#           pwsh setup-gmedit.ps1 -Force          (re-extract over an existing install)
param([string]$Zip = "", [switch]$Force)
$ErrorActionPreference = 'Continue'
$dest    = "$env:LOCALAPPDATA\Programs\GMEdit"
$plugins = "$env:APPDATA\AceGM\GMEdit\plugins"

# 1) GMEdit — fallback manual extract. SKIP if already installed (Playnite/itch or a
#    prior run) unless -Force, so we never clobber a running GMEdit.
if (-not $Zip) {
    $Zip = (Get-ChildItem "D:\Downloads","$env:USERPROFILE\Downloads","$env:USERPROFILE\Desktop" `
            -Filter "*gmedit*windows*.zip" -EA SilentlyContinue | Select-Object -First 1).FullName
}
if ((Test-Path "$dest\GMEdit.exe") -and -not $Force) {
    Write-Host "[skip] GMEdit already installed at $dest — not re-extracting (use -Force to override)"
} elseif ($Zip -and (Test-Path $Zip)) {
    Get-Process GMEdit -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Expand-Archive -Path $Zip -DestinationPath $dest -Force
    Write-Host "[ok] extracted GMEdit -> $dest"
} else {
    Write-Host "[info] GMEdit not found here — it's normally installed via the Playnite"
    Write-Host "       extension (from itch.io). That's fine; continuing with the plugin."
}

# 2) Start Menu shortcut (so Raycast + Start Menu index it)
if (Test-Path "$dest\GMEdit.exe") {
    $lnk = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\GMEdit.lnk"
    $ws = New-Object -ComObject WScript.Shell; $sc = $ws.CreateShortcut($lnk)
    $sc.TargetPath = "$dest\GMEdit.exe"; $sc.WorkingDirectory = $dest; $sc.Save()
    Write-Host "[ok] Start Menu shortcut -> GMEdit"
}

# 3) GMEdit-Constructor plugin — clone, or git-pull to update
New-Item -ItemType Directory -Force -Path $plugins | Out-Null
$cdir = "$plugins\GMEdit-Constructor"
if (Test-Path "$cdir\.git") {
    git -C $cdir pull --ff-only 2>&1 | Out-Null; Write-Host "[ok] Constructor updated (git pull)"
} else {
    git clone https://github.com/thennothinghappened/GMEdit-Constructor $cdir 2>&1 | Out-Null
    Write-Host "[ok] Constructor cloned -> $cdir"
}

# 4) Runtime check (the version-pin gotcha)
$rt = "C:\ProgramData\GameMakerStudio2\Cache\runtimes"
Write-Host "`n[info] Installed GameMaker runtimes:"
Get-ChildItem $rt -Directory -EA SilentlyContinue | ForEach-Object { Write-Host "       $($_.Name)" }
Write-Host "[info] A project PINS a runtime version. If Constructor says 'no compatible"
Write-Host "       runtime', either install the matching one via the GameMaker IDE"
Write-Host "       (Preferences > Runtime Feeds) or override it in Constructor's Control"
Write-Host "       Panel (Ctrl+``). Runtimes are account-gated, so that step can't be scripted."
Write-Host "`n[done] Launch GMEdit from Raycast/Start. Constructor keys: F5 run, Ctrl+`` panel."
