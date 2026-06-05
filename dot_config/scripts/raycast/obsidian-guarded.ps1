#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Obsidian
# @raycast.mode silent
# @raycast.packageName Obsidian
# @raycast.icon 🪨
# @raycast.description Restore canonical .obsidian config (iCloud-clobber guard) then open the vault

# THE GUARD: iCloud on Windows keeps reverting .obsidian config (plugins/settings
# vanish). This restores the known-good config from a copy kept OUTSIDE iCloud
# (git-tracked in the dotfiles), THEN opens Obsidian — so every launch self-heals.
# Update the canonical with obsidian-snapshot.ps1 after intentional changes.
$vault = "D:\iCloudDrive\iCloud~md~obsidian\sb\.obsidian"
$canon = "$env:USERPROFILE\.config\obsidian\config-backup"
$files = 'community-plugins.json','core-plugins.json','app.json','appearance.json','hotkeys.json','graph.json','daily-notes.json'
foreach ($f in $files) {
    $src = Join-Path $canon $f
    if (Test-Path $src) { Copy-Item $src (Join-Path $vault $f) -Force -ErrorAction SilentlyContinue }
}
Start-Process "obsidian://open?vault=sb"
