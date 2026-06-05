#!/bin/bash
# Called for each space.N item on aerospace_workspace_change
WS_ID="${NAME#space.}"

FOCUSED="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused 2>/dev/null | tr -d ' ')}"

if [ "$FOCUSED" = "$WS_ID" ]; then
  sketchybar --set "$NAME" icon.color="0xff89b4fa"  # active — blue
else
  WIN_COUNT=$(aerospace list-windows --workspace "$WS_ID" 2>/dev/null | grep -c .)
  if [ "$WIN_COUNT" -gt 0 ]; then
    sketchybar --set "$NAME" icon.color="0xff74c7ec"  # populated — teal
  else
    sketchybar --set "$NAME" icon.color="0xff6c7086"  # empty — dim
  fi
fi
