#!/bin/bash
# Start sketchybar service and mark plugins executable

chmod +x "$HOME/.config/sketchybar/plugins/"*.sh

if command -v sketchybar &>/dev/null; then
  brew services start FelixKratz/formulae/sketchybar 2>/dev/null || true
fi
