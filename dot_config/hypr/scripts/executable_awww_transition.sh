#!/bin/bash
# awww Wallpaper Transition — refresh-rate aware
set -euo pipefail

DIR="$HOME/Pictures/Wallpapers"

if [ -n "${1:-}" ]; then
    IMAGE="$1"
else
    # Exclude the wallpaper currently displayed so "random" never picks a no-op
    CURRENT=$(awww query 2>/dev/null | sed -n 's/.*currently displaying: image: //p' | head -1)
    IMAGE=$(find "$DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.gif" \) \
            ! -path "${CURRENT:-/nonexistent}" | shuf -n 1)
fi

if [ -z "${IMAGE:-}" ] || [ ! -f "$IMAGE" ]; then
    echo "awww_transition: no wallpaper found in $DIR" >&2
    exit 1
fi

# Match the transition to the actual panel — was hardcoded to 165, which makes a
# 60Hz laptop render 2.75x the frames it can display.
FPS=$(hyprctl monitors -j 2>/dev/null | grep -o '"refreshRate": *[0-9.]*' \
      | grep -o '[0-9.]*$' | sort -rn | head -1)
FPS=${FPS%%.*}
FPS=${FPS:-60}

# Synchronize Hyprland active border color instantly with the selected wallpaper
python3 "$HOME/.config/hypr/scripts/sync_border.py" "$IMAGE" &

awww img "$IMAGE" \
    --transition-type random \
    --transition-fps "$FPS" \
    --transition-duration 1.5 \
    --transition-step 90
