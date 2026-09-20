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

    -- GPUs by PCI address, primary renderer first. Resolved to the current
    -- /dev/dri/cardN at startup by modules/environment.lua -- never pin cardN
    -- here, it is reassigned at boot.
    --   lspci -d ::03xx           lists the addresses
    --   ls -l /dev/dri/by-path    shows what they map to right now
    gpu = {
        "0000:03:00.0",   -- Radeon RX 7700 XT (dedicated) — primary
        "0000:0e:00.0",   -- Raphael iGPU — fallback, keeps its outputs usable
    },

    -- Host-specific environment. Anything naming this machine's hardware lives
    -- here rather than in modules/environment.lua.
    env = {
        -- Force DXVK onto the dGPU only (fixes dual-GPU crashes in e.g. Rocket League)
        DXVK_FILTER_DEVICE_NAME = "AMD Radeon RX 7700 XT",
    },

    -- NOTE: no app overrides needed — modules/variables.lua's defaults (including
    -- antigravity) already match this host.
    apps = {},
    devices = {
        {
            name          = "logitech-g305-1",
            sensitivity   = 0,
            accel_profile = "flat",
        },
    },
}
