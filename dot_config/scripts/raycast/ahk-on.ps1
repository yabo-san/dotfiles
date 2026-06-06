# Raycast Script Command (Windows / PowerShell)
# Relaunch the AHK remap process (quake-hotkey.ahk: Alt copy/undo, Win+W Proton Mail
# quake, Win+Shift+S ShareX, Obsidian Alt-ify). Same thing Playnite's global PostScript
# does after a game exits — here for manual access (e.g. AHK died, or you killed it).

# @raycast.schemaVersion 1
# @raycast.title AHK On
# @raycast.mode silent
# @raycast.packageName AHK

# Optional:
# @raycast.icon ⌨️
# @raycast.description Relaunch AutoHotkey quake-hotkey.ahk (= Playnite PostScript)

$ahk    = "$env:USERPROFILE\scoop\apps\autohotkey\current\v2\AutoHotkey64.exe"
$script = "$env:USERPROFILE\.config\scripts\wezterm\quake-hotkey.ahk"
Get-Process AutoHotkey* -ErrorAction SilentlyContinue | Stop-Process -Force   # avoid duplicates
Start-Sleep -Milliseconds 300
& $ahk $script
