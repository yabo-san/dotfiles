# @raycast.schemaVersion 1
# @raycast.title Launch Steam
# @raycast.mode silent
# @raycast.packageName Apps
# @raycast.icon 🎮
# @raycast.description Open the Steam client (Games category is disabled in Raycast,
#   which hides Steam itself — this Script Command makes the client findable without
#   re-flooding Raycast with the whole 380-game library).

Start-Process "C:\Program Files (x86)\Steam\steam.exe"
