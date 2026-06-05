#!/bin/bash
MEM=$(memory_pressure 2>/dev/null | grep "System memory pressure" | awk '{print $NF}' | tr -d '%')
if [ -z "$MEM" ]; then
  MEM=$(vm_stat | awk '
    /Pages active/   {a=$3}
    /Pages wired/    {w=$4}
    /Pages occupied/ {c=$5}
    END { printf "%d", int((a+w+c)*4096/1073741824) }')
  sketchybar --set memory label="${MEM}GB"
else
  sketchybar --set memory label="${MEM}%"
fi
