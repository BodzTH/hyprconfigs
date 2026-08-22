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
    apps = {},
    devices = {},
}
