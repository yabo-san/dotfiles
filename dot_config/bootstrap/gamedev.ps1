#requires -Version 5.1
# gamedev toolchain bootstrap (manual, re-runnable): the parts that aren't clean scoop/winget apps.
# winget-packages.json / scoopfile.json are export dumps, so don't hand-edit them. Run: pwsh ~/.config/bootstrap/gamedev.ps1
$ErrorActionPreference = 'Continue'
function Step($m){ Write-Host "==> $m" -ForegroundColor Cyan }
function Have($c){ [bool](Get-Command $c -ErrorAction SilentlyContinue) }

# GMEdit + GMEdit-Constructor (Constructor clones into %APPDATA%\AceGM\GMEdit\plugins).
Step 'GMEdit + Constructor (delegates to setup-constructor.sh)'
$gmedit = Join-Path $PSScriptRoot 'setup-constructor.sh'
if (Test-Path $gmedit) { sh $gmedit }
else { Write-Host '  setup-constructor.sh not found — get GMEdit at https://yellowafterlife.itch.io/gmedit' -ForegroundColor Yellow }

Step 'gm-cli — manual install: https://github.com/YoYoGames/gm-cli (licensed GM runtime required)'

# Aseprite is paid; try winget in case a build is listed, skip quietly otherwise.
if (Have winget) { Step 'Aseprite (winget try)'; winget install --id Aseprite.Aseprite -e --accept-source-agreements --accept-package-agreements 2>$null }

# Tilengine (kevengine's GM renderer) has no GitHub releases; its DLL imports SDL2.dll, fetched here.
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
