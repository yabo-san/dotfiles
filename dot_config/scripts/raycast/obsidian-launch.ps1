#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Obsidian
# @raycast.mode silent
# @raycast.packageName Obsidian
# @raycast.icon 🪨
# @raycast.description Start iCloud sync daemon (if not running) then open the vault

$running = Get-Process python -ErrorAction SilentlyContinue | Where-Object {
    $_.CommandLine -like "*obsidian_sync*"
}
if (-not $running) {
    Start-Process python -ArgumentList "-m obsidian_sync --config D:\REPOS\obsidian-icloud-windows-sync\my-config.yaml" -WindowStyle Hidden
}

Start-Process "obsidian://open?vault=sb"
