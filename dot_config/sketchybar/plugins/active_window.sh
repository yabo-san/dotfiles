#!/bin/bash
# Show focused window title, fall back to app name — mirrors YASB active_window widget
TITLE=$(aerospace list-windows --focused 2>/dev/null \
  | awk -F' [|] ' 'NR==1 { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3 }')

if [ -z "$TITLE" ]; then
  TITLE=$(osascript -e \
    'tell application "System Events" to get name of first application process whose frontmost is true' \
    2>/dev/null)
fi

# Truncate at 46 chars to match YASB max_length
if [ "${#TITLE}" -gt 46 ]; then
  TITLE="${TITLE:0:43}..."
fi

sketchybar --set active_window label="$TITLE"
