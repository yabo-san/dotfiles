#!/bin/bash
CURRENT=$(aerospace list-workspaces --focused 2>/dev/null)
osascript -e 'tell application "Ghostty" to activate'
sleep 0.05
osascript -e 'tell application "System Events" to key code 50'
sleep 0.1
[ -n "$CURRENT" ] && aerospace workspace "$CURRENT"
