#!/usr/bin/env fish
# OpenRGB Color Picker: 2s delay to switch workspace -> pick pixel -> apply static LED color

if not command -q openrgb
    exit 0
end

sleep 2
set -l color (hyprpicker)

if test -n "$color"
    set -l hex (string replace "#" "" $color)
    openrgb --noautoconnect -m static -c $hex
end
