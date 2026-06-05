#!/bin/bash
# Updated by flashspace_workspace_change event
# $WORKSPACE and $DISPLAY are passed as env vars by flashspace

if [ -n "$WORKSPACE" ]; then
  sketchybar --set space label="  $WORKSPACE"
else
  WORKSPACE=$(aerospace list-workspaces --focused 2>/dev/null || echo "—")
  sketchybar --set space label="  $WORKSPACE"
fi
