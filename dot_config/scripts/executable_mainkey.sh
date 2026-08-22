#!/usr/bin/env bash

# Script Purpose: Find and return the name of the main/primary input device in Hyprland
# This is typically used to identify which keyboard device to target for layout changes

# Step-by-step breakdown:
# 1. Get all connected devices from Hyprland
# 2. Find the line containing "main: yes" and include 5 lines BEFORE it
# The -B 5 flag means "show 5 lines Before the match"
# This captures the device information that appears above the "main: yes" line
# 3. Take only the first line from the result
# This should be the device name/identifier line
# 4. Remove any leading whitespace (spaces or tabs) to clean up the output
# The regex ^[ \t]* matches any amount of leading spaces or tabs
hyprctl devices \
| grep -B 6 "main: yes" \
| head -1 \
| sed 's/^[ \t]*//'

# Example Hyprland device output structure:
# Keyboard:
#   AT Translated Set 2 keyboard
#   rules: r "", m: "", l: "", v: "", o: ""
#   active keymap: English (US)
#   main: yes
#
# This script would return: "AT Translated Set 2 keyboard"

# Common use cases:
# - Called by other scripts that need to know the main keyboard device
# - Used in keyboard layout management automation
# - Referenced in Hyprland configuration scripts'
