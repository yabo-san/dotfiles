#requires -Version 5.1
<#
  post-game.ps1 — Playnite global "Game exited script" body.

  Restores AutoHotkey (quake-hotkey.ahk: backtick WezTerm dropdown, mac-style
  Alt remaps, Win+Shift+S -> ShareX) after a game exits.

  Launches the exe DIRECTLY rather than via the Startup .lnk — a shortcut is an
  untracked binary blob that chezmoi cannot manage, and when it went missing the
  restore silently no-opped behind a Test-Path guard.

  NOTE: this cannot run if the machine hard-locks or is reset mid-game. If AHK
  is dead after a crash, that's why — re-run it from Raycast ("AHK On").
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
