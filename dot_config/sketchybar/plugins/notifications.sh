#!/bin/bash
# Read unread count from Notification Center db (needs Full Disk Access)
DB=~/Library/Group\ Containers/group.com.apple.usernoted/db2/db
COUNT=$(sqlite3 "$DB" \
  "SELECT COUNT(*) FROM record WHERE delivered_date > 0 AND shown = 0;" 2>/dev/null)

if [ -n "$COUNT" ] && [ "$COUNT" -gt 0 ] 2>/dev/null; then
  sketchybar --set notifications drawing=on label="$COUNT"
else
  sketchybar --set notifications drawing=off
fi
