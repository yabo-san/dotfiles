#requires -Version 5.1
# =============================================================================
# setup-playnite.ps1 — Playnite + the private extensions and themes
# =============================================================================
# The PUBLIC dotfiles stay generic and secret-free: they install Playnite, then
# pull the PRIVATE extensions from yabo-san/playnite-extensions and folder-drop
# them. No Playnite state, config or secrets ever live in the dotfiles.
#
# The extensions used to live in the launcher repo (yabo-san/yabo-launcher, a
# fork of SirDiabo/GithubLauncher). They moved out on 2026-07-31 — a
# GithubLauncher extension inside a fork OF GithubLauncher was a trap, and
# nothing there could be published without dragging a fork's history along.
#
# This builds EVERY extension it finds rather than a named one, so adding a new
# extension to that repo needs no change here.
#
#   Run on a fresh machine with Playnite CLOSED (it loads extensions at startup).
#   Re-runnable.  pwsh ~/.config/bootstrap/setup-playnite.ps1
# =============================================================================
$ErrorActionPreference = 'Continue'

$repo   = 'D:\REPOS\playnite-extensions'
$remote = 'https://github.com/yabo-san/playnite-extensions.git'

$extDir   = Join-Path $env:APPDATA 'Playnite\Extensions'
$themeDir = Join-Path $env:APPDATA 'Playnite\Themes\Desktop'

function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }
function Note($m){ Write-Host "    $m" -ForegroundColor DarkGray }
function Warn($m){ Write-Host "    $m" -ForegroundColor Yellow }

# 1) Playnite itself — package-managed, generic, idempotent
Step 'Playnite (winget — skips if already installed)'
if (Get-Command winget -ErrorAction SilentlyContinue) {
  winget install -e --id Playnite.Playnite --accept-source-agreements --accept-package-agreements 2>$null
} else {
  Warn 'winget not found — install Playnite manually.'
}

# 2) the extensions live in a PRIVATE repo — clone if missing (needs your gh token)
if (-not (Test-Path $repo)) {
  Step "Cloning playnite-extensions (private) -> $repo"
  git clone $remote $repo
}
if (-not (Test-Path $repo)) {
  Warn 'Extensions repo unavailable (no token / generic machine). Playnite is installed —'
  Warn 'drop your own extensions into %APPDATA%\Playnite\Extensions and you are done.'
  return
}

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
  Warn '.NET SDK not found — needed to build the extensions. Install it and re-run.'
  return
}

New-Item -ItemType Directory -Force $extDir, $themeDir | Out-Null

# 3) build + deploy every EXTENSION (a folder with an extension.yaml and a .csproj)
Step 'Building and deploying extensions'
foreach ($dir in Get-ChildItem $repo -Directory) {
  $yaml = Join-Path $dir.FullName 'extension.yaml'
  if (-not (Test-Path $yaml)) { continue }

  $proj = Get-ChildItem $dir.FullName -Filter *.csproj -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $proj) {
    Note "$($dir.Name): extension.yaml but no .csproj — skipped."
    continue
  }

  dotnet build $proj.FullName -c Release -v quiet | Out-Null

  $dll = Get-ChildItem (Join-Path $dir.FullName 'bin\Release') -Filter *.dll -Recurse -ErrorAction SilentlyContinue |
         Where-Object { $_.BaseName -notmatch '^(Newtonsoft|Playnite)' } | Select-Object -First 1
  if (-not $dll) {
    Warn "$($dir.Name): build produced no DLL — skipped."
    continue
  }

  $dest = Join-Path $extDir $dir.Name
  New-Item -ItemType Directory -Force $dest | Out-Null
  Copy-Item $dll.FullName $dest -Force
  Copy-Item $yaml $dest -Force
  Write-Host "    $($dir.Name) -> $($dll.Name)" -ForegroundColor Green
}

# 4) deploy every THEME (a folder with a theme.yaml). XAML — nothing to build.
Step 'Deploying themes'
foreach ($dir in Get-ChildItem $repo -Directory) {
  if (-not (Test-Path (Join-Path $dir.FullName 'theme.yaml'))) { continue }
  $dest = Join-Path $themeDir $dir.Name
  New-Item -ItemType Directory -Force $dest | Out-Null
  # /MIR so a removed file upstream is removed here too; excludes VCS + build junk.
  robocopy $dir.FullName $dest /MIR /XD .git bin obj /NFL /NDL /NJH /NJS /NP | Out-Null
  Write-Host "    $($dir.Name)" -ForegroundColor Green
}

# 5) the Hydra extension shells out to a Node helper for its LevelDB read.
#    chezmoi deploys the script; the native dependency installs per machine.
$hydraHelper = Join-Path $env:USERPROFILE '.config\scripts\hydra\dump-library.js'
if (Test-Path $hydraHelper) {
  $hydraDir = Split-Path $hydraHelper
  if (-not (Test-Path (Join-Path $hydraDir 'node_modules\classic-level'))) {
    if (Get-Command npm -ErrorAction SilentlyContinue) {
      Step 'Installing the Hydra reader dependency (classic-level)'
      Push-Location $hydraDir; npm install classic-level --silent 2>$null; Pop-Location
    } else {
      Warn 'Node/npm not found — the Hydra extension will not be able to read its library.'
    }
  }
}

Write-Host "[done] Open Playnite -> Library > Update Game Library to import your games." -ForegroundColor Green
Note 'Playnite own config.json (theme choice, global scripts) is not carried here — set on first run.'
Note 'GithubLauncher imports nothing until you add a game to it. That is expected.'
