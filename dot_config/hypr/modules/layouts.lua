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
        -- Kept through the gaming cleanup: mode 3 also fires for content type
        -- "video", which mpv reports during fullscreen playback — not only games.
        vrr = 3,

        force_default_wallpaper      = 0,    -- 0 = disable Hyprland anime wallpaper; awww manages wallpaper
        disable_hyprland_logo        = true,
        disable_splash_rendering     = true,
        background_color             = "0x111111",   -- matches the Onyx base instead of default blue-grey
        font_family                  = "CaskaydiaCove Nerd Font",   -- compositor-drawn text (group tab titles, notifications) matches the bar and hyprlock
        -- Swallowing off: a terminal stays visible while the GUI app it launched is open.
        -- Set to true to hide ghostty/kitty behind apps they launch again.
        enable_swallow               = false,
        swallow_regex               = "^(com.mitchellh.ghostty|ghostty|kitty)$",
        focus_on_activate            = true,
        animate_manual_resizes       = true,
        animate_mouse_windowdragging = true,
        close_special_on_empty       = true,
        session_lock_xray            = true,
        session_lock_blur            = true,
        -- If hyprlock crashes, the session stays locked behind Hyprland's red
        -- "lockscreen app died" screen and no replacement locker is accepted.
        -- With this on, one is: from a TTY run
        --   hyprctl --instance 0 dispatch 'hl.dsp.exec_cmd("hyprlock")'
        -- and unlock normally, instead of having to kill the whole session.
        allow_session_lock_restore   = true,
        key_press_enables_dpms       = true,   -- makes hypridle's after_sleep_cmd wake reliable
        mouse_move_enables_dpms      = true,
    },

    -- ▓▒░ BINDS CONFIGURATION
    binds = {
        scroll_event_delay                = 100,
        workspace_back_and_forth          = true,  -- Re-press workspace key to toggle back
        drag_threshold                    = 10,    -- default 0 grabs windows on mousedown; avoids stray drags
        hide_special_on_workspace_change  = true,  -- two scratchpads bound (SUPER+S / SUPER+N)
        -- Inside a group (SUPER+CTRL+G), SUPER+left/right step through its tabs
        -- first and only leave the group at either end. Without it, hidden tabs
        -- could only be reached with the mouse (click or scroll the groupbar).
        movefocus_cycles_groupfirst       = true,
    },

    -- NOTE: no `input` block here. repeat_rate, repeat_delay and
    --       follow_mouse_threshold used to be duplicated in this file, which is
    --       exactly the split input.lua's header warns about — grepping one file
    --       found nothing and the key looked unset. Every `input` key lives in
    --       modules/input.lua now. Don't re-add one here.

    -- ▓▒░ ECOSYSTEM
    ecosystem = {
        no_update_news  = true,   -- rolling release (CachyOS); update nags add no value
        no_donation_nag = true,
    },
})
