# restore-crt.ps1
# Example script to move a specific workspace (e.g., Music/3) back to the CRT.
# Used when you actually WANT to use the CRT.

$crtName = "\\.\DISPLAY3"

# Move workspace 3 (Music) to the CRT.
glazewm.exe command "move-workspace --workspace 3 --monitor $crtName"

# Focus it.
glazewm.exe command "focus --workspace 3"
