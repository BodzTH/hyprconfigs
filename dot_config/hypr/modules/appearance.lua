-- ▄▀█ █▀█ █▀█ █▀▀ ▄▀█ █▀█ ▄▀█ █▄░█ █▀▀ █▀▀
-- █▀█ █▀▀ █▀▀ ██▄ █▀█ █▀▄ █▀█ █░▀█ █▄▄ ██▄
--
-- MODULE 5: APPEARANCE & VISUAL SETTINGS
-- Colors, borders, transparency, blur, and UI styling
-- See: https://wiki.hypr.land/Configuring/Basics/Variables/
-- ═══════════════════════════════════════════════════════════════

hl.config({
    -- ▓▒░ GENERAL APPEARANCE
    general = {
        gaps_in     = 5,
        gaps_out    = 20,
        border_size = 2,
        col = {
            -- Glowing semi-transparent gradient fading to complete transparency
            active_border   = { colors = {"rgba(e5e5e5ee)", "rgba(e5e5e500)"}, angle = 45 },
            inactive_border = "rgba(222222ff)",
        },
        resize_on_border = true,
        layout           = "dwindle",
    },

    -- ▓▒░ DECORATION & VISUAL EFFECTS
    decoration = {
        rounding       = 25,
        rounding_power = 2,

        -- Transparency: active windows are slightly translucent for depth
        active_opacity   = 0.80,
        inactive_opacity = 0.70,

        -- ▓▒░ SHADOW EFFECTS
        shadow = {
            enabled        = true,
            range          = 8,
            render_power   = 3,
            color          = "rgba(0,0,0,0.66)",
            color_inactive = "rgba(0,0,0,0)",
        },

        -- ▓▒░ BLUR EFFECT
        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            noise             = 0.015,
            contrast          = 0.9,
            brightness        = 0.8,
            vibrancy          = 1.0,
            new_optimizations = true,
            ignore_opacity    = true,   -- already the default; kept explicit for clarity
            xray              = true,
            special           = true,
            popups            = true,
            popups_ignorealpha = 0.2,
        },

        -- ▓▒░ DIM INACTIVE WINDOWS
        dim_special  = 0.3,
        dim_inactive = true,
        dim_strength = 0.1,
    },

    -- ▓▒░ RENDERING & OPTIMIZATION
    render = {
        direct_scanout        = 2,
        new_render_scheduling = true,
    },

    -- ▓▒░ XWAYLAND SCALING FIX
    -- No-op at scale = 1 on this 1080p monitor; kept as insurance for a future HiDPI display
    xwayland = {
        force_zero_scaling = true,
    },
})
