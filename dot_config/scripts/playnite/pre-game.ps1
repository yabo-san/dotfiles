#requires -Version 5.1
<#
  pre-game.ps1 — Playnite global "Game starting script" body.

  Gets the two things that interfere with games out of the way before one starts.
  post-game.ps1 brings both back.

  1. AutoHotkey — its low-level keyboard hook is a raw-input liability and an
     anti-cheat red flag.

  2. GlazeWM — the drastic option, and the one that finally settles two days of
     trying to make a tiling WM coexist with games. It does not need to negotiate
     with a game if it is not running.

     Why nothing gentler worked: GlazeWM snapshots a FLOATING window's dimensions
     at the moment it claims it (manage_window.rs:189-209, "use the original
     width/height") and never revisits them. A game creates its window BEFORE it
     knows its resolution — Dishonored's is 160x120 during init — so the game gets
     frozen at that size. Ignore rules, set-tiling and raw SetWindowPos were all
     tried; the WM re-applies its own model and the two sides visibly fight.

     Killing it is clean because GlazeWM rebuilds entirely from config on start:
     workspaces re-home to their bind_to_monitor screens. That path has been
     exercised repeatedly and comes back correct every time.

  ⚠️ This is the ONE script whose failure CANCELS the game launch — Playnite
  treats a throw here (or $StartingArgs.CancelStartup = $true) as "don't start".
  $ErrorActionPreference is forced to 'Stop' by Playnite's runspace, so every
  statement must be guarded. Never let anything escape a try.
#>
param(
    [object] $Game
)

$ErrorActionPreference = 'Continue'

try {
    Get-Process AutoHotkey* -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
catch {
    # Swallow: a failure here would cancel the launch.
}

try {
    Get-Process glazewm -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
}
catch {
    # Swallow: a failure here would cancel the launch.
}
