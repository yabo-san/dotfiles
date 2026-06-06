# evict-crt.ps1
# Evict all primary workspaces (1-7) from the CRT and park workspace 10 there.
# This keeps the display active in Windows but "cleans" it of GlazeWM activity.

$crtName = "\\.\DISPLAY3"
$primaryMonitor = "\\.\DISPLAY1"

# Move workspaces 1-7 to the primary monitor if they are on the CRT.
# Note: GlazeWM CLI handles the logic; if it's already there, it's a no-op.
foreach ($ws in 1..7) {
    glazewm.exe command "move-workspace --workspace $ws --monitor $primaryMonitor"
}

# Move workspace 10 to the CRT to act as a placeholder.
glazewm.exe command "move-workspace --workspace 10 --monitor $crtName"

# Focus back to workspace 1 on main.
glazewm.exe command "focus --workspace 1"
