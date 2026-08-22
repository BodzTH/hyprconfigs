-- █░░ ▄▀█ █▄█ █▀█ █░█ ▀█▀ █▀
-- █▄▄ █▀█ ░█░ █▄█ █▄█ ░█░ ▄█
--
-- MODULE 8: LAYOUTS & WINDOW BEHAVIOR
-- Master layout, Dwindle layout, and window management settings
-- See: https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/
-- See: https://wiki.hypr.land/Configuring/Layouts/Master-Layout/
-- ═══════════════════════════════════════════════════════════════

hl.config({
    -- ▓▒░ DWINDLE LAYOUT
    dwindle = {
        preserve_split = true,
    },

    -- ▓▒░ MASTER LAYOUT
    master = {
        new_status        = "slave",     -- New windows are added to the slave stack
        new_on_top        = true,
        smart_resizing    = true,
        allow_small_split = true,
        mfact             = 0.5,         -- Master area takes 50% of screen width
        orientation       = "left",
    },

    -- ▓▒░ MISCELLANEOUS WINDOW BEHAVIOR
    misc = {
        -- vrr: 0 = off, 1 = always on, 2 = fullscreen only, 3 = fullscreen + content type
        vrr = 3,

        force_default_wallpaper      = 0,    -- 0 = disable Hyprland anime wallpaper; awww manages wallpaper
        disable_hyprland_logo        = true,
        enable_swallow               = true,
        -- Terminal windows get "swallowed" (hidden) when they launch a GUI app
        swallow_regex                = "^(com.mitchellh.ghostty|ghostty|kitty|Alacritty|alacritty|foot)$",
        focus_on_activate            = true,
        animate_manual_resizes       = true,
        animate_mouse_windowdragging = true,
        close_special_on_empty       = true,
        session_lock_xray            = true,
        session_lock_blur            = true,
    },

    -- ▓▒░ BINDS CONFIGURATION
    binds = {
        scroll_event_delay       = 100,
        workspace_back_and_forth = true,  -- Re-press workspace key to toggle back
    },
})
