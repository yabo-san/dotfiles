#requires -Version 5.1
# setup-zen.ps1: keeps Zen's zen-keyboard-shortcuts.json tracked; the profile dir has a random ID, resolved at runtime.
#   pwsh setup-zen.ps1            restore into the profile (Zen closed: it reads shortcuts at startup)
#   pwsh setup-zen.ps1 -Snapshot  copy the profile file back here after changing shortcuts in Zen
param([switch]$Snapshot)
$ErrorActionPreference = 'Continue'
$tracked = Join-Path $PSScriptRoot 'zen-keyboard-shortcuts.json'

$root = Join-Path $env:APPDATA 'zen\Profiles'
$prof = Get-ChildItem $root -Directory -EA SilentlyContinue | Where-Object { $_.Name -match '\.Default' } | Select-Object -First 1
if (-not $prof) { $prof = Get-ChildItem $root -Directory -EA SilentlyContinue | Select-Object -First 1 }
if (-not $prof) { Write-Host "[!!] No Zen profile under $root — install/run Zen once first." -ForegroundColor Yellow; return }
$live = Join-Path $prof.FullName 'zen-keyboard-shortcuts.json'

if ($Snapshot) {
  if (-not (Test-Path $live)) { Write-Host "[!!] No live shortcuts file at $live" -ForegroundColor Yellow; return }
  Copy-Item $live $tracked -Force
  Write-Host "[ok] snapshotted Zen shortcuts -> $tracked"
  Write-Host "     now: chezmoi add $tracked ; git commit"
} else {
  if (Get-Process zen -ErrorAction SilentlyContinue) { Write-Host "[!!] Close Zen first (it reads shortcuts at startup)." -ForegroundColor Yellow; return }
  if (-not (Test-Path $tracked)) { Write-Host "[!!] No tracked JSON at $tracked" -ForegroundColor Yellow; return }
  Copy-Item $tracked $live -Force
  Write-Host "[ok] restored Zen shortcuts -> $live (start Zen to load)"
}
