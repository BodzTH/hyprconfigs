-- Default Host Profile
-- Fallback settings when running on an unconfigured hostname
return {
    monitors = {
        {
            output   = "",
            mode     = "preferred",
            position = "auto",
            scale    = 1,
        },
    },
    -- Empty: let Aquamarine auto-detect GPUs. Correct default on unknown hardware.
    gpu     = {},
    env     = {},
    -- Top-level `input` keys that differ on this machine, e.g.
    --   input = { kb_layout = "us,de", kb_variant = ",nodeadkeys" },
    input   = {},
    apps    = {},
    devices = {},
}
