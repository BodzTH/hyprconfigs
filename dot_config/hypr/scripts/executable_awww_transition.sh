#!/bin/bash
# awww 165Hz Wallpaper Transition Script

DIR="$HOME/Pictures/Wallpapers"

if [ -n "$1" ]; then
    IMAGE="$1"
else
    IMAGE=$(find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" \) | shuf -n 1)
fi

# Synchronize Hyprland active border color instantly with the selected wallpaper
python3 "$HOME/.config/hypr/scripts/sync_border.py" "$IMAGE" &

awww img "$IMAGE" \
    --transition-type random \
    --transition-fps 165 \
    --transition-duration 1.5 \
    --transition-step 90
