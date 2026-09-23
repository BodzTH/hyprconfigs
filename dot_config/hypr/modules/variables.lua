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

-- ▓▒░ PERSONAL APPS (not packaged — only on machines that have them)
-- nil where the file is missing, so keybindings.lua skips the bind (and the
-- cheatsheet row) instead of binding a key that silently does nothing.
local function if_present(path, args)
    local f = io.open(path, "r")
    if not f then return nil end
    f:close()
    return args and (path .. " " .. args) or path
end
vars.antigravity     = if_present(home .. "/Apps/Antigravity/Antigravity.AppImage", "--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations")
vars.thePlan         = if_present(home .. "/The-Plan/the-plan")
-- NOTE: vars.bar removed — quickshell is a systemd unit now (../systemd/quickshell.service),
--       not an exec_cmd. Its `env QT_QPA_PLATFORMTHEME=qt6ct` prefix was also already
--       redundant: modules/environment.lua exports that var session-wide.

-- ▓▒░ HOST-SPECIFIC APPLICATION OVERRIDES
if host and host.apps then
    for key, val in pairs(host.apps) do
        vars[key] = val
    end
end

return vars
