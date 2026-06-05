# bootstrap.ps1 — fresh-Windows bootstrap for yabo-san/dotfiles
# =============================================================================
# THE ONE HUMAN GATE: create the Windows account as 'yabo' (-> C:\Users\yabo)
# before running. Everything else is path-agnostic (configs template the home
# dir), so this just chains the rest. Fetch + run on a clean Windows:
#   irm https://raw.githubusercontent.com/yabo-san/dotfiles/main/bootstrap.ps1 | iex
# Re-runnable.
# =============================================================================
$ErrorActionPreference = 'Stop'
function Step($m){ Write-Host "`n==> $m" -ForegroundColor Cyan }

# 0) THE GATE — account identity (config still works elsewhere, but yabo is the intent)
if ($env:USERNAME -ne 'yabo') {
  Write-Host "[!] You're '$env:USERNAME', not 'yabo'." -ForegroundColor Yellow
  Write-Host "    Config is path-agnostic so it'll work, but 'yabo' is the clean-slate identity (matches yabo-san/*)." -ForegroundColor Yellow
  if ((Read-Host "    Continue anyway? (y/N)") -ne 'y') { return }
}

# 1) scoop (no-UAC pkg mgr) -> git + chezmoi
Step 'scoop + git + chezmoi'
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
  Invoke-RestMethod get.scoop.sh | Invoke-Expression
}
scoop install git chezmoi

# 2) chezmoi pulls + applies ALL config (also deploys the package manifests + rendered .reg)
Step 'chezmoi init --apply yabo-san/dotfiles'
chezmoi init --apply yabo-san/dotfiles

# 3) packages from the now-deployed manifests
Step 'scoop + winget package import'
$bs = "$env:USERPROFILE\.config\bootstrap"
'extras','games','nerd-fonts','nonportable' | ForEach-Object { scoop bucket add $_ 2>$null }
if (Test-Path "$bs\scoopfile.json")       { scoop import "$bs\scoopfile.json" }
if (Test-Path "$bs\winget-packages.json") { winget import -i "$bs\winget-packages.json" --accept-source-agreements --accept-package-agreements }

# 4) registry (the .reg were templated by chezmoi -> already correct for THIS account)
#    NOTE: windows-tweaks.reg touches HKLM (IFEO) -> needs an ELEVATED shell; re-run this step as admin if it errors.
Step 'registry: windows-tweaks + open-shell'
foreach ($r in 'windows-tweaks.reg','openshell-settings.reg') { if (Test-Path "$bs\$r") { try { reg import "$bs\$r" } catch { Write-Host "  ! $r needs admin — re-run elevated: reg import `"$bs\$r`"" -ForegroundColor Yellow } } }

# 5) the genuinely-manual remainder (can't be scripted on Windows)
Step 'DONE. Remaining MANUAL steps:'
@"
  - Sign in: Dashlane -> then Steam / Epic / RomM, re-enter API keys (SteamGridDB / IGDB)
  - Open-Shell: load $bs\openshell-settings.xml in Open-Shell settings
  - Win11 GUI-only: taskbar auto-hide, Raycast hotkey, default-app 'Open with -> Always'
  - Per-toolchain (as needed): $bs\setup-zen.ps1, setup-gamedev/constructor, setup-playnite (when folded)
"@ | Write-Host -ForegroundColor Gray
