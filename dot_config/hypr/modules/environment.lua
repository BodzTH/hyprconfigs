-- █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
-- ██▄ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
--
-- MODULE 2: ENVIRONMENT VARIABLES
-- See: https://wiki.hypr.land/Configuring/Core/Environment-Variables/
--
-- hl.env() sets these before the display server initializes, which is why
-- AQ_DRM_DEVICES below is effective here.
--
-- These lived in ~/.config/uwsm/env while the session was uwsm-managed. That
-- split the config across two trees -- uwsm's env files are static shell and
-- can't read hosts/ -- and AQ_DRM_DEVICES was silently lost in the gap. Env is
-- back in-tree so it stays host-aware and version-controlled.
-- ═══════════════════════════════════════════════════════════════

local host = require("hosts")

-- ▓▒░ GPU SELECTION (AQ_DRM_DEVICES)
-- /dev/dri/cardN numbering is assigned at boot and can change between boots;
-- PCI addresses do not. Multi-GPU explicitly warns against pinning cardN, and
-- the stable by-path names can't be used directly because they contain ':',
-- which AQ_DRM_DEVICES uses as its own separator. So host profiles carry PCI
-- addresses in priority order and we resolve them to whatever cardN they are
-- on this boot. First entry is the primary renderer.
local function resolve_gpus(pci_addresses)
    local cards = {}
    for _, addr in ipairs(pci_addresses or {}) do
        -- -e, not -f: -f prints a canonicalized path even when nothing is there,
        -- which would export a nonexistent device and break GPU selection outright.
        -- -e fails cleanly when the card isn't present on this machine.
        local f = io.popen("readlink -e /dev/dri/by-path/pci-" .. addr .. "-card 2>/dev/null")
        local card = f and f:read("*l")
        if f then f:close() end
        if card and card ~= "" then
            cards[#cards + 1] = card
        end
    end
    return cards
end

-- No list, or none of the listed cards present -> export nothing and let
-- Aquamarine auto-detect. That is the correct behaviour on an unknown host.
local gpus = resolve_gpus(host.gpu)
if #gpus > 0 then
    hl.env("AQ_DRM_DEVICES", table.concat(gpus, ":"))
end

-- ▓▒░ CURSOR
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-dark-cursors")

-- ▓▒░ GTK
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("GDK_SCALE", "1")

-- ▓▒░ QT
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")

-- ▓▒░ TOOLKITS & MULTIMEDIA
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland,x11")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("MOZ_ENABLE_WAYLAND", "1")

-- ▓▒░ SSH AGENT
-- gnome-keyring dropped its ssh component; gcr-ssh-agent.socket replaces it.
-- scripts/bootstrap.sh enables that socket. Without this export SSH_AUTH_SOCK
-- is unset and no agent is reachable.
local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
if runtime_dir then
    hl.env("SSH_AUTH_SOCK", runtime_dir .. "/gcr/ssh")
end

-- ▓▒░ AMD GPU — VULKAN & GRAPHICS
hl.env("AMD_VULKAN_ICD", "RADV")
hl.env("LIBVA_DRIVER_NAME", "radeonsi")

-- ▓▒░ AMD GPU — GAMING PERFORMANCE
hl.env("mesa_glthread", "true")           -- Mesa GL threading for OpenGL games (RadeonSI)
hl.env("vk_xwayland_wait_ready", "false") -- skip XWayland VSync wait, cuts input latency

-- ▓▒░ HOST-SPECIFIC OVERRIDES
-- Anything tied to one machine's hardware (e.g. DXVK_FILTER_DEVICE_NAME naming
-- a specific GPU) belongs in the host profile, not here.
for key, val in pairs((host and host.env) or {}) do
    hl.env(key, val)
end

-- NOTE: XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE / XDG_SESSION_DESKTOP are set by
--       the session itself (hyprland.desktop carries DesktopNames=Hyprland) and
--       must not be set here.
