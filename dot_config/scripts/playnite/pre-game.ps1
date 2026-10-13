#requires -Version 5.1
# Playnite "game starting" hook: stops AutoHotkey and GlazeWM before a game; post-game.ps1 restarts them.
# GlazeWM freezes a floating window at its first size (games start tiny), so it has to be off, not configured around.
# A throw here cancels the launch, and Playnite's runspace forces ErrorAction Stop, so everything stays in try.
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
