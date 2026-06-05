#!/bin/bash
VOL=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null)
MUTED=$(osascript -e 'input muted of (get volume settings)' 2>/dev/null)

if [ "$MUTED" = "true" ]; then
  ICON=$(printf '\xef\x84\xb1')  # U+F131 muted
  COLOR="0xff6c7086"
else
  ICON=$(printf '\xef\x84\xb0')  # U+F130 mic
  COLOR="0xffcba6f7"
fi

sketchybar --set microphone icon="$ICON" icon.color="$COLOR" label="${VOL}%"
