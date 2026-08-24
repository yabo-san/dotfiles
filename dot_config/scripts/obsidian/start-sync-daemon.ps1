#requires -Version 5.1
# =============================================================================
# start-sync-daemon.ps1 — bring up the Obsidian local<->iCloud sync daemon
# =============================================================================
# Run at LOGON from a Startup shortcut (see run_onchange_after_startup-shortcuts.ps1).
# Idempotent and safe to run by hand: if the daemon is already up it does nothing.
#
# WHY THIS EXISTS AS ITS OWN SCRIPT: this logic used to live inside the Raycast
# "Obsidian" command, so sync only started if the vault was opened THAT ONE WAY.
# Open Obsidian from the taskbar, the Start menu, an obsidian:// link or a
# pinned tile and nothing synced -- silently. Sync is a machine service, not a
# side effect of one launcher, so it now starts at logon and Obsidian is opened
# however you like.
#
# THE ARCHITECTURE IT SERVES: Obsidian on this machine opens ONLY the replica at
# D:\obsidian\sb. It never touches D:\iCloudDrive\iCloud~md~obsidian\sb. This
# daemon is the bridge between them, so the iCloud vault (the Mac/iPhone source
# of truth) is never edited by Windows directly.
#
# Five faults killed the previous arrangements (five weeks silent, then three
# days dead); each guard below is one of them:
#
#   1. VENV, NOT THE SCOOP PYTHON. `python` is in scoopfile.json, so a `scoop
#      update` replaces the install dir and takes site-packages with it -- which
#      happened on 2026-07-31 (pyyaml, watchdog, colorama, aiofiles all gone;
#      the daemon then died at `import yaml`). A venv in the tool's own repo is
#      immune. run_onchange_after_install-obsidian-sync.ps1 creates it.
#
#   2. STDIN IS FED. DuplicateScanner.scan_and_clean() runs at __main__.py:31,
#      BEFORE the engine is built and outside any try, and calls input() guarded
#      only against KeyboardInterrupt -- not EOFError. With no stdin that is an
#      uncaught exception, so ANY conflict/duplicate/.tmp file in the three
#      vaults makes the daemon unstartable. "n" declines the destructive
#      cleanup; conflicts are reported below instead of blind-deleted.
#
#   3. FAILURES ARE VISIBLE. pythonw with redirected streams means no console
#      flash, but stderr lands in a file, the process is re-checked a beat
#      later, and anything wrong is written to a breadcrumb the next run and
#      `obsidian-sync-status` both read. A logon task that fails quietly is how
#      you lose five weeks.
#
#   4. CONFIG COMES FROM CHEZMOI (~/.config/obsidian/sync-config.yaml), not the
#      tool's checkout, so `git pull` upstream cannot clobber it.
#
#   5. STDOUT IS UTF-8. Every transfer logs an arrow icon (logger.py's push/pull
#      icons are literally "↑"/"↓"), and pythonw under -RedirectStandardOutput
#      gives CPython a pipe, which it encodes with the ANSI codepage (cp1252)
#      unless told otherwise. cp1252 cannot encode ↑, so print() raised
#      UnicodeEncodeError inside sync_file -- BEFORE the copy ran -- and every
#      push AND pull died as "[ERROR] Error syncing ... 'charmap' codec can't
#      encode character '\u2191'". 535 hits in the log; from 2026-08-18 20:19
#      to 2026-08-21 nothing propagated in either direction. The earlier
#      instances that worked had inherited a UTF-8 environment by luck; this
#      pins it. PYTHONIOENCODING retunes stdio only -- open() semantics,
#      i.e. how note files themselves are read/written, are untouched.
# =============================================================================
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

# ── already running? ────────────────────────────────────────────────────────
# CommandLine, not process name: the venv pythonw.exe is a shim that re-execs
# the base interpreter, so one daemon shows up as TWO pythonw processes (parent
# + child). Matching on the module name counts the pair as one.
#
# Get-CimInstance, NOT Get-Process: the .CommandLine property on a Process
# object only exists in PowerShell 7+. This runs under Windows PowerShell 5.1
# (that is what the Startup shortcut launches, same as the yasb bar fix), where
# the property is silently absent -- so the filter matched nothing, the guard
# fell through, and every logon would have started a SECOND daemon on top of
# the first. Two writers on the same three vaults is the worst failure this
# whole arrangement can have. Win32_Process exposes CommandLine on both.
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

# Decline the duplicate-cleanup prompt (fault 2 above). Per-run filename: the
# live daemon holds its stdin file open for its whole life, so a fixed name
# makes this line throw ("used by another process") the moment anything else
# tries to start one.
$stdin = Join-Path $env:TEMP "obsidian-sync-stdin-$stamp.txt"
Set-Content -LiteralPath $stdin -Value 'n' -Encoding ascii

# Fault 5: pin stdio to UTF-8 for the child (Start-Process inherits this env).
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

# Conflict artifacts don't stop the daemon, but they mean the two sides diverged
# -- worth surfacing rather than silently accumulating.
$conflicts = @()
foreach ($d in 'D:\obsidian\sb', 'D:\iCloudDrive\iCloud~md~obsidian\sb') {
    $conflicts += Get-ChildItem $d -Recurse -File -Filter '*_CONFLICT_*' -ErrorAction SilentlyContinue
}
if ($conflicts) {
    Note "sync: $($conflicts.Count) conflict file(s) present - $($conflicts.FullName -join '; ')" 'Yellow'
}
