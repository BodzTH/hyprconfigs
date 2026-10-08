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
    -- A locked bind is one meant to work on the lock screen, and the lock
    -- screen runs inside the "lockscreen" submaps (end of this file), where
    -- only universal binds survive.
    if opts and opts.locked then opts.submap_universal = true end
    return hl.bind(keys, action, opts)
end

-- ▓▒░ APPLICATION LAUNCHER BINDINGS
bind(m .. " + T", hl.dsp.exec_cmd(vars.terminal), { description = "Apps: Terminal (kitty)" })
bind(m .. " + E", hl.dsp.exec_cmd(vars.fileManager), { description = "Apps: File manager (yazi)" })
bind(m .. " + F", hl.dsp.exec_cmd(vars.browser), { description = "Apps: Browser (Firefox)" })
bind(m .. " + C", hl.dsp.exec_cmd(vars.terminal_editor), { description = "Apps: Editor (Neovim)" })     -- kitty -e nvim (NvChad)
bind(m .. " + O", hl.dsp.exec_cmd(vars.notingApp), { description = "Apps: Notes (Obsidian)" })
bind(m .. " + D", hl.dsp.exec_cmd(vars.discord), { description = "Apps: Discord" })
bind(m .. " + U", hl.dsp.exec_cmd(vars.updater), { description = "Apps: Update system (pacman -Syu)" })                -- CachyOS system updater
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

-- ▓▒░ GROUP TABS — SUPER+SHIFT+↑↓ moves the active tab's position; switching
-- tabs is SUPER+↑↓ (ARROW NAVIGATION below). SUPER+SHIFT+←→ switched tabs too
-- until 2026-10-07 and was dropped as a duplicate, so it's free.
-- (keyboard resize is gone; resize with SUPER+right-drag)
bind(m .. " + SHIFT + up",    hl.dsp.group.move_window({ forward = false }), { description = "Windows: Move group tab up" })
bind(m .. " + SHIFT + down",  hl.dsp.group.move_window(),                    { description = "Windows: Move group tab down" })

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

-- ▓▒░ ARROW NAVIGATION — ←→ cycles workspaces, ↑↓ cycles tabs in a group
bind(m .. " + left",  hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Switch workspace left" })
bind(m .. " + right", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Switch workspace right" })
bind(m .. " + up",    hl.dsp.group.prev(),                 { description = "Windows: Switch group tab up" })
bind(m .. " + down",  hl.dsp.group.next(),                 { description = "Windows: Switch group tab down" })

-- ▓▒░ WINDOW FOCUS NAVIGATION (directional)
bind(m .. " + ALT + left",  hl.dsp.focus({ direction = "left"  }), { description = "Windows: Focus window left" })
bind(m .. " + ALT + right", hl.dsp.focus({ direction = "right" }), { description = "Windows: Focus window right" })
bind(m .. " + ALT + up",    hl.dsp.focus({ direction = "up"    }), { description = "Windows: Focus window up" })
bind(m .. " + ALT + down",  hl.dsp.focus({ direction = "down"  }), { description = "Windows: Focus window down" })

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

-- ▓▒░ WORKSPACE CYCLING (scroll wheel)
bind(m .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces: Next workspace (scroll)" })
bind(m .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces: Previous workspace (scroll)" })

-- ▓▒░ MOUSE BINDINGS — drag and resize windows
bind(m .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Windows: Drag window" })
bind(m .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Windows: Resize window (drag)" })

-- ▓▒░ MULTIMEDIA & BRIGHTNESS (laptop function keys)
-- The wpctl binds work everywhere: wireplumber is installed.
bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true, description = "Media: Volume up" })
bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true, description = "Media: Volume down" })
bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true, description = "Media: Mute output" })
bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true, description = "Media: Mute microphone" })
-- Brightness only where brightnessctl is installed (a host with a backlight;
-- hyprcachyos has neither). Like the personal apps in modules/variables.lua:
-- no bind, and no cheatsheet row, for a key that would silently do nothing.
local brightnessctl = io.open("/usr/bin/brightnessctl", "r")
if brightnessctl then
    brightnessctl:close()
    bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true, description = "Media: Brightness up" })
    bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true, description = "Media: Brightness down" })
end

-- ▓▒░ MEDIA CONTROL
-- quickshell drives the player over MPRIS (shell.qml, "MEDIA KEYS"), the same
-- player the bar's media widget shows. These used to run playerctl, which isn't
-- installed, so the keys did nothing.
bind("XF86AudioNext",  hl.dsp.global("quickshell:media-next"),       { locked = true, description = "Media: Next track" })
bind("XF86AudioPause", hl.dsp.global("quickshell:media-play-pause"), { locked = true, description = "Media: Play / pause" })
bind("XF86AudioPlay",  hl.dsp.global("quickshell:media-play-pause"), { locked = true, description = "Media: Play / pause" })
bind("XF86AudioPrev",  hl.dsp.global("quickshell:media-previous"),   { locked = true, description = "Media: Previous track" })

-- ▓▒░ WALLPAPER TRANSITION (SUPER + SHIFT + W)
bind(m .. " + SHIFT + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/awww_transition.sh"), { description = "System: Random wallpaper" })

-- ▓▒░ OPENRGB COLOR PICKER (SUPER + SHIFT + P)
bind(m .. " + SHIFT + P", hl.dsp.exec_cmd("~/.config/hypr/scripts/pick_rgb.fish"), { description = "System: Pick an OpenRGB colour from the screen" })

