-- █▄▀ █▀▀ █▄█ █▄▄ █ █▄░█ █▀▄ █ █▄░█ █▀▀ █▀
-- █░█ ██▄ ░█░ █▄█ █ █░▀█ █▄▀ █ █░▀█ █▄█ ▄█
--
-- MODULE 9: KEYBINDINGS
-- Keyboard shortcuts and input handling
-- See: https://wiki.hypr.land/Configuring/Basics/Binds/
-- ═══════════════════════════════════════════════════════════════

local vars = require("modules.variables")
local m    = vars.mainMod

-- ▓▒░ BIND HELPER + CHEATSHEET REGISTRY
-- Every bind in this file goes through bind(), which is hl.bind() plus one
-- thing: it records the action under its modmask + key, so the quickshell
-- cheatsheet (SUPER+H) can run a bind it lists:
--   hyprctl eval 'cheatsheet.run(64, "Q")'
-- `hyprctl binds -j` shows Lua binds only as dispatcher "__lua" with an opaque
-- id, so without this the cheatsheet could list binds but never run one.
-- `cheatsheet` is a global on purpose: `hyprctl eval` runs in this Lua state
-- and can only reach globals. It is rebuilt on every config reload.
--
-- Every description is "Category: Action". The cheatsheet splits it into its
-- left-rail category and the row title, so keep that shape when adding binds.
-- Binds whose descriptions differ only by a trailing direction (left/right/
-- up/down) or number collapse into one row there ("Focus window ←→↑↓").
local MOD_MASKS = { SHIFT = 1, CAPS = 2, CTRL = 4, CONTROL = 4, ALT = 8,
                    MOD2 = 16, MOD3 = 32, SUPER = 64, MOD4 = 64, MOD5 = 128 }

cheatsheet = { actions = {} }

function cheatsheet.run(mask, key)
    local action = cheatsheet.actions[mask .. ":" .. key]
    if action then hl.dispatch(action) end
end

