-- █░█ ▄▀█ █▀█ █ ▄▀█ █▄▄ █░░ █▀▀ █▀
-- ▀▄▀ █▀█ █▀▄ █ █▀█ █▄█ █▄▄ ██▄ ▄█
--
-- MODULE 1: VARIABLES & APPLICATION ALIASES
-- Define default applications and command shortcuts
-- ═══════════════════════════════════════════════════════════════

local host = require("hosts")

local vars = {}

vars.mainMod = "SUPER"                    -- Windows key as primary modifier

-- ▓▒░ DEFAULT APPLICATION VARIABLES
local home = os.getenv("HOME") or ("/home/" .. (os.getenv("USER") or "user"))
vars.terminal        = "kitty"
vars.fileManager     = "kitty --class=org.yazi.fm -e fish -c 'y'"   -- yazi via kitty
vars.browser         = "firefox"
vars.terminal_editor = "kitty -e nvim"   -- NvChad inside kitty
vars.notingApp       = "obsidian"
vars.discord         = "discord"
vars.updater         = "kitty --class=cachy.update -e sh -c 'sudo pacman -Syu; echo \"\nPress Enter to close...\"; read'"
vars.antigravity     = home .. "/Apps/Antigravity/Antigravity.AppImage --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations"
vars.bar             = "env QT_QPA_PLATFORMTHEME=qt6ct quickshell"

-- ▓▒░ HOST-SPECIFIC APPLICATION OVERRIDES
if host and host.apps then
    for key, val in pairs(host.apps) do
        vars[key] = val
    end
end

return vars
