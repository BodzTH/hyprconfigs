-- █▄▀ █▀▀ █▄█ █▄▄ █ █▄░█ █▀▄ █ █▄░█ █▀▀ █▀
-- █░█ ██▄ ░█░ █▄█ █ █░▀█ █▄▀ █ █░▀█ █▄█ ▄█
--
-- MODULE 9: KEYBINDINGS
-- Keyboard shortcuts and input handling
-- See: https://wiki.hypr.land/Configuring/Basics/Binds/
-- ═══════════════════════════════════════════════════════════════

local vars = require("modules.variables")
local m    = vars.mainMod

-- ▓▒░ APPLICATION LAUNCHER BINDINGS
hl.bind(m .. " + T", hl.dsp.exec_cmd(vars.terminal))
hl.bind(m .. " + E", hl.dsp.exec_cmd(vars.fileManager))
hl.bind(m .. " + F", hl.dsp.exec_cmd(vars.browser))
hl.bind(m .. " + C", hl.dsp.exec_cmd(vars.terminal_editor))     -- kitty -e nvim (NvChad)
hl.bind(m .. " + O", hl.dsp.exec_cmd(vars.notingApp))
hl.bind(m .. " + D", hl.dsp.exec_cmd(vars.discord))
hl.bind(m .. " + U", hl.dsp.exec_cmd(vars.updater))              -- CachyOS system updater
hl.bind(m .. " + G", hl.dsp.exec_cmd(vars.antigravity))

-- ▓▒░ QUICKSHELL PANEL TRIGGERS
-- These use Hyprland's global_shortcuts protocol to signal quickshell panels.
-- The panels register matching appid+name pairs via GlobalShortcut in QML.
-- See: https://wiki.hypr.land/Configuring/Basics/Binds/#global-shortcuts
hl.bind(m .. " + A",         hl.dsp.global("quickshell:toggle-launcher"))
hl.bind(m .. " + Space",     hl.dsp.global("quickshell:toggle-wallpaper-selector"))
hl.bind(m .. " + B",         hl.dsp.global("quickshell:focus-bar"))
hl.bind(m .. " + Backspace", hl.dsp.global("quickshell:toggle-power-menu"))
hl.bind("Print",             hl.dsp.global("quickshell:toggle-screenshot"))

-- ▓▒░ WINDOW MANAGEMENT
hl.bind(m .. " + Q",             hl.dsp.window.close())
hl.bind(m .. " + W",             hl.dsp.window.float({ action = "toggle" }))
hl.bind(m .. " + P",             hl.dsp.window.pseudo())
hl.bind(m .. " + J",             hl.dsp.layout("togglesplit"))   -- dwindle.preserve_split needs this bind to matter
hl.bind("ALT + SHIFT + Return",  hl.dsp.window.fullscreen({ mode = "fullscreen",  action = "toggle" }))
hl.bind("ALT + Return",          hl.dsp.window.fullscreen({ mode = "maximized",   action = "toggle" }))

-- ▓▒░ WINDOW RESIZE (repeating)
hl.bind(m .. " + SHIFT + right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }),  { repeating = true })
hl.bind(m .. " + SHIFT + left",  hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true })
hl.bind(m .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true })
hl.bind(m .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = 30, relative = true }),  { repeating = true })

