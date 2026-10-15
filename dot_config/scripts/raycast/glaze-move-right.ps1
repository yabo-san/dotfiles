# Raycast Script Command (Windows / PowerShell)
# Raycast hotkey -> GlazeWM CLI, for keys GlazeWM's hook can't capture. Bind to lwin+l in Raycast.

# @raycast.schemaVersion 1
# @raycast.title Glaze Move Right
# @raycast.mode silent
# @raycast.packageName GlazeWM

# Optional:
# @raycast.icon ➡️
# @raycast.description Move the focused GlazeWM window right (for lwin+l)

& "C:\Program Files\glzr.io\GlazeWM\cli\glazewm.exe" command move --direction right
