-- Host Profile: laptop
-- Rename this file to the laptop's `hostname` (see hosts/init.lua) for it to load
-- automatically. Adjust the eDP-1 mode/scale to match the real panel —
-- `hyprctl monitors all` will list it once the file is active.
return {
    monitors = {
        -- Internal panel. Bump scale to 1.5/2 if it's HiDPI.
        { output = "eDP-1", mode = "preferred", position = "auto", scale = 1 },
        -- Catch-all: any docked/external display, auto-placed to the right.
        { output = "",      mode = "preferred", position = "auto", scale = 1 },
    },

    -- GPUs by PCI address, primary renderer first. Leave empty to let Aquamarine
    -- auto-detect; fill it in only if the wrong GPU is picked or an output on a
    -- second card stays dark.
    --   lspci -d ::03xx    lists this machine's addresses
    -- Multi-GPU recommends the *integrated* GPU as primary on laptops: it
    -- preserves battery and is indistinguishable in practice for compositing.
    gpu = {
        -- "0000:06:00.0",   -- iGPU — primary
        -- "0000:01:00.0",   -- dGPU — fallback
    },

    -- GPU-vendor env goes here, never in modules/environment.lua. libva usually
    -- picks the right VA-API driver itself; set it only if hardware video
    -- decoding fails (`vainfo` shows which driver loaded).
    env     = {
        -- LIBVA_DRIVER_NAME = "iHD",        -- Intel
        -- LIBVA_DRIVER_NAME = "radeonsi",   -- AMD
        -- LIBVA_DRIVER_NAME = "nvidia",             -- NVIDIA
        -- GBM_BACKEND = "nvidia-drm",               -- NVIDIA
        -- __GLX_VENDOR_LIBRARY_NAME = "nvidia",     -- NVIDIA
        -- NVD_BACKEND = "direct",                   -- NVIDIA
    },
    apps    = {},
    devices = {},
}
