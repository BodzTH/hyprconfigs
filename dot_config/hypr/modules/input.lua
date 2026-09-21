-- █ █▄░█ █▀█ █░█ ▀█▀
-- █ █░▀█ █▀▀ █▄█ ░█░
--
-- INPUT — keyboard, pointer, touchpad, gestures, per-device overrides.
--
-- NOTE: these settings used to be split across input.lua and layouts.lua, so
--       grepping one file for `repeat_rate` found nothing and the key looked
--       unset. Every `input` key now lives in this one block. Keep it that way.
-- See: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
-- ═══════════════════════════════════════════════════════════════

local host = require("hosts")

hl.config({
    input = {
        kb_layout    = "us,ara",   -- Arabic + US layout; SUPER+K switches between them
        follow_mouse = 1,
        sensitivity  = 0,          -- -1.0 to 1.0, 0 = no modification

        repeat_rate            = 40,   -- default 25 — noticeably sluggish key-repeat in nvim/yazi
        repeat_delay           = 300,  -- default 600
        follow_mouse_threshold = 3,    -- avoids focus jitter when the cursor crosses the 20px gaps

        -- Ignored entirely on machines with no touchpad (e.g. the desktop) —
        -- safe to keep here so the same config covers a laptop too.
        touchpad = {
            natural_scroll       = true,
            tap_to_click         = true,
            disable_while_typing = true,
            clickfinger_behavior = true,  -- 1/2/3 fingers = LMB/RMB/MMB, ignores click location
            drag_lock            = 1,
            scroll_factor        = 0.8,
        },
    },
    cursor = {
        warp_on_change_workspace = 0,     -- Don't teleport cursor on workspace switch
        -- no_break_fs_vrr          = 2,     -- Auto-prevent cursor movement from breaking VRR
        no_hardware_cursors      = 0,     -- Always use hardware cursors (cheaper than software)
        -- min_refresh_rate         = 48,    -- FreeSync floor Hz (prevents drops below this)
        -- NOTE: the two commented lines are gaming-only — both act on fullscreen
        --       windows with content type "game" — and this machine isn't used
        --       for gaming. no_break_fs_vrr's default is already 2, so nothing
        --       changes by commenting them out.
    },
})

-- ▓▒░ GESTURES
-- See: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ▓▒░ PER-DEVICE OVERRIDES (from hosts/<hostname>.lua)
for _, dev in ipairs(host.devices or {}) do
    hl.device(dev)
end
