#!/bin/bash
BATT=$(pmset -g batt | grep -o '[0-9]*%' | tr -d '%')
CHARGING=$(pmset -g batt | grep -c 'AC Power')

if [ "$CHARGING" -gt 0 ]; then
  ICON=""
  COLOR="#a6e3a1"
elif [ "$BATT" -le 20 ]; then
  ICON=""
  COLOR="#f38ba8"
elif [ "$BATT" -le 50 ]; then
  ICON=""
  COLOR="#f9e2af"
else
  ICON=""
  COLOR="#a6e3a1"
fi

sketchybar --set battery icon="$ICON" icon.color="$COLOR" label="${BATT}%"