local function bind(keys, action, opts)
    local parts = {}
    for part in keys:gmatch("[^+]+") do
        parts[#parts + 1] = part:match("^%s*(.-)%s*$")
    end
    local mask = 0
    for i = 1, #parts - 1 do
        mask = mask + (MOD_MASKS[parts[i]:upper()] or 0)
    end
    cheatsheet.actions[mask .. ":" .. parts[#parts]] = action
    return hl.bind(keys, action, opts)
end

-- ▓▒░ APPLICATION LAUNCHER BINDINGS
bind(m .. " + T", hl.dsp.exec_cmd(vars.terminal), { description = "Apps: Terminal (kitty)" })
bind(m .. " + E", hl.dsp.exec_cmd(vars.fileManager), { description = "Apps: File manager (yazi)" })
bind(m .. " + F", hl.dsp.exec_cmd(vars.browser), { description = "Apps: Browser (Firefox)" })
bind(m .. " + C", hl.dsp.exec_cmd(vars.terminal_editor), { description = "Apps: Editor (Neovim)" })     -- kitty -e nvim (NvChad)
bind(m .. " + O", hl.dsp.exec_cmd(vars.notingApp), { description = "Apps: Notes (Obsidian)" })
bind(m .. " + D", hl.dsp.exec_cmd(vars.discord), { description = "Apps: Discord" })
bind(m .. " + U", hl.dsp.exec_cmd(vars.updater), { description = "System: Update system (pacman -Syu)" })              -- CachyOS system updater
-- hl.bind(m .. " + G", hl.dsp.exec_cmd(vars.antigravity))
if vars.thePlan then   -- nil unless installed (modules/variables.lua)
    bind(m .. " + Y", hl.dsp.exec_cmd(vars.thePlan), { description = "Apps: The Plan" })
end

-- ▓▒░ QUICKSHELL PANEL TRIGGERS
-- These use Hyprland's global_shortcuts protocol to signal quickshell panels.
-- The panels register matching appid+name pairs via GlobalShortcut in QML.
-- See: https://wiki.hypr.land/Configuring/Basics/Binds/#global-shortcuts
bind(m .. " + A",         hl.dsp.global("quickshell:toggle-launcher"), { description = "Panels: App launcher" })
bind(m .. " + Space",     hl.dsp.global("quickshell:toggle-wallpaper-selector"), { description = "Panels: Wallpaper selector" })
bind(m .. " + B",         hl.dsp.global("quickshell:focus-bar"), { description = "Panels: Focus the bar (keyboard navigation)" })
bind(m .. " + Backspace", hl.dsp.global("quickshell:toggle-power-menu"), { description = "Panels: Power menu" })
bind("Print",             hl.dsp.global("quickshell:toggle-screenshot"), { description = "Capture: Screenshot panel (copy / save)" })
bind(m .. " + H",         hl.dsp.global("quickshell:toggle-shortcuts"), { description = "Panels: Keybind cheatsheet" })
bind(m .. " + comma",     hl.dsp.global("quickshell:toggle-notifications"), { description = "Panels: Notifications + Do Not Disturb" })
bind(m .. " + grave",     hl.dsp.global("quickshell:toggle-overview"), { description = "Panels: Window overview" })

-- ▓▒░ WINDOW MANAGEMENT
bind(m .. " + Q",             hl.dsp.window.close(), { description = "Windows: Close window" })
bind(m .. " + W",             hl.dsp.window.float({ action = "toggle" }), { description = "Windows: Toggle floating" })
bind(m .. " + P",             hl.dsp.window.pseudo(), { description = "Windows: Toggle pseudotile" })
bind(m .. " + J",             hl.dsp.layout("togglesplit"), { description = "Windows: Toggle split direction" })   -- dwindle.preserve_split needs this bind to matter
bind("ALT + SHIFT + Return",  hl.dsp.window.fullscreen({ mode = "fullscreen",  action = "toggle" }), { description = "Windows: Fullscreen" })
bind("ALT + Return",          hl.dsp.window.fullscreen({ mode = "maximized",   action = "toggle" }), { description = "Windows: Maximize" })

-- ▓▒░ WINDOW RESIZE (repeating)
bind(m .. " + SHIFT + right", hl.dsp.window.resize({ x = 30, y = 0, relative = true }),  { repeating = true, description = "Windows: Resize window right" })
bind(m .. " + SHIFT + left",  hl.dsp.window.resize({ x = -30, y = 0, relative = true }), { repeating = true, description = "Windows: Resize window left" })
bind(m .. " + SHIFT + up",    hl.dsp.window.resize({ x = 0, y = -30, relative = true }), { repeating = true, description = "Windows: Resize window up" })
bind(m .. " + SHIFT + down",  hl.dsp.window.resize({ x = 0, y = 30, relative = true }),  { repeating = true, description = "Windows: Resize window down" })

-- ▓▒░ KEYBOARD LAYOUT SWITCHING
-- Cycles through input.kb_layout (modules/input.lua, per-host override in hosts/)
-- locked: also fires under hyprlock, so the password can be typed in either
-- layout. hyprlock reads the xkb group from the compositor and redraws its
-- $LAYOUT label on the switch (hyprlock.conf).
bind(m .. " + K", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { locked = true, description = "System: Switch keyboard layout" })

-- ▓▒░ CLIPBOARD MANAGEMENT
-- SUPER+V opens clipboard history via the quickshell ClipboardPanel
bind(m .. " + V",         hl.dsp.global("quickshell:toggle-clipboard"), { description = "Panels: Clipboard history" })
bind(m .. " + SHIFT + V", hl.dsp.exec_cmd("cliphist wipe"), { description = "Panels: Wipe clipboard history" })

-- ▓▒░ SCREENSHOT BINDINGS
-- F11: Direct region capture → clipboard (fast, no UI)
-- The grim/wl-copy pair MUST stay braced. `||` and `&&` are equal precedence and
-- left-associative, so the unbraced form parsed as (pkill || grim) && wl-copy:
-- pressing F11 to cancel an open slurp killed the selection and then copied the
-- *previous* capture off the temp file. F12 never had this because `|` binds
-- tighter than `||`, which is why only this line needed the braces.
bind("F11", hl.dsp.exec_cmd(
    'sh -c \'TEMP="/tmp/screenshot_region.png"; pkill -x slurp || { grim -g "$(slurp)" "$TEMP" && wl-copy -t image/png < "$TEMP"; }\''
), { description = "Capture: Region to clipboard" })
-- F12: Region capture → Satty annotation → save & clipboard
bind("F12", hl.dsp.exec_cmd(
    'sh -c \'mkdir -p ~/Pictures/Screenshots; pkill -x slurp || grim -g "$(slurp)" - | satty --filename - --output-filename ~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png\''
), { description = "Capture: Region to Satty (annotate + save)" })
-- SUPER+Print: close all windows first -- captures the desktop as the README
-- preview and pushes it (chezmoi scripts/showcase.sh)
bind(m .. " + Print", hl.dsp.exec_cmd('sh -c \'"$(chezmoi source-path)/scripts/showcase.sh"\''), { description = "Capture: Desktop showcase for the README" })
-- Print: Opens the quickshell ScreenshotPanel (Copy / Save / Save & Copy)
-- (handled by the global_shortcuts bind above)

-- ▓▒░ WINDOW FOCUS NAVIGATION
bind(m .. " + left",  hl.dsp.focus({ direction = "left"  }), { description = "Windows: Focus window left" })
bind(m .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Windows: Focus window right" })
bind(m .. " + up",    hl.dsp.focus({ direction = "up"    }), { description = "Windows: Focus window up" })
bind(m .. " + down",  hl.dsp.focus({ direction = "down"  }), { description = "Windows: Focus window down" })

-- ▓▒░ WORKSPACE SWITCHING & MOVE WINDOW TO WORKSPACE
for i = 1, 10 do
    local key = i % 10    -- 10 maps to key 0
    bind(m .. " + "           .. key, hl.dsp.focus({ workspace = i }),       { description = "Workspaces: Go to workspace " .. i })
    bind(m .. " + SHIFT + "   .. key, hl.dsp.window.move({ workspace = i }), { description = "Workspaces: Move window to workspace " .. i })
end

-- ▓▒░ SPECIAL WORKSPACES (SCRATCHPADS)
-- Drop-down terminal (SUPER+S)
bind(m .. " + S",         hl.dsp.workspace.toggle_special("terminal"), { description = "Workspaces: Scratchpad terminal" })
bind(m .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:terminal" }), { description = "Workspaces: Send window to scratchpad terminal" })
-- Notes / Obsidian (SUPER+N)
bind(m .. " + N",         hl.dsp.workspace.toggle_special("notes"), { description = "Workspaces: Scratchpad notes" })
bind(m .. " + SHIFT + N", hl.dsp.window.move({ workspace = "special:notes" }), { description = "Workspaces: Send window to scratchpad notes" })

-- ▓▒░ WORKSPACE CYCLING (scroll wheel + arrow key overrides)
bind(m .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next workspace (scroll)" })
bind(m .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous workspace (scroll)" })

-- ▓▒░ MOUSE BINDINGS — drag and resize windows
bind(m .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Windows: Drag window" })
bind(m .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Windows: Resize window (drag)" })

-- ▓▒░ MULTIMEDIA & BRIGHTNESS (laptop function keys)
-- NOTE: brightnessctl is NOT installed on hyprcachyos, so the two XF86MonBrightness
--       binds below are inert here. Kept deliberately — they are laptop function
--       keys and this one tree runs on both machines. `pacman -S brightnessctl`
--       on a host that has a backlight. Same for playerctl in the next block.
--       The wpctl binds work: wireplumber is installed.
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Media: Volume up" })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Media: Volume down" })
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, description = "Media: Mute output" })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Media: Mute microphone" })
bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"),                  { locked = true, repeating = true, description = "Media: Brightness up" })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"),                  { locked = true, repeating = true, description = "Media: Brightness down" })

-- ▓▒░ MEDIA CONTROL
-- NOTE: playerctl is NOT installed on hyprcachyos — these four are inert here.
--       Left in place for portability; `pacman -S playerctl` to activate them.
--       quickshell's bar does not shell out to playerctl, so nothing else covers
--       these keys in the meantime.
bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true, description = "Media: Next track" })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause" })
bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Media: Play / pause" })
bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true, description = "Media: Previous track" })

