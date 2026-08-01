#requires -Version 5.1
<#
  game-started.ps1 — Playnite global "Game started script" body.

  Playnite's config.json only holds a ONE-LINE stub that calls this file, so all
  real logic lives here in chezmoi instead of buried in an untracked JSON blob.
  The stub is planted by run_onchange_after_playnite-scripts.ps1.

  MUST RETURN IMMEDIATELY. Playnite runs scripts synchronously on its WPF UI
  thread (SynchronizationContext.Send + PSThreadOptions.UseCurrentThread), so
  anything that waits here freezes the entire app. We only read the tag and
  hand off to a detached Python worker.

  MUST NOT THROW. $ErrorActionPreference is forced to 'Stop' by Playnite's
  runspace, so a stray non-terminating error becomes terminating and throws a
  modal dialog on the UI thread. A failure here can't cancel the launch (only
  the "Game starting" script can do that), but the dialog is still in the way.

  Where a game goes is per-game metadata in PLAYNITE. Nothing about any
  individual game belongs in the GlazeWM config.

    Tag      yabo:display=ACR0414        preferred — EDID id, stable
    Tag      yabo:ws=8                   optional — override the host workspace
    Feature  [RC] Display: \\.\DISPLAY9  fallback — what Display Helper writes

  Find a monitor's hardwareId with:  glazewm query monitors
#>
param(
    [int]    $GamePid,
    [object] $Game
)

$ErrorActionPreference = 'Continue'
$DefaultWorkspace = '8'

# Every exit path says WHY. Without this the script fails completely silently -
# Dishonored did nothing for a whole day and the only way to find out was reading
# Playnite's log and guessing.
$Script:GateLog = Join-Path $env:USERPROFILE '.config\scripts\playnite\place-window.log'
function Resolve-Names($ids, $objects, [string]$collection) {
    # Prefer the raw Ids resolved through the database: that is the record of
    # truth, and it works even when the convenience property comes back empty.
    $names = @()
    try {
        if ($ids -and $PlayniteApi) {
            foreach ($id in $ids) {
                $item = $PlayniteApi.Database.$collection.Get($id)
                if ($item -and $item.Name) { $names += $item.Name }
            }
        }
    } catch { }

    if ($names.Count -eq 0 -and $objects) {
        try { $names = @($objects | ForEach-Object { $_.Name } | Where-Object { $_ }) } catch { }
    }

    return $names
}

function Write-Gate([string]$msg) {
    try {
        $line = "{0} [GATE] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss,fff'), $msg
        Add-Content -LiteralPath $Script:GateLog -Value $line -ErrorAction SilentlyContinue
    } catch { }
}

