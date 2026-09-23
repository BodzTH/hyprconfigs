#!/usr/bin/env fish
# OpenRGB Color Picker: 2s delay to switch workspace -> pick pixel -> apply colour
# to every device. OpenRGB itself is driven by openrgb_color.sh (server fast
# path, Static/Direct per device) — the same path the wallpaper sync uses.

if not command -q openrgb
    exit 0
end

sleep 2
set -l color (hyprpicker)

if test -n "$color"
    ~/.config/hypr/scripts/openrgb_color.sh (string replace "#" "" $color)
end
