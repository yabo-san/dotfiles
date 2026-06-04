# Raycast Script Command (Windows / PowerShell)
# Bridges a Raycast hotkey -> GlazeWM CLI, for keys GlazeWM's own keyboard
# hook can't capture (e.g. plain Win+L). Bind this to lwin+l in Raycast to
# get move-right on the key GlazeWM refuses to bind.

# @raycast.schemaVersion 1
# @raycast.title Glaze Move Right
# @raycast.mode silent
# @raycast.packageName GlazeWM

# Optional:
# @raycast.icon ➡️
# @raycast.description Move the focused GlazeWM window right (for lwin+l)

& "C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe" command move --direction right
