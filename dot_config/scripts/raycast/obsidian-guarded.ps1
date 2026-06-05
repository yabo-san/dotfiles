#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Obsidian
# @raycast.mode silent
# @raycast.packageName Obsidian
# @raycast.icon 🪨
# @raycast.description Restore the FULL .obsidian config (iCloud-clobber guard) then open the vault

# THE GUARD: iCloud-on-Windows reverts .obsidian config (plugins/settings vanish). This
# restores the known-good config from the off-iCloud, git-backed canonical, THEN opens
# Obsidian — so every launch self-heals. Restores the WHOLE config: top-level JSONs,
# every plugin's data.json (Templater, Dataview, etc.), themes/snippets. Leaves
# workspace*.json alone (ephemeral layout). Update canonical via obsidian-snapshot.ps1.
$vault = "D:\iCloudDrive\iCloud~md~obsidian\sb\.obsidian"
$canon = "$env:USERPROFILE\.config\obsidian\config-backup"

if (Test-Path $canon) {
    # 1) top-level config JSONs
    Get-ChildItem $canon -Filter *.json -File -ErrorAction SilentlyContinue |
        ForEach-Object { Copy-Item $_.FullName (Join-Path $vault $_.Name) -Force -ErrorAction SilentlyContinue }

    # 2) per-plugin settings (data.json)
    if (Test-Path "$canon\plugins") {
        Get-ChildItem "$canon\plugins" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $data = Join-Path $_.FullName 'data.json'
            if (Test-Path $data) {
                $dest = Join-Path $vault "plugins\$($_.Name)"
                New-Item -ItemType Directory -Force -Path $dest | Out-Null
                Copy-Item $data (Join-Path $dest 'data.json') -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # 3) themes + snippets
    foreach ($sub in 'themes','snippets') {
        if (Test-Path "$canon\$sub") { Copy-Item "$canon\$sub" (Join-Path $vault $sub) -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Start-Process "obsidian://open?vault=sb"
