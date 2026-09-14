-- Host Profile: hyprcachyos (Main Desktop)
-- Hardware: AMD Ryzen 5 7600X3D · RX 7700 XT + Raphael iGPU · Acer VG240Y S 1080p@165Hz
return {
    monitors = {
        {
            output   = "",
            mode     = "1920x1080@165.00",
            position = "0x0",
            scale    = 1,
        },
    },
    -- NOTE: no app overrides needed — modules/variables.lua's defaults (including antigravity)
    -- already match this host.
    apps = {},
    devices = {
        {
            name          = "logitech-g305-1",
            sensitivity   = 0,
            accel_profile = "flat",
        },
    },
}
