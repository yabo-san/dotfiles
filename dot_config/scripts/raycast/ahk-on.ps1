# Raycast Script Command (Windows / PowerShell)
# Relaunch hotkeys.ahk: drop-downs (backtick terminal, Win+S Cider), Win+D, Alt copy/paste,
# Obsidian keys. Same thing Playnite's global PostScript
# does after a game exits — here for manual access (e.g. AHK died, or you killed it).

# @raycast.schemaVersion 1
# @raycast.title AHK On
# @raycast.mode silent
# @raycast.packageName AHK

# Optional:
# @raycast.icon ⌨️
# @raycast.description Relaunch AutoHotkey hotkeys.ahk (= Playnite PostScript)

$ahk    = "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe"
$script = "$env:USERPROFILE\.config\scripts\hotkeys.ahk"
Get-Process AutoHotkey* -ErrorAction SilentlyContinue | Stop-Process -Force   # avoid duplicates
Start-Sleep -Milliseconds 300
& $ahk $script
