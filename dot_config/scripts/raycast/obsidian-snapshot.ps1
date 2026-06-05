#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Snapshot Obsidian Config
# @raycast.mode silent
# @raycast.packageName Obsidian
# @raycast.icon 💾
# @raycast.description Save your WHOLE Obsidian config (incl per-plugin settings) as canonical

# Captures the full .obsidian config to the off-iCloud, git-backed canonical store the
# guard restores from. Run this whenever you deliberately change plugins/settings.
# Includes: top-level config JSONs (app/appearance/hotkeys/graph/daily-notes/plugins lists),
#           EVERY plugin's data.json (Templater, Dataview, etc. — the per-plugin settings),
#           themes/ and snippets/.
# Excludes: workspace*.json (ephemeral layout — the conflict-prone junk) and plugin CODE
#           (main.js/styles.css/manifest.json — re-installable, would bloat the repo).
$vault = "D:\iCloudDrive\iCloud~md~obsidian\sb\.obsidian"
$canon = "$env:USERPROFILE\.config\obsidian\config-backup"

# rebuild canonical fresh so removed plugins/settings don't linger
if (Test-Path $canon) { Remove-Item $canon -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $canon | Out-Null

# 1) top-level config JSONs, except ephemeral workspace*
Get-ChildItem $vault -Filter *.json -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike 'workspace*' } |
    ForEach-Object { Copy-Item $_.FullName (Join-Path $canon $_.Name) -Force }

# 2) per-plugin settings (data.json only — NOT the plugin code)
if (Test-Path "$vault\plugins") {
    Get-ChildItem "$vault\plugins" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $data = Join-Path $_.FullName 'data.json'
        if (Test-Path $data) {
            $dest = Join-Path $canon "plugins\$($_.Name)"
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item $data (Join-Path $dest 'data.json') -Force
        }
    }
}

# 3) appearance customization: themes + snippets
foreach ($sub in 'themes','snippets') {
    if (Test-Path "$vault\$sub") { Copy-Item "$vault\$sub" (Join-Path $canon $sub) -Recurse -Force }
}

Write-Host "[ok] snapshotted full Obsidian config -> $canon (incl per-plugin data.json)"
