# bootstrap.ps1: fresh-Windows bootstrap for yabo-san/dotfiles. Re-runnable.
# The one human gate: create the Windows account as 'yabo' first. Run:
#   irm https://raw.githubusercontent.com/yabo-san/dotfiles/main/bootstrap.ps1 | iex
$ErrorActionPreference = 'Stop'
function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }

if ($env:USERNAME -ne 'yabo') {
  Write-Host "[!] You're '$env:USERNAME', not 'yabo'." -ForegroundColor Yellow
  Write-Host "    Config is path-agnostic so it'll work, but 'yabo' is the clean-slate identity (matches yabo-san/*)." -ForegroundColor Yellow
  if ((Read-Host "    Continue anyway? (y/N)") -ne 'y') { return }
}

Step 'scoop + git + chezmoi'
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
  Invoke-RestMethod get.scoop.sh | Invoke-Expression
}
scoop install git chezmoi

# chezmoi also deploys the package manifests and rendered .reg files used below.
Step 'chezmoi init --apply yabo-san/dotfiles'
chezmoi init --apply yabo-san/dotfiles

Step 'scoop + winget package import'
$bs = "$env:USERPROFILE\.config\bootstrap"
'extras','games','nerd-fonts','nonportable' | ForEach-Object { scoop bucket add $_ 2>$null }
if (Test-Path "$bs\scoopfile.json")       { scoop import "$bs\scoopfile.json" }
if (Test-Path "$bs\winget-packages.json") { winget import -i "$bs\winget-packages.json" --accept-source-agreements --accept-package-agreements }

# windows-tweaks.reg touches HKLM (IFEO), so it needs an elevated shell.
Step 'registry: windows-tweaks + open-shell'
foreach ($r in 'windows-tweaks.reg','openshell-settings.reg') { if (Test-Path "$bs\$r") { try { reg import "$bs\$r" } catch { Write-Host "  ! $r needs admin — re-run elevated: reg import `"$bs\$r`"" -ForegroundColor Yellow } } }

Step 'DONE. Remaining MANUAL steps:'
@"
  - Sign in: Dashlane -> then Steam / Epic / RomM, re-enter API keys (SteamGridDB / IGDB)
  - Open-Shell: load $bs\openshell-settings.xml in Open-Shell settings
  - Win11 GUI-only: taskbar auto-hide, Raycast hotkey, default-app 'Open with -> Always'
  - Per-toolchain (as needed): $bs\setup-zen.ps1, setup-gamedev/constructor, setup-playnite (when folded)
"@ | Write-Host -ForegroundColor Gray
