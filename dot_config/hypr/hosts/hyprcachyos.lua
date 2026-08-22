-- Host Profile: hyprcachyos (Main Desktop)
-- Hardware: AMD Ryzen 5 7600X3D · RX 7700 XT + Raphael iGPU · Acer VG240Y S 1080p@165Hz
return {
    monitors = {
        {
            output   = "",
            mode     = "1920x1080@165.00Hz",
            position = "0x0",
            scale    = 1,
        },
    },
    apps = {
        antigravity = "/home/" .. (os.getenv("USER") or "bodz") .. "/Apps/Antigravity/Antigravity.AppImage --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations",
    },
    devices = {
        {
            name          = "logitech-g305-1",
            sensitivity   = 0,
            accel_profile = "flat",
        },
    },
}
