#requires -Version 5.1
# =============================================================================
# gamedev — toolchain bootstrap (manual, re-runnable)
# =============================================================================
# The gamedev stack that ISN'T a clean scoop/winget app lives here. The
# package-managed ones are in winget-packages.json / scoopfile.json — but those
# are `winget export` / `scoop export` DUMPS (regenerated), so don't hand-edit
# them; this script is the home for everything that needs fetching/building.
# Run:  pwsh ~/.config/bootstrap/gamedev.ps1
# =============================================================================
$ErrorActionPreference = 'Continue'
function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }
function Have($c){ [bool](Get-Command $c -ErrorAction SilentlyContinue) }

# --- gamedev: already package-managed (winget-packages.json) — here for the record
#   YoYoGames.GameMaker.Studio.2   GameMaker IDE  (runtime+build are GM-account-gated; see kevengine notes)
#   ItchIo.Itch                    itch.io client
#   BlenderFoundation.Blender, Playnite.Playnite, Libretro.RetroArch

# --- gamedev: GMEdit + GMEdit-Constructor (code editor + compile-from-editor plugin)
#   GMEdit:      https://yellowafterlife.itch.io/gmedit   (YAL; src: github.com/YAL-GameMaker)
#   Constructor: git clone https://github.com/thennothinghappened/GMEdit-Constructor
#                -> %APPDATA%\AceGM\GMEdit\plugins\GMEdit-Constructor   (git pull to update)
Step 'GMEdit + Constructor (delegates to setup-gmedit.ps1)'
$gmedit = Join-Path $PSScriptRoot 'setup-gmedit.ps1'
if (Test-Path $gmedit) { & $gmedit }
else { Write-Host '  setup-gmedit.ps1 not found — get GMEdit at https://yellowafterlife.itch.io/gmedit' -ForegroundColor Yellow }

# --- gamedev: gm-cli (YoYo headless build CLI — GMEdit + CLI replaces the GM IDE)
#   https://github.com/YoYoGames/gm-cli   (needs a licensed GM runtime; account-gated)
Step 'gm-cli — manual install: https://github.com/YoYoGames/gm-cli (licensed GM runtime required)'

# --- gamedev: Aseprite (pixel-art editor = sprite source-of-truth; CLI-exports PNG+JSON)
#   Paid: Steam or aseprite.org. Open build: github.com/aseprite/aseprite (build from source).
#   Try winget in case a build is listed; silently skips if absent/paid.
if (Have winget) { Step 'Aseprite (winget try)'; winget install --id Aseprite.Aseprite -e --accept-source-agreements --accept-package-agreements 2>$null }

# --- gamedev: Tilengine embed deps (kevengine -> GameMaker renderer)
#   Tilengine: scanline 2D renderer embedded in GM as a native extension. MPL-2.0 (commercial-OK).
#     DLL+header: megamarc/Tilengine prebuilt (no GitHub releases — distributed zip, or CMake build).
#     SDL2 runtime: Tilengine.dll imports SDL2.dll -> fetched here from the official SDL2 (2.x) release.
$tln = Join-Path $HOME '.local\gamedev\tilengine'
Step "Tilengine embed deps -> $tln"
New-Item -ItemType Directory -Force $tln | Out-Null
try {
  $rel = (Invoke-RestMethod 'https://api.github.com/repos/libsdl-org/SDL/releases' -Headers @{ 'User-Agent' = 'dotfiles' }) |
         Where-Object { $_.tag_name -like 'release-2.*' } | Select-Object -First 1
  $url = ($rel.assets | Where-Object { $_.name -like '*win32-x64.zip' } | Select-Object -First 1).browser_download_url
  $z = Join-Path $env:TEMP 'sdl2-gamedev.zip'; Invoke-WebRequest $url -OutFile $z -UseBasicParsing
  Expand-Archive $z -DestinationPath $tln -Force
  Write-Host "  + SDL2.dll ($($rel.tag_name)) -> $tln" -ForegroundColor Green
} catch { Write-Host "  ! SDL2 fetch failed: $($_.Exception.Message)" -ForegroundColor Yellow }
Write-Host "  Drop Tilengine.dll + Tilengine.h here from the megamarc/Tilengine prebuilt zip." -ForegroundColor DarkGray

Write-Host "`n# gamedev toolchain bootstrap complete." -ForegroundColor Green
