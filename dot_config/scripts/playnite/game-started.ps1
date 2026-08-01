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

try {
    if (-not $GamePid) { return }

    $proc = Get-Process -Id $GamePid -ErrorAction SilentlyContinue
    if (-not $proc) { return }

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
        $rc = $Game.Features | Where-Object { $_.Name -like '`[RC`] Display: *' } |
              Select-Object -First 1

        # display:<monitor> — written by our extension. Windowed games only.
        $tag = $Game.Tags | Where-Object { $_.Name -like 'display:*' } |
               Select-Object -First 1 -ExpandProperty Name
        if ($tag) { $target = $tag -replace '^display:', '' }

        $wsTag = $Game.Tags | Where-Object { $_.Name -like 'workspace:*' } |
                 Select-Object -First 1 -ExpandProperty Name
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
            if (-not $target -or $target -eq 'exclusive') {
                $target = ($rc.Name -replace '^\[RC\] Display:\s*', '').Trim()
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
    if ($mode -eq 'place' -and -not $target) { return }

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
    if (-not $py) { return }

    $worker = Join-Path $env:USERPROFILE '.config\scripts\playnite\place_game_window.py'
    if (-not (Test-Path $worker)) { return }

    # No '??' here: Playnite's runspace is Windows PowerShell 5.1.
    $gameName = ''
    if ($Game -and $Game.Name) { $gameName = $Game.Name }

    # InstallDirectory is the PRIMARY matcher. Playnite's own Steam plugin works
    # this way — SteamGameController.cs:198 watches the install directory for
    # processes rather than tracking the launched pid — which is exactly why
    # $StartedProcessId came back as `vcredist_x64` for Dishonored: the redist
    # lives inside that directory and got caught first. ProcessName is the
    # fallback for games with no install dir recorded.
    $installDir = ''
    if ($Game -and $Game.InstallDirectory) { $installDir = $Game.InstallDirectory }

    $argList = @(
        "`"$worker`"",
        '--mode',        $mode,
        '--process',     $proc.ProcessName,
        '--install-dir', "`"$installDir`"",
        '--workspace',   $workspace,
        '--target',      "`"$target`"",
        '--game',        "`"$gameName`""
    )
    Start-Process -FilePath $py -ArgumentList $argList -WindowStyle Hidden | Out-Null
}
catch {
    # Never surface a dialog over a launching game.
}