-- ▓▒░ WALLPAPER TRANSITION (SUPER + SHIFT + W)
bind(m .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/awww_transition.sh"), { description = "System: Random wallpaper" })

-- ▓▒░ OPENRGB COLOR PICKER (SUPER + SHIFT + P)
bind(m .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/pick_rgb.fish"), { description = "System: Pick an OpenRGB colour from the screen" })

-- ▓▒░ SESSION LOCK
-- Emits logind's Lock signal rather than naming hyprlock here; hypridle picks it
-- up and runs its lock_cmd. Same path sleep takes, so the locker is defined once
-- (hypridle.conf) instead of being repeated at every call site.
bind(m .. " + L", hl.dsp.exec_cmd("loginctl lock-session"),
    { description = "System: Lock screen" })

-- NOTE: no lid-switch bind. Lid handling belongs to logind, not Hyprland —
--       closing the lid raises PrepareForSleep, which hypridle's before_sleep_cmd
--       already locks on. A bind here would be a second, redundant path, and
--       Switches warns it can conflict with logind's own HandleLidSwitch.

-- ▓▒░ WINDOW MOVE (direction) — SUPER+SHIFT+arrows stays resize, unchanged
bind(m .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }), { description = "Windows: Move window left" })
bind(m .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }), { description = "Windows: Move window right" })
bind(m .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }), { description = "Windows: Move window up" })
bind(m .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }), { description = "Windows: Move window down" })

