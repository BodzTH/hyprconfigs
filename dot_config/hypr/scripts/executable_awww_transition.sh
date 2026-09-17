#!/usr/bin/env bash
# Set a wallpaper with an awww transition and sync the border color to it.
# Usage: awww_transition.sh [IMAGE]   (no IMAGE = random, never the current one)

DIR="$HOME/Pictures/Wallpapers"
IMAGE="$1"

if [ -z "$IMAGE" ]; then
    CURRENT=$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -1)
    IMAGE=$(find "$DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
            ! -path "${CURRENT:-/none}" 2>/dev/null | shuf -n 1)
fi

if [ ! -f "$IMAGE" ]; then
    notify-send "Wallpaper" "No wallpaper found in $DIR" 2>/dev/null
    exit 1
fi

# Transition at the fastest connected monitor's refresh rate (60 if unknown)
FPS=$(hyprctl monitors -j 2>/dev/null | jq '[.[].refreshRate] | max | floor' 2>/dev/null)
[[ "$FPS" =~ ^[0-9]+$ ]] || FPS=60

python3 "$HOME/.config/hypr/scripts/sync_border.py" "$IMAGE" &
awww img "$IMAGE" --transition-type random --transition-fps "$FPS" \
    --transition-duration 1.5 --transition-step 90
