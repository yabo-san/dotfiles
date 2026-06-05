#requires -Version 5.1
# setup-zen.ps1 — track Zen browser keyboard shortcuts in the dotfiles.
# Zen stores ALL shortcuts (incl your private-window override) in one file,
# zen-keyboard-shortcuts.json, inside its profile — but the profile has a random ID
# (%APPDATA%\zen\Profiles\<random>.Default (release)\), so we keep a tracked copy here
# and sync it in/out, resolving the profile path at runtime.
#
#   pwsh setup-zen.ps1            -> RESTORE: copy the tracked JSON into the Zen profile
#                                   (run with Zen CLOSED — it reads shortcuts at startup)
#   pwsh setup-zen.ps1 -Snapshot -> copy the profile JSON back HERE after you change
#                                   shortcuts in Zen's UI (then: chezmoi add + commit)
param([switch]$Snapshot)
$ErrorActionPreference = 'Continue'
$tracked = Join-Path $PSScriptRoot 'zen-keyboard-shortcuts.json'

# find the Zen profile (prefer the *.Default* release profile; fall back to first)
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
