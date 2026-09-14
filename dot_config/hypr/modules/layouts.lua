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
    -- (the master layout block was removed — general.layout = "dwindle" and nothing switches layouts,
    --  so those settings were dead config)
    dwindle = {
        preserve_split      = true,   -- see keybindings.lua's SUPER+J togglesplit bind
        precise_mouse_move  = true,
    },

    -- ▓▒░ MISCELLANEOUS WINDOW BEHAVIOR
    misc = {
        -- vrr: 0 = off, 1 = always on, 2 = fullscreen only, 3 = fullscreen + content type
        vrr = 3,

        force_default_wallpaper      = 0,    -- 0 = disable Hyprland anime wallpaper; awww manages wallpaper
        disable_hyprland_logo        = true,
        disable_splash_rendering     = true,
        background_color             = "0x111111",   -- matches the Onyx base instead of default blue-grey
        enable_swallow               = true,
        -- Terminal windows get "swallowed" (hidden) when they launch a GUI app
        swallow_regex                = "^(com.mitchellh.ghostty|ghostty|kitty)$",
        focus_on_activate            = true,
        animate_manual_resizes       = true,
        animate_mouse_windowdragging = true,
        close_special_on_empty       = true,
        session_lock_xray            = true,
        session_lock_blur            = true,
        key_press_enables_dpms       = true,   -- makes hypridle's after_sleep_cmd wake reliable
        mouse_move_enables_dpms      = true,
    },

    -- ▓▒░ BINDS CONFIGURATION
    binds = {
        scroll_event_delay                = 100,
        workspace_back_and_forth          = true,  -- Re-press workspace key to toggle back
        drag_threshold                    = 10,    -- default 0 grabs windows on mousedown; avoids stray drags
        hide_special_on_workspace_change  = true,  -- two scratchpads bound (SUPER+S / SUPER+N)
    },

    -- ▓▒░ INPUT RESPONSIVENESS
    input = {
        repeat_rate            = 40,   -- default 25 — noticeably sluggish key-repeat in nvim/yazi
        repeat_delay           = 300,  -- default 600
        follow_mouse_threshold = 3,    -- avoids focus jitter when the cursor crosses the 20px gaps
    },

    -- ▓▒░ ECOSYSTEM
    ecosystem = {
        no_update_news  = true,   -- rolling release (CachyOS); update nags add no value
        no_donation_nag = true,
    },
})
