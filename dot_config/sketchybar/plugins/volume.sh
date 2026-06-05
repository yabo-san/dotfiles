#!/bin/bash
# Mirrors YASB volume widget icons
VOL=$(osascript -e 'output volume of (get volume settings)' 2>/dev/null)
MUTED=$(osascript -e 'output muted of (get volume settings)' 2>/dev/null)

if [ "$MUTED" = "true" ] || [ "$VOL" = "0" ]; then
  ICON=$(printf '\xef\x80\xa6')  # U+F026 muted
  COLOR="0xff6c7086"
elif [ "$VOL" -lt 34 ]; then
  ICON=$(printf '\xef\x80\xa7')  # U+F027 low
  COLOR="0xff89b4fa"
else
  ICON=$(printf '\xef\x80\xa8')  # U+F028 high
  COLOR="0xff89b4fa"
fi

sketchybar --set volume icon="$ICON" icon.color="$COLOR" label="${VOL}%"
