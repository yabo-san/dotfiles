#requires -Version 5.1
# Starts the Obsidian local<->iCloud sync daemon. Run at logon by a Startup shortcut; safe to rerun.
# Uses the repo venv (scoop updates wipe site-packages) and the chezmoi-managed config. Failures go to daemon-status.txt.
$ErrorActionPreference = 'Stop'

$repo    = 'D:\REPOS\obsidian-icloud-windows-sync'
$py      = Join-Path $repo '.venv\Scripts\pythonw.exe'
$config  = Join-Path $env:USERPROFILE '.config\obsidian\sync-config.yaml'
$logDir  = 'D:\obsidian\logs'
$status  = Join-Path $logDir 'daemon-status.txt'

function Note($msg, $colour = 'Gray') {
    Write-Host $msg -ForegroundColor $colour
    try {
        New-Item -ItemType Directory -Force $logDir | Out-Null
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $msg" | Set-Content -LiteralPath $status -Encoding utf8
    } catch { }   # never let the breadcrumb take the daemon down with it
}

# Match on CommandLine: the venv pythonw shim shows up as two processes. Get-CimInstance because
# Process.CommandLine does not exist in PowerShell 5.1, and a missed match would start a second daemon.
$running = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*obsidian_sync*' })

if ($running) {
    Note "sync: already running (pid $($running.ProcessId -join ', '))" 'DarkGray'
    exit 0
}

if (-not (Test-Path $py))     { Note "sync: FAILED - venv missing ($py). Run chezmoi apply, or in $repo`: python -m venv .venv; .venv\Scripts\python -m pip install ." 'Red'; exit 1 }
if (-not (Test-Path $config)) { Note "sync: FAILED - config missing ($config). Run chezmoi apply." 'Red'; exit 1 }

New-Item -ItemType Directory -Force $logDir | Out-Null
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$outLog = Join-Path $logDir "launcher-$stamp.out.log"
$errLog = Join-Path $logDir "launcher-$stamp.err.log"

# Answer "n" to the duplicate-cleanup input() prompt, which crashes on EOF. Per-run file: the live daemon keeps its stdin open.
$stdin = Join-Path $env:TEMP "obsidian-sync-stdin-$stamp.txt"
Set-Content -LiteralPath $stdin -Value 'n' -Encoding ascii

# pythonw writes to a pipe in cp1252, which cannot encode the log's arrow icons and breaks every sync.
$env:PYTHONIOENCODING = 'utf-8'

$p = Start-Process -FilePath $py `
    -ArgumentList '-m', 'obsidian_sync', '--config', "`"$config`"" `
    -WorkingDirectory $repo `
    -RedirectStandardInput $stdin `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog `
    -PassThru

Start-Sleep -Seconds 4

if ($p.HasExited) {
    $err = Get-Content $errLog -Raw -ErrorAction SilentlyContinue
    if (-not $err) { $err = (Get-Content $outLog -Tail 15 -ErrorAction SilentlyContinue) -join "`n" }
    Note "sync: FAILED - daemon exited immediately (code $($p.ExitCode)). $err" 'Red'
    exit 1
}

Note "sync: running (pid $($p.Id)), log $outLog" 'Green'

# Conflict files do not stop the daemon but mean the two sides diverged, so report them.
$conflicts = @()
foreach ($d in 'D:\obsidian\sb', 'D:\iCloudDrive\iCloud~md~obsidian\sb') {
    $conflicts += Get-ChildItem $d -Recurse -File -Filter '*_CONFLICT_*' -ErrorAction SilentlyContinue
}
if ($conflicts) {
    Note "sync: $($conflicts.Count) conflict file(s) present - $($conflicts.FullName -join '; ')" 'Yellow'
}
