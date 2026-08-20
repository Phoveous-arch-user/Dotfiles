#!/bin/bash
class=$(hyprctl activewindow -j | grep -oP '"class":\s*"\K[^"]+')
locked=("stardew valley.exe" "level devil.exe" "spindle.exe" "ultrakill.exe")
for l in "${locked[@]}"; do
  if [[ "$class" == "$l" ]]; then
    exit 0
  fi
done
hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized" })'
