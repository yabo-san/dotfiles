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

# --- free the game's workspace ------------------------------------------------
# Closing the game leaves you stranded on an empty workspace, possibly on the CRT
# staring at nothing. GlazeWM deactivates an empty workspace by itself (keep_alive
# is false on 8/9/10), so there is nothing to delete — the missing half is moving
# FOCUS back somewhere sane.
#
# Only runs for games we actually placed. A game carrying Display Helper's own
# "[RC] Display:" feature was never ours to begin with, and an untagged game was
# never moved, so neither needs releasing.
try {
    if (-not $Game) { return }

    $rc = $Game.Features | Where-Object { $_.Name -like '`[RC`] Display: *' } | Select-Object -First 1
    if ($rc) { return }

    $tag = $Game.Tags | Where-Object { $_.Name -like 'display:*' } |
           Select-Object -First 1 -ExpandProperty Name
    if (-not $tag) { return }

    $workspace = '8'
    $wsTag = $Game.Tags | Where-Object { $_.Name -like 'workspace:*' } |
             Select-Object -First 1 -ExpandProperty Name
    if ($wsTag) { $workspace = $wsTag -replace '^workspace:', '' }

    $py = @(
        "$env:USERPROFILE\scoop\apps\python\current\pythonw.exe",
        "$env:USERPROFILE\scoop\apps\python\current\python.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    $worker = Join-Path $env:USERPROFILE '.config\scripts\playnite\place_game_window.py'
    if (-not $py -or -not (Test-Path $worker)) { return }

    Start-Process -FilePath $py -WindowStyle Hidden -ArgumentList @(
        "`"$worker`"", '--mode', 'release', '--workspace', $workspace, '--focus-after', '1'
    ) | Out-Null
}
catch {
    # Never surface a dialog after a game exits.
}
