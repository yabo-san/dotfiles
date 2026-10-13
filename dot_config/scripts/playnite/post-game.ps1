#requires -Version 5.1
# Playnite "game exited" hook: restarts AutoHotkey and GlazeWM, which pre-game.ps1 stopped.
# Launches the exes directly, not Startup shortcuts. After a crash mid-game neither runs; restart them by hand.
param(
    [object] $Game
)

$ErrorActionPreference = 'Continue'

try {
    $exe = "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe"
    $ahk = "$env:USERPROFILE\.config\scripts\hotkeys.ahk"
    if ((Test-Path $exe) -and -not (Get-Process AutoHotkey* -ErrorAction SilentlyContinue)) {
        Start-Process $exe -ArgumentList "`"$ahk`""
    }
}
catch {
    # Never surface a dialog after a game exits.
}

try {
    $glaze = 'C:\Program Files\glzr.io\GlazeWM\glazewm.exe'
    if ((Test-Path $glaze) -and -not (Get-Process glazewm -ErrorAction SilentlyContinue)) {
        Start-Process $glaze -WindowStyle Hidden
    }
}
catch {
    # Never surface a dialog after a game exits.
}
