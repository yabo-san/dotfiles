# Raycast Script Command (Windows / PowerShell)
# Kill AHK so a game gets raw input (anti-cheat safe), as Playnite's PreScript does; for games launched outside it.

# @raycast.schemaVersion 1
# @raycast.title AHK Off (game mode)
# @raycast.mode silent
# @raycast.packageName AHK

# Optional:
# @raycast.icon 🎮
# @raycast.description Kill AutoHotkey so games get raw input (= Playnite PreScript)

Get-Process AutoHotkey* -ErrorAction SilentlyContinue | Stop-Process -Force
