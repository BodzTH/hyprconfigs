#!/usr/bin/env fish
# OpenRGB Color Picker: 2s delay to switch workspace -> pick pixel -> apply static LED color

sleep 2
set -l color (hyprpicker)

if test -n "$color"
    set -l hex (string replace "#" "" $color)
    openrgb --noautoconnect -m static -c $hex
end
