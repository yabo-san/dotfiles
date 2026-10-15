# Raycast Script Command (Windows / PowerShell)
# Relaunch hotkeys.ahk, as Playnite's PostScript does after a game; for when AHK died or was killed.

# @raycast.schemaVersion 1
# @raycast.title AHK On
# @raycast.mode silent
# @raycast.packageName AHK

# Optional:
# @raycast.icon ⌨️
# @raycast.description Relaunch AutoHotkey hotkeys.ahk (= Playnite PostScript)

$ahk    = "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe"
$script = "$env:USERPROFILE\.config\scripts\hotkeys.ahk"
Get-Process AutoHotkey* -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 300
& $ahk $script
