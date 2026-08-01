#requires -Version 5.1
<#
  post-game.ps1 — Playnite global "Game exited script" body.

  Puts back what pre-game.ps1 took away.

  1. AutoHotkey (quake-hotkey.ahk: backtick WezTerm dropdown, mac-style Alt
     remaps, Win+Shift+S -> ShareX).

  2. GlazeWM. It is killed before a game so it cannot fight over the game's
     window, and restarted here. GlazeWM rebuilds entirely from config on start,
     so workspaces re-home to their bind_to_monitor screens by themselves — there
     is nothing to save and restore.

  Both launch the exe DIRECTLY rather than via a Startup .lnk — a shortcut is an
  untracked binary blob chezmoi cannot manage, and when one went missing the
  restore silently no-opped behind a Test-Path guard.

  NOTE: neither can run if the machine hard-locks or is reset mid-game. If AHK or
  the tiling is dead after a crash, that is why — AHK comes back from Raycast
  ("AHK On"), and GlazeWM from its Startup shortcut or by running it directly.
#>
param(
    [object] $Game
)

$ErrorActionPreference = 'Continue'

try {
    $exe = "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe"
    $ahk = "$env:USERPROFILE\.config\scripts\wezterm\quake-hotkey.ahk"
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
