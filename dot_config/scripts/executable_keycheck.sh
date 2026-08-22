#!/usr/bin/env bash

# Get the main keyboard device name using a custom script
# This script likely returns the identifier for your primary keyboard
main_key_device=$(~/.config/scripts/mainkey.sh)

# Get the current keyboard layout for the main keyboard device
# Steps:
# 1. Reload Hyprland configuration (suppress output with &> /dev/null)
# 2. Get all device information from Hyprland
# 3. Find the section for our main keyboard device (grep -A 2 gets the device + 2 lines after)
# 4. Get the last line of that section (tail -1) which contains the active keymap
# 5. Clean up the output by removing the "active keymap: " prefix
keylayout=""

check_keylayout ()
{
  keylayout=$(hyprctl reload &> /dev/null \
  && hyprctl devices \
  | grep -A 3 "$main_key_device\$" \
  | tail -1 \
  | sed 's/active keymap: //')
}

# Call check_keylayout function
check_keylayout

# Try up to 5 times to switch the keyboard layout to English
for ((i = 0; i < 5; i++)); do
  # Check if the current layout is NOT English
  if [[ "$keylayout" != *"English"* ]]; then
    # Switch to the next keyboard layout for the main device
    # Suppress output since we only care if it works
    hyprctl switchxkblayout "$main_key_device" next &> /dev/null
    # Call check_keylayout function for the updated keylayout
    check_keylayout
  else
    # If we're already on English layout, stop trying
    break 
  fi
done

# Purpose of this script:
# This script ensures your main keyboard is set to English layout.
# It's useful for:
# - Startup scripts to guarantee consistent keyboard layout
# - Hotkey bindings to quickly reset to English
# - Situations where you've switched to another language and want to reset