-- ▓▒░ SESSION LOCK
-- NOTE: the SUPER+L lock bind was removed on 2026-10-09 at Bodz's request. Lock
-- from the power menu (SUPER+Backspace) or let the idle timer do it; both emit
-- `loginctl lock-session`, so hypridle.conf's lock_cmd stays the one locker.

-- NOTE: no lid-switch bind. Lid handling belongs to logind, not Hyprland —
--       closing the lid raises PrepareForSleep, which hypridle's before_sleep_cmd
--       already locks on. A bind here would be a second, redundant path, and
--       Switches warns it can conflict with logind's own HandleLidSwitch.

-- ▓▒░ WINDOW MOVE (direction) — SUPER+CTRL+arrows (SUPER+SHIFT+↑↓ is group tabs)
bind(m .. " + CTRL + left",  hl.dsp.window.move({ direction = "l" }), { description = "Windows: Move window left" })
bind(m .. " + CTRL + right", hl.dsp.window.move({ direction = "r" }), { description = "Windows: Move window right" })
bind(m .. " + CTRL + up",    hl.dsp.window.move({ direction = "u" }), { description = "Windows: Move window up" })
bind(m .. " + CTRL + down",  hl.dsp.window.move({ direction = "d" }), { description = "Windows: Move window down" })

-- ▓▒░ MULTI-MONITOR (matters once a laptop is docked)
-- (on brackets, not arrows — SUPER+ALT+arrows is directional window focus)
bind(m .. " + ALT + bracketleft",  hl.dsp.focus({ monitor = "-1" }), { description = "Workspaces: Focus previous monitor" })
bind(m .. " + ALT + bracketright", hl.dsp.focus({ monitor = "+1" }), { description = "Workspaces: Focus next monitor" })
bind(m .. " + ALT + SHIFT + bracketleft",  hl.dsp.window.move({ monitor = "-1" }), { description = "Workspaces: Move window to previous monitor" })
bind(m .. " + ALT + SHIFT + bracketright", hl.dsp.window.move({ monitor = "+1" }), { description = "Workspaces: Move window to next monitor" })

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

-- ▓▒░ LOCK SCREEN POWER BUTTONS (keyboard)
-- ←/→ select sleep / reboot / shutdown on hyprlock, Enter fires the selection,
-- Esc or any other key drops it. Plain arrows and Enter can't be global binds
-- (they'd be eaten everywhere), so they live in two submaps that only exist
-- while hyprlock runs. scripts/lock_buttons.py's watcher enters "lockscreen"
-- when the lock starts, switches to "lockscreen-armed" while something is
-- selected — only then is Enter taken from the password field — and resets on
-- unlock. Locked binds above are universal (see bind()), so SUPER+K and the
-- media keys keep working in here.
local LOCK_BUTTONS = "~/.config/hypr/scripts/lock_buttons.py"

-- Global: the watcher calls lockbuttons.enter() over `hyprctl eval`.
lockbuttons = {}

function lockbuttons.enter(pid, submap)
    lockbuttons.pid = pid
    hl.dispatch(hl.dsp.submap(submap))
end

local function is_hyprlock(pid)
    local f = pid and io.open("/proc/" .. pid .. "/comm")
    local comm = f and f:read("l")
    if f then f:close() end
    return comm == "hyprlock"
end

-- True while a hyprlock owns these submaps. If its watcher died without
-- resetting the submap, the next key resets it here rather than leaving every
-- normal bind dead. Reads /proc in-process: no fork per key. A config reload
-- while locked wipes this Lua state but keeps the submap, so a lost pid is
-- looked up again once instead of being taken for a dead lock.
local function lock_alive()
    if not is_hyprlock(lockbuttons.pid) then
        local p = io.popen("pidof -s hyprlock")
        lockbuttons.pid = p and tonumber(p:read("l") or "")
        if p then p:close() end
    end
    if is_hyprlock(lockbuttons.pid) then return true end
    lockbuttons.enter(nil, "reset")
    return false
end

local function lock_key(cmd)
    return function()
        if lock_alive() then
            hl.exec_cmd(LOCK_BUTTONS .. " key " .. lockbuttons.pid .. " " .. cmd)
        end
    end
end

-- The catch-all fires for every key, bound ones included (seen on 0.56.2), so
-- it skips the keys these submaps handle themselves — otherwise → would select
-- and clear in the same press.
local LOCK_KEYS = { "Left", "Right", "Return", "KP_Enter", "Escape" }   -- keysym case: is_key_down("right") is nil

local function lock_typed()
    for _, k in ipairs(LOCK_KEYS) do
        if hl.is_key_down(k) then return end
    end
    lock_key("clear")()
end

local function lock_nav_binds()
    hl.bind("left",  lock_key("prev"), { locked = true, description = "System: Lock screen button left" })
    hl.bind("right", lock_key("next"), { locked = true, description = "System: Lock screen button right" })
end

hl.define_submap("lockscreen", function()
    lock_nav_binds()
    -- non_consuming: every other key still reaches the password field.
    hl.bind("catchall", lock_alive, { locked = true, non_consuming = true })
end)

hl.define_submap("lockscreen-armed", function()
    lock_nav_binds()
    hl.bind("Return",   lock_key("activate"), { locked = true, description = "System: Lock screen press selected button" })
    hl.bind("KP_Enter", lock_key("activate"), { locked = true, description = "System: Lock screen press selected button" })
    hl.bind("escape",   lock_key("clear"),    { locked = true, description = "System: Lock screen drop button selection" })
    -- Typing drops the selection, so Enter goes back to submitting the password.
    hl.bind("catchall", lock_typed, { locked = true, non_consuming = true })
end)
