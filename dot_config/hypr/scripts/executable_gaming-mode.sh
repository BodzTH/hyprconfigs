#!/bin/bash
# Toggle Gaming Mode for Hyprland
# Strips compositor effects and layer surfaces to unlock direct scanout

STATE_FILE="/tmp/hypr-gaming-mode"

if [ -f "$STATE_FILE" ]; then
    # Gaming mode ON → restore normal
    hyprctl reload
    quickshell &>/dev/null & disown
    rm "$STATE_FILE"
    notify-send -u low -t 2000 "🎨 Gaming Mode OFF" "Effects restored"
else
    # Normal → enable gaming mode
    # Strip compositor effects
    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { rounding = 0, active_opacity = 1.0, inactive_opacity = 1.0, blur = { enabled = false }, shadow = { enabled = false }, dim_inactive = false }, general = { gaps_in = 0, gaps_out = 0 } })'
    # Kill layer surfaces that block direct scanout
    pkill -f quickshell 2>/dev/null
    touch "$STATE_FILE"
    notify-send -u low -t 2000 "🎮 Gaming Mode ON" "Bar killed · Direct scanout unlocked"
fi
