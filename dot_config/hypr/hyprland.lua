-- ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗      █████╗ ███╗   ██╗██████╗
-- ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║     ██╔══██╗████╗  ██║██╔══██╗
-- ███████║ ╚████╔╝ ██████╔╝██████╔╝██║     ███████║██╔██╗ ██║██║  ██║
-- ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗██║     ██╔══██║██║╚██╗██║██║  ██║
-- ██║  ██║   ██║   ██║     ██║  ██║███████╗██║  ██║██║ ╚████║██████╔╝
-- ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═════╝
--
-- Hyprland Lua Configuration — Modular Entry Point
-- https://wiki.hypr.land/Configuring/Start/
--
-- Stack: kitty · yazi · quickshell · awww · neovim (NvChad)
-- Theme: Onyx & Platinum (monochrome) + catppuccin-mocha-dark-cursors
-- ═══════════════════════════════════════════════════════════════

-- ▓▒░ MODULE LOAD ORDER
-- Dependencies must be required before the modules that use them.

require("modules.environment")   -- Env vars (cursor, Qt, GTK, AMD GPU, Wayland)
require("modules.monitors")      -- Display config: 1920x1080@165Hz
require("modules.appearance")    -- Borders, blur, shadows, transparency
require("modules.animations")    -- Bezier curves & animation tree
require("modules.input")         -- Keyboard (us+ara), mouse, gestures
require("modules.layouts")       -- Dwindle, Master, misc, binds
require("modules.autostart")     -- quickshell, awww, hypridle, clipboard
require("modules.keybindings")   -- All SUPER+* keybinds
require("modules.windowrules")   -- Window & layer rules
