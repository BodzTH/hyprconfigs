-- █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
-- ██▄ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
--
-- MODULE 2: ENVIRONMENT VARIABLES
-- Core system and protocol environment setup
-- See: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
-- ═══════════════════════════════════════════════════════════════

-- NOTE: All hl.env() calls below have been commented out because they are now
-- managed by UWSM (Universal Wayland Session Manager) to ensure early and 
-- reliable propagation to systemd and D-Bus.
-- The active environment variables are now located in:
-- ~/.config/uwsm/env and ~/.config/uwsm/env-hyprland

-- ▓▒░ CURSOR CONFIGURATION
-- hl.env("XCURSOR_SIZE", "24")
-- hl.env("HYPRCURSOR_SIZE", "24")
-- hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
-- hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-dark-cursors")

-- ▓▒░ XDG SPECIFICATION COMPLIANCE
-- Required for proper Wayland desktop integration
-- hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
-- hl.env("XDG_SESSION_TYPE", "wayland")
-- hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- ▓▒░ GTK APPLICATION SETTINGS
-- Enables GTK applications to work properly on Wayland
-- hl.env("GDK_BACKEND", "wayland,x11,*")
-- hl.env("GDK_SCALE", "1")

-- ▓▒░ QT APPLICATION SETTINGS
-- Enables Qt5 & Qt6 applications to work properly on Wayland and load theme utilities
-- hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
-- hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
-- hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- ▓▒░ ANIMATION & MULTIMEDIA LIBRARIES
-- hl.env("CLUTTER_BACKEND", "wayland")
-- hl.env("SDL_VIDEODRIVER", "wayland,x11")

-- ▓▒░ ELECTRON APPLICATIONS
-- Hints Electron apps (VSCode, Discord, etc.) to use the native Wayland backend
-- hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- ▓▒░ AMD GPU - VULKAN & GRAPHICS
-- hl.env("AMD_VULKAN_ICD", "RADV")
-- hl.env("LIBVA_DRIVER_NAME", "radeonsi")
-- Force DXVK to only use the dedicated GPU (Fixes dual-GPU crashes in games like Rocket League)
-- hl.env("DXVK_FILTER_DEVICE_NAME", "AMD Radeon RX 7700 XT")

-- ▓▒░ AMD GPU — GAMING PERFORMANCE
-- Mesa GL threading for OpenGL games (RadeonSI)
-- hl.env("mesa_glthread", "true")
-- Skip XWayland VSync wait — reduces input latency for X11/XWayland games
-- hl.env("vk_xwayland_wait_ready", "false")

-- ▓▒░ MOZILLA & JAVA WAYLAND INTEGRATION
-- hl.env("MOZ_ENABLE_WAYLAND", "1")

-- ▓▒░ HYPRLAND MULTI-GPU EXPLICIT PATHS
-- Use direct device paths to prevent Aquamarine backend crash
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/card1:/dev/dri/card0")