-- ▓▒░ KEYBOARD LAYOUT SWITCHING
-- Cycles between us and ara layouts
hl.bind(m .. " + K", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

-- ▓▒░ CLIPBOARD MANAGEMENT
-- SUPER+V opens clipboard history via the quickshell ClipboardPanel
hl.bind(m .. " + V",         hl.dsp.global("quickshell:toggle-clipboard"))
hl.bind(m .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist wipe"))

-- ▓▒░ SCREENSHOT BINDINGS
-- F11: Direct region capture → clipboard (fast, no UI)
hl.bind("F11", hl.dsp.exec_cmd(
    'sh -c \'TEMP="/tmp/screenshot_region.png"; grim -g "$(slurp)" "$TEMP" && wl-copy -t image/png < "$TEMP"\''
))
-- F12: Region capture → Satty annotation → save & clipboard
hl.bind("F12", hl.dsp.exec_cmd(
    'sh -c \'mkdir -p ~/Pictures/Screenshots; grim -g "$(slurp)" - | satty --filename - --output-filename ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png\''
))
-- SUPER+Print: close all windows first -- captures the desktop as the README
-- preview and pushes it (chezmoi scripts/showcase.sh)
hl.bind(m .. " + Print", hl.dsp.exec_cmd('sh -c \'"$(chezmoi source-path)/scripts/showcase.sh"\''))
-- Print: Opens the quickshell ScreenshotPanel (Copy / Save / Save & Copy)
-- (handled by the global_shortcuts bind above)

-- ▓▒░ WINDOW FOCUS NAVIGATION
hl.bind(m .. " + left",  hl.dsp.focus({ direction = "left"  }))
hl.bind(m .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(m .. " + up",    hl.dsp.focus({ direction = "up"    }))
hl.bind(m .. " + down",  hl.dsp.focus({ direction = "down"  }))

-- ▓▒░ WORKSPACE SWITCHING & MOVE WINDOW TO WORKSPACE
for i = 1, 10 do
    local key = i % 10    -- 10 maps to key 0
    hl.bind(m .. " + "           .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(m .. " + SHIFT + "   .. key, hl.dsp.window.move({ workspace = i }))
end

-- ▓▒░ SPECIAL WORKSPACES (SCRATCHPADS)
-- Drop-down terminal (SUPER+S)
hl.bind(m .. " + S",         hl.dsp.workspace.toggle_special("terminal"))
hl.bind(m .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:terminal" }))
-- Notes / Obsidian (SUPER+N)
hl.bind(m .. " + N",         hl.dsp.workspace.toggle_special("notes"))
hl.bind(m .. " + SHIFT + N", hl.dsp.window.move({ workspace = "special:notes" }))

-- ▓▒░ WORKSPACE CYCLING (scroll wheel + arrow key overrides)
hl.bind(m .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(m .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- ▓▒░ MOUSE BINDINGS — drag and resize windows
hl.bind(m .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(m .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ▓▒░ MULTIMEDIA & BRIGHTNESS (laptop function keys)
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true })

-- ▓▒░ MEDIA CONTROL
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- ▓▒░ WALLPAPER TRANSITION (SUPER + SHIFT + W)
hl.bind(m .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/awww_transition.sh"))

-- ▓▒░ OPENRGB COLOR PICKER (SUPER + SHIFT + P)
hl.bind(m .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/pick_rgb.fish"))

-- ▓▒░ SESSION LOCK
-- No lock keybind existed before — hyprlock was only reachable via hypridle's timers.
hl.bind(m .. " + L", hl.dsp.exec_cmd("pidof hyprlock || hyprlock --grace 1"),
    { description = "Lock the screen" })

-- Laptop lid switch — a silent no-op on machines with no lid device.
-- Verify the exact name with `hyprctl devices` if it doesn't fire.
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("pidof hyprlock || hyprlock --grace 1"),
    { locked = true, description = "Lock on lid close" })

-- ▓▒░ WINDOW MOVE (direction) — SUPER+SHIFT+arrows stays resize, unchanged
hl.bind(m .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }), { description = "Move window left" })
hl.bind(m .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }), { description = "Move window right" })
hl.bind(m .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }), { description = "Move window up" })
hl.bind(m .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }), { description = "Move window down" })

-- ▓▒░ MULTI-MONITOR (matters once a laptop is docked)
hl.bind(m .. " + ALT + left",  hl.dsp.focus({ monitor = "-1" }), { description = "Focus previous monitor" })
hl.bind(m .. " + ALT + right", hl.dsp.focus({ monitor = "+1" }), { description = "Focus next monitor" })
hl.bind(m .. " + ALT + SHIFT + left",  hl.dsp.window.move({ monitor = "-1" }), { description = "Move window to previous monitor" })
hl.bind(m .. " + ALT + SHIFT + right", hl.dsp.window.move({ monitor = "+1" }), { description = "Move window to next monitor" })

-- ▓▒░ WORKSPACE CYCLING (keyboard)
hl.bind(m .. " + bracketleft",  hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })
hl.bind(m .. " + bracketright", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })

-- ▓▒░ WINDOW UTILITIES
hl.bind(m .. " + Tab",           hl.dsp.window.cycle_next(),        { description = "Cycle to next window" })
hl.bind(m .. " + SHIFT + Return", hl.dsp.window.center(),           { description = "Center floating window" })
hl.bind(m .. " + SHIFT + Space",  hl.dsp.window.pin(),              { description = "Pin window across workspaces" })
hl.bind(m .. " + CTRL + Q",       hl.dsp.window.kill(),             { description = "Force-kill window (SIGKILL)" })
hl.bind(m .. " + CTRL + G",       hl.dsp.group.toggle(),            { description = "Toggle window group (tabs)" })

-- ▓▒░ COLOR PICKER (SUPER + I) — hyprpicker is installed but was unbound
hl.bind(m .. " + I", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Pick a color to clipboard" })

-- ▓▒░ RELOAD CONFIG
hl.bind(m .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "Reload Hyprland config" })
