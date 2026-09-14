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
hl.bind(m .. " + SHIFT + C", hl.dsp.exec_cmd(vars.editor))      -- neovim (GUI)
hl.bind(m .. " + X", hl.dsp.exec_cmd(vars.calculator))
hl.bind(m .. " + O", hl.dsp.exec_cmd(vars.notingApp))
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

-- ▓▒░ GAMING MODE TOGGLE (SUPER + F5)
hl.bind(m .. " + F5", hl.dsp.exec_cmd("~/.config/hypr/scripts/gaming-mode.sh"))

-- ▓▒░ WALLPAPER TRANSITION (SUPER + SHIFT + W)
hl.bind(m .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/awww_transition.sh"))

-- ▓▒░ OPENRGB COLOR PICKER (SUPER + SHIFT + P)
hl.bind(m .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/pick_rgb.fish"))
