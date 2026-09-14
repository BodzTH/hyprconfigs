-- ▄▀█ █░█ ▀█▀ █▀█ █▀ ▀█▀ ▄▀█ █▀█ ▀█▀
-- █▀█ █▄█ ░█░ █▄█ ▄█ ░█░ █▀█ █▀▄ ░█░
--
-- MODULE 4: AUTOSTART
-- Applications and services to launch on Hyprland startup
-- See: https://wiki.hypr.land/Configuring/Basics/Autostart/
-- ═══════════════════════════════════════════════════════════════

local vars = require("modules.variables")

hl.on("hyprland.start", function()
    -- ▓▒░ STATUS BAR
    -- Quickshell replaces waybar as the status bar
    hl.exec_cmd(vars.bar)

    -- ▓▒░ WALLPAPER DAEMON
    -- awww replaces hyprpaper as the wallpaper daemon
    hl.exec_cmd("awww-daemon & sleep 0.5 && awww restore")

    -- ▓▒░ DYNAMIC BORDER SYNCHRONIZER
    -- Watches wallpaper changes and synchronizes glowing active border
    hl.exec_cmd("python3 ~/.config/hypr/scripts/sync_border.py --watch")

    -- ▓▒░ IDLE MANAGEMENT
    hl.exec_cmd("systemctl --user start hypridle.service")

    -- ▓▒░ D-BUS ENVIRONMENT SYNC
    -- Required for portals and XDG apps to work properly on Wayland
    -- NOTE: Commented out because UWSM handles this automatically in 2026.
    -- hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- ▓▒░ AUTHENTICATION & KEYRING
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    -- NOTE: the hyprpolkitagent binary is not on $PATH; it must be started via its systemd unit.
    hl.exec_cmd("systemctl --user start hyprpolkitagent")

    -- ▓▒░ CLIPBOARD MANAGEMENT
    -- cliphist stores clipboard history for both text and images
    -- SUPER+V in keybindings pops this via the quickshell ClipboardPanel
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")

    -- NOTE: nm-applet is NOT started — network status is managed
    --       by the quickshell NetworkWidget in the bar.
    -- NOTE: dunst is NOT started — notifications are handled by
    --       quickshell's built-in NotificationServer & NotificationOSD.
    -- NOTE: hyprpaper is NOT started — awww handles wallpaper.
    -- NOTE: waybar is NOT started — quickshell is the bar.
end)