try {
    $gameName = ''
    if ($Game -and $Game.Name) { $gameName = $Game.Name }

    $installDir = ''
    if ($Game -and $Game.InstallDirectory) { $installDir = $Game.InstallDirectory }

    # ── DO NOT GATE ON THE PID ───────────────────────────────────────────────
    # Playnite's $StartedProcessId is unreliable for Steam games: for Dishonored
    # it comes back as `vcredist_x64`, because the redistributable lives inside
    # the install directory and gets caught first. That process exits in about
    # two seconds, so `Get-Process -Id $GamePid` finds nothing and this script
    # used to `return` here - before ever reading a tag. The game was never
    # touched and never said why.
    #
    # Playnite's OWN Steam plugin has the same problem and solves it the same
    # way we do: watch the INSTALL DIRECTORY, not the pid
    # (SteamGameController.cs:198). The worker already treats --install-dir as
    # its primary matcher, so a missing or dead pid is survivable - it is only
    # fatal if we have no install directory to fall back on either.
    $procName = ''
    if ($GamePid) {
        $proc = Get-Process -Id $GamePid -ErrorAction SilentlyContinue
        if ($proc) { $procName = $proc.ProcessName }
    }

    if (-not $procName -and -not $installDir) {
        Write-Gate "$gameName - no usable pid AND no install directory; nothing to match on"
        return
    }

    # --- resolve the target monitor from Playnite metadata ------------------
    # NOTE: '[' and ']' are wildcard metacharacters in -like, hence the backticks.
    $target    = ''
    $workspace = $DefaultWorkspace
    $mode      = 'place'

    if ($Game) {
        # ── DISPLAY HELPER OWNS THE WINDOW → CLEAR ITS SCREEN ANYWAY ─────────
        # An "[RC] Display:" feature means the user handed this game to Display
        # Helper, the fallback for titles that genuinely NEED exclusive
        # fullscreen. We must never touch that window: DH switches the primary
        # monitor and sets the display mode, and DWM border calls on an exclusive
        # -fullscreen window are what crash Unreal and break DirectInput grabs.
        #
        # But NOT TOUCHING THE WINDOW IS NOT THE SAME AS DOING NOTHING, and this
        # used to `return` here, which left the game sharing its screen with
        # whatever workspace happened to be on it. Launching from Playnite means
        # we already know where the game is going — DH's own feature names the
        # screen — so we still evacuate that monitor. The game gets it to itself,
        # which was the entire point.
        #
        # NOTE: '[' and ']' are wildcard metacharacters in -like, hence backticks.
        # ── RESOLVE NAMES THE HARD WAY ───────────────────────────────────────
        # $Game.Tags / $Game.Features are CONVENIENCE properties that resolve the
        # game's Ids against the database, and in Playnite's script runspace they
        # can come back empty even when the game is tagged. Dishonored carries
        # display:acer in the database, and this script still saw no tag at all -
        # it fell through to the untagged path and never touched the window.
        #
        # So read the raw *Ids and resolve them through $PlayniteApi.Database
        # ourselves, falling back to the convenience property. One of the two
        # always works, and the failure is no longer silent.
        $tagNames  = @(Resolve-Names $Game.TagIds     $Game.Tags     'Tags')
        $featNames = @(Resolve-Names $Game.FeatureIds $Game.Features 'Features')
        Write-Gate "$gameName - tags=[$($tagNames -join ', ')] features=[$($featNames -join ', ')]"

        # NOTE: '[' and ']' are wildcard metacharacters in -like, hence backticks.
        $rc = $featNames | Where-Object { $_ -like '`[RC`] Display: *' } |
              Select-Object -First 1

        # display:<monitor> — written by our extension. Windowed games only.
        $tag = $tagNames | Where-Object { $_ -like 'display:*' } | Select-Object -First 1
        if ($tag) { $target = $tag -replace '^display:', '' }

        $wsTag = $tagNames | Where-Object { $_ -like 'workspace:*' } | Select-Object -First 1
        if ($wsTag) { $workspace = $wsTag -replace '^workspace:', '' }

        if ($rc) {
            # Evacuate only — the worker never looks at the window in this mode.
            $mode = 'evacuate'

            # DH writes a GDI device name, e.g. "[RC] Display: \\.\DISPLAY9".
            # Prefer OUR tag when the game carries one, because \\.\DISPLAYn
            # DRIFTS: every display-config change renumbers it (this is the same
            # failure that silently killed the yasb CRT bar). When the string no
            # longer resolves, the worker falls back to whichever monitor the
            # game's window actually landed on, which is why --process still
            # matters here.
            # $rc is a STRING here (Resolve-Names returns names, not objects), so
            # do NOT reach for .Name — that silently yields $null and the game
            # ends up evacuating "wherever the window lands" instead of the screen
            # Display Helper actually named.
            if (-not $target -or $target -eq 'exclusive') {
                $target = ($rc -replace '^\[RC\] Display:\s*', '').Trim()
            }
        }
        elseif ($target -eq 'exclusive') {
            # display:exclusive — a fullscreen game you'd rather not hand to
            # Display Helper. Same contract, but no screen is named, so the
            # worker finds the window and clears whichever monitor it took.
            $mode = 'evacuate'; $target = ''
        }
    }

    # ⚠️ OPT-IN ONLY. If the game carries no display tag, DO NOTHING — return
    # before spawning anything at all.
    #
    # This guard was missing and it broke Dishonored: an untagged game still fell
    # through to 'place', so the worker stripped its window styles mid-launch and
    # moved it to workspace 8. Rewriting a D3D game's styles during init is
    # exactly the class of thing the GlazeWM ignore rules exist to prevent (see
    # the Unreal WindowsWindow.cpp:363 crash and the DarkMod DirectInput race).
    #
    # An untagged game must be indistinguishable from this whole system not
    # existing.
    # ── NO TAG OF OURS → ASSUME DISPLAY HELPER, AND HOLD THE SCREEN ──────────
    # An untagged game is not "nothing to do". The assumption is that the user is
    # driving it with Display Helper, so our job is to tell the WM "a game is
    # taking this monitor, do not put anything there".
    #
    # This is SAFE in a way that 'place' is not: evacuate never touches the
    # window. It only moves OUR workspaces off a screen. The old opt-in guard
    # existed because untagged games were being window-STRIPPED mid-launch, which
    # is what broke Dishonored — that danger belongs to 'place' alone.
    #
    # No screen is named, so the worker infers it from where the window actually
    # opens. That is a guess, hence --only-if-covers: it claims the monitor ONLY
    # if the game is genuinely filling it. Without that, a small windowed game
    # opening on the ultrawide would throw workspaces 1-7 off the main display.
    # ── WE DO NOT MANAGE GAME WINDOWS. AT ALL. ───────────────────────────────
    # Owner's call after two days of this (2026-08-01): forget window management.
    # Moving, resizing and stripping game windows never worked reliably and never
    # will - Dishonored re-asserts its own style and position every ~2.5s, so every
    # "fix" is undone a second later and the attempts are visible as flicker.
    #
    # The whole job is now:
    #   1. Display Helper says which monitor the game wants (it switches the
    #      PRIMARY, which is the only thing that actually relocates such a game).
    #   2. We move OUR workspaces off that monitor.
    #   3. On close we reclaim it.
    #
    # That is 'evacuate' mode, which never touches the window. 'place' - the strip
    # and reposition path - is now opt-in via a display:manage tag, kept only for
    # the games that genuinely tolerate it (The Dark Mod, Thief).
    $inferred = $false
    if ($mode -eq 'place') {
        if ($tagNames -contains 'display:manage') {
            Write-Gate "$gameName - display:manage set, will move the window too"
        } else {
            $mode = 'evacuate'
        }
    }

    # A game we were told nothing about still goes SOMEWHERE, and that somewhere is
    # knowable: the PRIMARY display. Windows puts the primary at the desktop origin
    # and a game that pins itself pins to (0,0).
    #
    # This also covers Display Helper without having to parse its feature at all.
    # DH's only trick is SetPrimaryDisplay (verified in its DLL: CDS_SET_PRIMARY,
    # setAsPrimaryDevice), and it runs BEFORE the game starts - so by the time this
    # script runs, the primary already IS the screen DH chose. Same rule either
    # way: whatever is primary right now is where the game is going.
    #
    # Replaces inferring the monitor from where a window happens to appear, which
    # needed the window to exist, to be findable, and to have settled first.
    if ($mode -eq 'evacuate' -and -not $target) {
        $target = 'primary'
        $inferred = $true
    }

    # NOTE: evacuate mode does NOT require a target. 'display:exclusive' says the
    # game picks its own screen, so the worker finds the window and clears our
    # workspaces off whichever monitor it landed on.

    # --- hand off to the detached worker ------------------------------------
    # pythonw = no console flash. scoop only shims 'python3', so the versioned
    # app path is the reliable one; the shims are fallbacks.
    $py = @(
        "$env:USERPROFILE\scoop\apps\python\current\pythonw.exe",
        "$env:USERPROFILE\scoop\apps\python\current\python.exe",
        "$env:USERPROFILE\scoop\shims\python3.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $py) {
        Write-Gate "$gameName - no python found; cannot run the worker"
        return
    }

    $worker = Join-Path $env:USERPROFILE '.config\scripts\playnite\place_game_window.py'
    if (-not (Test-Path $worker)) {
        Write-Gate "$gameName - worker missing at $worker"
        return
    }

    # --process may legitimately be empty now (dead/wrong pid); --install-dir is
    # the primary matcher and the worker only errors when BOTH are missing, which
    # was already checked above.
    $argList = @(
        "`"$worker`"",
        '--mode',        $mode,
        '--process',     $procName,
        '--install-dir', "`"$installDir`"",
        '--workspace',   $workspace,
        '--target',      "`"$target`"",
        '--game',        "`"$gameName`""
    )
    if ($inferred) { $argList += '--only-if-covers' }

    Write-Gate "$gameName - handing off: mode=$mode target='$target' ws=$workspace proc='$procName' inferred=$inferred dir='$installDir'"
    Start-Process -FilePath $py -ArgumentList $argList -WindowStyle Hidden | Out-Null
}
catch {
    # Never surface a dialog over a launching game — but do not swallow the reason.
    Write-Gate "EXCEPTION: $($_.Exception.Message)"
}
