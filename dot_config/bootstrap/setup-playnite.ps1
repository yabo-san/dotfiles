#requires -Version 5.1
# =============================================================================
# setup-playnite.ps1 — Playnite + the yabo dev-only extension (the "backup")
# =============================================================================
# The PUBLIC dotfiles stay generic + secret-free: they install Playnite, then
# pull the PRIVATE YaboLibrary extension (which OWNS the library / feed subscription
# / curation) from the yabo-launcher repo and folder-drop it. No Playnite state,
# config, or secrets ever live in the dotfiles — the private extension is the backup.
#
# Replaces the old yabo-san/yabo backup repo entirely (nothing left to mis-author).
#
#   Run ONCE on a fresh machine, with Playnite CLOSED (it loads extensions at startup).
#   Re-runnable.  pwsh ~/.config/bootstrap/setup-playnite.ps1
# =============================================================================
$ErrorActionPreference = 'Continue'
$repo = 'D:\REPOS\ports-launcher'          # private launcher repo (carries the extension)
$remote = 'https://github.com/yabo-san/yabo-launcher.git'

function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }

# 1) Playnite (the app) — package-managed, generic, idempotent
Step 'Playnite (winget — skips if already installed)'
if (Get-Command winget -ErrorAction SilentlyContinue) {
  winget install -e --id Playnite.Playnite --accept-source-agreements --accept-package-agreements 2>$null
}

# 2) the dev-only extension lives in the PRIVATE launcher repo — clone if missing (needs your gh token)
if (-not (Test-Path $repo)) {
  Step "Cloning yabo-launcher (private) -> $repo"
  git clone $remote $repo
}
if (-not (Test-Path $repo)) {
  Write-Host "  Launcher repo unavailable (no token / generic machine). Playnite is installed —" -ForegroundColor Yellow
  Write-Host "  drop your own extension into %APPDATA%\Playnite\Extensions and you're done." -ForegroundColor Yellow
  return
}

# 3) build the YaboLibrary plugin if it isn't built yet
$built = Join-Path $repo 'playnite\YaboLibrary\bin\Release\net462\YaboLibrary.dll'
if (-not (Test-Path $built)) {
  if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Step 'Building YaboLibrary (dotnet build -c Release)'
    dotnet build -c Release (Join-Path $repo 'playnite\YaboLibrary')
  } else {
    Write-Host "  .NET SDK not found — install it to build the plugin, or drop a prebuilt DLL." -ForegroundColor Yellow
    return
  }
}

# 4) deploy via the launcher's existing folder-drop script (Playnite MUST be closed)
Step 'Deploying the extension (launcher deploy-playnite-extension.ps1)'
& (Join-Path $repo 'dev\deploy-playnite-extension.ps1')

Write-Host "[done] Open Playnite -> Library > Update Game Library to import your games." -ForegroundColor Green
Write-Host "[note] Playnite's own config.json (theme/global settings) isn't carried here — set on first run." -ForegroundColor DarkGray
