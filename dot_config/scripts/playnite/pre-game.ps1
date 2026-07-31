#requires -Version 5.1
<#
  pre-game.ps1 — Playnite global "Game starting script" body.

  Kills AutoHotkey before a game launches: AHK's low-level keyboard hook is both
  a raw-input liability and an anti-cheat red flag. post-game.ps1 brings it back.

  ⚠️ This is the ONE script whose failure CANCELS the game launch — Playnite
  treats a throw here (or $StartingArgs.CancelStartup = $true) as "don't start".
  $ErrorActionPreference is forced to 'Stop' by Playnite's runspace, so every
  statement must be guarded. Never let anything escape the try.
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
