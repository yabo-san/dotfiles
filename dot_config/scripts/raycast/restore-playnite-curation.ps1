# Raycast Script Command (Windows / PowerShell)
# Arm the curation restore, then start Playnite.
#
# Playnite's library DB is deliberately NOT carried by clone-my-playnite.ps1 (it
# scrubs library\*.db as [secret]), so a rebuilt machine imports games with no
# tags — and the Playnite -> GlazeWM integration reads tags. This puts them back
# from dot_config/playnite/curation.json.
#
# The work happens INSIDE Playnite via the "Application started" script, using
# $PlayniteApi rather than writing LiteDB behind a running app. All this command
# does is drop the marker that tells it to act, and launch Playnite.
#
# Non-destructive: the restore only ever ADDS tags/features, never removes.

# @raycast.schemaVersion 1
# @raycast.title Restore Playnite Curation
# @raycast.mode fullOutput
# @raycast.packageName Playnite

# Optional:
# @raycast.icon 🏷️
# @raycast.description Re-apply exported tags/features to the Playnite library

$ErrorActionPreference = 'Stop'

$curation = Join-Path $env:USERPROFILE '.config\playnite\curation.json'
$marker   = Join-Path $env:USERPROFILE '.config\playnite\.restore-pending'

if (-not (Test-Path $curation)) {
    Write-Host "No curation export found at:" -ForegroundColor Red
    Write-Host "  $curation"
    Write-Host "Run export-curation.ps1 first (with Playnite closed)." -ForegroundColor Yellow
    exit 1
}

$data = Get-Content $curation -Raw | ConvertFrom-Json
Write-Host "Curation export: $($data.gameCount) games, taken $($data.exportedAt)" -ForegroundColor Cyan

if (Get-Process 'Playnite*' -ErrorAction SilentlyContinue) {
    Write-Host "Playnite is running — close it first, then re-run this." -ForegroundColor Yellow
    Write-Host "(the restore runs during Playnite's startup)" -ForegroundColor DarkGray
    exit 1
}

New-Item -ItemType Directory -Force (Split-Path $marker) | Out-Null
Set-Content -Path $marker -Value "armed $(Get-Date -Format o)" -Encoding UTF8
Write-Host "Armed. Starting Playnite — the restore runs during startup." -ForegroundColor Green

$exe = @(
    "$env:LOCALAPPDATA\Playnite\Playnite.DesktopApp.exe",
    'D:\games\yabo-portable\Playnite.DesktopApp.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($exe) {
    Start-Process $exe
    Write-Host "Log: ~\.config\playnite\restore-curation.log" -ForegroundColor DarkGray
} else {
    Write-Host "Playnite exe not found — start it yourself; the marker is set." -ForegroundColor Yellow
}
