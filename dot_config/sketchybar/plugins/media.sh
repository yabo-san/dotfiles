#!/bin/bash
# Requires: brew install nowplaying-cli
# Mirrors YASB media widget — hidden when nothing is playing
if ! command -v nowplaying-cli &>/dev/null; then
  sketchybar --set media drawing=off
  exit 0
fi

TITLE=$(nowplaying-cli get title 2>/dev/null)
ARTIST=$(nowplaying-cli get artist 2>/dev/null)

if [ -z "$TITLE" ] || [ "$TITLE" = "null" ]; then
  sketchybar --set media drawing=off
  exit 0
fi

if [ -n "$ARTIST" ] && [ "$ARTIST" != "null" ]; then
  LABEL="$ARTIST — $TITLE"
else
  LABEL="$TITLE"
fi

if [ "${#LABEL}" -gt 50 ]; then
  LABEL="${LABEL:0:47}..."
fi

sketchybar --set media drawing=on label="$LABEL"
