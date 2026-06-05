#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Snapshot Obsidian Config
# @raycast.mode silent
# @raycast.packageName Obsidian
# @raycast.icon 💾
# @raycast.description Save current .obsidian config as canonical — run AFTER you intentionally change plugins/settings

# Captures your current Obsidian config to the off-iCloud canonical store the guard
# restores from. Run this whenever you deliberately enable a plugin / change a
# setting, so the guard doesn't revert your intended change.
$vault = "D:\iCloudDrive\iCloud~md~obsidian\sb\.obsidian"
$canon = "$env:USERPROFILE\.config\obsidian\config-backup"
$files = 'community-plugins.json','core-plugins.json','app.json','appearance.json','hotkeys.json','graph.json','daily-notes.json'
New-Item -ItemType Directory -Force -Path $canon | Out-Null
foreach ($f in $files) {
    $src = Join-Path $vault $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $canon $f) -Force -ErrorAction SilentlyContinue }
}
