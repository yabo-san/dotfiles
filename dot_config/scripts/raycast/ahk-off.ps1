# Raycast Script Command (Windows / PowerShell)
# Kill the AHK remap process (mac-style Alt copy/undo + Win+W quake + ShareX +
# Obsidian Alt-ify) so a game gets RAW native input (anti-cheat safe). This is the
# same thing Playnite's global PreScript does on every game launch — here for manual
# access (e.g. a game launched OUTSIDE Playnite).

# @raycast.schemaVersion 1
# @raycast.title AHK Off (game mode)
# @raycast.mode silent
# @raycast.packageName AHK

# Optional:
# @raycast.icon 🎮
# @raycast.description Kill AutoHotkey so games get raw input (= Playnite PreScript)

Get-Process AutoHotkey* -ErrorAction SilentlyContinue | Stop-Process -Force
