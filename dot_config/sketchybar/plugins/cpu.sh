#!/bin/bash
CPU=$(top -l 1 -n 0 | grep "CPU usage" | awk '{print int($3+$5)}')
sketchybar --set cpu label="${CPU}%"
