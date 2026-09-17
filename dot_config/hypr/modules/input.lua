-- █ █▄░█ █▀█ █░█ ▀█▀
-- █ █░▀█ █▀▀ █▄█ ░█░
--
-- MODULE 7: INPUT DEVICES
-- Keyboard, mouse, trackpad, and input device configuration
-- See: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Devices/
-- ═══════════════════════════════════════════════════════════════

local host = require("hosts")

-- ▓▒░ GLOBAL INPUT SETTINGS
hl.config({
    input = {
        kb_layout    = "us,ara",   -- Arabic + US layout; SUPER+K switches between them
        follow_mouse = 1,
        sensitivity  = 0,          -- -1.0 to 1.0, 0 = no modification

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
        no_break_fs_vrr          = 2,     -- Auto-prevent cursor movement from breaking VRR
        no_hardware_cursors      = 0,     -- Always use hardware cursors (cheaper than software)
        min_refresh_rate         = 48,    -- FreeSync floor Hz (prevents drops below this)
    },
})

-- ▓▒░ GESTURES CONFIGURATION
-- See: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- ▓▒░ PER-DEVICE INPUT CONFIGURATION
if host and host.devices then
    for _, dev in ipairs(host.devices) do
        hl.device(dev)
    end
end
