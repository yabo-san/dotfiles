#!/usr/bin/env pwsh
# @raycast.schemaVersion 1
# @raycast.title Obsidian
# @raycast.mode compact
# @raycast.packageName Obsidian
# @raycast.icon 🪨
# @raycast.description Start the iCloud sync daemon (if not running) then open the vault

<#
  Opens the vault and makes sure the local<->iCloud sync daemon is alive.

  This script previously fired `python -m obsidian_sync` with -WindowStyle
  Hidden and never looked at the result. It "worked" for five weeks while the
  daemon was in fact dead on arrival, and 54 notes piled up in iCloud that
  Windows never saw. Every design choice below exists to stop that recurring.

  1. VENV, NOT THE SCOOP PYTHON. `python` is in scoopfile.json, so `scoop
     update` replaces the whole install directory and takes site-packages with
     it -- which is exactly what happened on 2026-07-31 (pyyaml, watchdog,
     colorama and aiofiles all vanished; the daemon then died at `import yaml`).
     A venv inside the tool's own repo is immune to that.

  2. STDIN IS FED. DuplicateScanner.scan_and_clean() runs at __main__.py:31,
     BEFORE the engine is constructed and outside any try, and calls input()
     guarded only against KeyboardInterrupt -- not EOFError. With no stdin that
     is an uncaught exception, so ANY conflict/duplicate/.tmp file anywhere in
     the three vaults makes the daemon unstartable. Answering "n" declines the
     destructive cleanup and lets the engine start; conflicts are surfaced below
     instead, where they can be looked at rather than blind-deleted.

  3. FAILURES ARE VISIBLE. pythonw + redirected streams means no console flash,
     but stderr lands in a file and we check the process is still alive a beat
     later. @raycast.mode is `compact` rather than `silent` so a failure
     actually reaches the screen.

  Config lives in chezmoi (~/.config/obsidian/sync-config.yaml), NOT in the
  tool's checkout, so `git pull` upstream can't clobber it.
#>

$ErrorActionPreference = 'Stop'

$repo   = 'D:\REPOS\obsidian-icloud-windows-sync'
$py     = Join-Path $repo '.venv\Scripts\pythonw.exe'
$config = Join-Path $env:USERPROFILE '.config\obsidian\sync-config.yaml'
$logDir = 'D:\obsidian\logs'
$vault  = 'sb'

function Fail($msg) { Write-Host $msg -ForegroundColor Red; Start-Process "obsidian://open?vault=$vault"; exit 1 }

# ── already running? ────────────────────────────────────────────────────────
$running = Get-Process python, pythonw -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*obsidian_sync*' }

if (-not $running) {
    if (-not (Test-Path $py))     { Fail "sync: venv missing ($py). Run: python -m venv .venv; .venv\Scripts\python -m pip install . in $repo" }
    if (-not (Test-Path $config)) { Fail "sync: config missing ($config). Run chezmoi apply." }

    New-Item -ItemType Directory -Force $logDir | Out-Null
    $stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
    $errLog = Join-Path $logDir "launcher-$stamp.err.log"
    $outLog = Join-Path $logDir "launcher-$stamp.out.log"

    # Decline the duplicate-cleanup prompt (see note 2 above).
    $stdin = Join-Path $env:TEMP 'obsidian-sync-stdin.txt'
    Set-Content -LiteralPath $stdin -Value 'n' -Encoding ascii

    $p = Start-Process -FilePath $py `
        -ArgumentList '-m', 'obsidian_sync', '--config', "`"$config`"" `
        -WorkingDirectory $repo `
        -RedirectStandardInput $stdin `
        -RedirectStandardOutput $outLog `
        -RedirectStandardError $errLog `
        -PassThru

    Start-Sleep -Seconds 4

    if ($p.HasExited) {
        $err = (Get-Content $errLog -Raw -ErrorAction SilentlyContinue)
        if (-not $err) { $err = (Get-Content $outLog -Tail 15 -ErrorAction SilentlyContinue) -join "`n" }
        Fail "sync: daemon exited immediately (code $($p.ExitCode)).`n$err"
    }

    Write-Host "sync: running (pid $($p.Id))" -ForegroundColor Green

    # Conflict artifacts don't stop the daemon now, but they do mean the two
    # sides diverged -- worth knowing about rather than silently accumulating.
    $conflicts = @()
    foreach ($d in 'D:\obsidian\sb', 'D:\iCloudDrive\iCloud~md~obsidian\sb') {
        $conflicts += Get-ChildItem $d -Recurse -File -Filter '*_CONFLICT_*' -ErrorAction SilentlyContinue
    }
    if ($conflicts) {
        Write-Host "sync: $($conflicts.Count) conflict file(s) present:" -ForegroundColor Yellow
        $conflicts | ForEach-Object { Write-Host "  $($_.FullName)" -ForegroundColor Yellow }
    }
} else {
    Write-Host "sync: already running (pid $($running.Id -join ', '))" -ForegroundColor DarkGray
}

Start-Process "obsidian://open?vault=$vault"
