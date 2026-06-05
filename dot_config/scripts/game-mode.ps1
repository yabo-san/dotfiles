#requires -Version 5.1
# game-mode.ps1 — called by Playnite GLOBAL scripts so AHK never runs during games.
#   OnGameStarting : game-mode.ps1 -On    -> KILL AutoHotkey (raw input + anti-cheat safe)
#   OnGameStopped  : game-mode.ps1 -Off   -> relaunch it (via the Startup shortcut)
#
# MUST NOT throw: a thrown OnGameStarting script CANCELS the game launch in Playnite,
# so everything is wrapped in try/catch and fails silently.
param([switch]$On, [switch]$Off)

try {
    if ($On) {
        Get-Process AutoHotkey* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    elseif ($Off) {
        # only relaunch if it isn't already running (avoid duplicate instances)
        if (-not (Get-Process AutoHotkey* -ErrorAction SilentlyContinue)) {
            $lnk = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\quake-hotkey.lnk'
            if (Test-Path $lnk) { Start-Process $lnk }
        }
    }
} catch { }