-- ▓▒░ MULTI-MONITOR (matters once a laptop is docked)
bind(m .. " + ALT + left",  hl.dsp.focus({ monitor = "-1" }), { description = "Workspaces: Focus previous monitor" })
bind(m .. " + ALT + right", hl.dsp.focus({ monitor = "+1" }), { description = "Workspaces: Focus next monitor" })
bind(m .. " + ALT + SHIFT + left",  hl.dsp.window.move({ monitor = "-1" }), { description = "Workspaces: Move window to previous monitor" })
bind(m .. " + ALT + SHIFT + right", hl.dsp.window.move({ monitor = "+1" }), { description = "Workspaces: Move window to next monitor" })

-- ▓▒░ WORKSPACE CYCLING (keyboard)
bind(m .. " + bracketleft",  hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous workspace" })
bind(m .. " + bracketright", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next workspace" })

-- ▓▒░ WINDOW UTILITIES
bind(m .. " + Tab",           hl.dsp.window.cycle_next(),        { description = "Windows: Cycle to next window" })
bind(m .. " + SHIFT + Return", hl.dsp.window.center(),           { description = "Windows: Center floating window" })
bind(m .. " + SHIFT + Space",  hl.dsp.window.pin(),              { description = "Windows: Pin across workspaces" })
bind(m .. " + CTRL + Q",       hl.dsp.window.kill(),             { description = "Windows: Force-kill window (SIGKILL)" })
bind(m .. " + CTRL + G",       hl.dsp.group.toggle(),            { description = "Windows: Toggle tab group" })

-- ▓▒░ COLOR PICKER (SUPER + I) — hyprpicker is installed but was unbound
bind(m .. " + I", hl.dsp.exec_cmd("hyprpicker -a"), { description = "Capture: Pick a colour to the clipboard" })

-- ▓▒░ RELOAD CONFIG
bind(m .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"), { description = "System: Reload Hyprland config" })
