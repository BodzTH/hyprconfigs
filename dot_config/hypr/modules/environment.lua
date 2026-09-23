-- █▀▀ █▄░█ █░█ █ █▀█ █▀█ █▄░█ █▀▄▀█ █▀▀ █▄░█ ▀█▀
-- ██▄ █░▀█ ▀▄▀ █ █▀▄ █▄█ █░▀█ █░▀░█ ██▄ █░▀█ ░█░
--
-- MODULE 2: ENVIRONMENT VARIABLES
-- See: https://wiki.hypr.land/Configuring/Core/Environment-Variables/
--
-- hl.env() sets these before the display server initializes, which is why
-- AQ_DRM_DEVICES below is effective here.
--
-- Keep these in-tree, not in a static shell env file: a static file can't read
-- hosts/, which previously let AQ_DRM_DEVICES silently drop out unnoticed (see
-- context.md). Lua keeps it host-aware and version-controlled.
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

-- ▓▒░ MESA — GAMING PERFORMANCE
-- NOTE: commented out — this machine isn't used for gaming, so Mesa keeps its
--       own defaults. Both are Mesa driconf options (radeonsi/radv here,
--       iris/anv on Intel) and host-neutral, so uncommenting is all a return
--       to gaming needs.
-- hl.env("mesa_glthread", "true")           -- Mesa GL threading for OpenGL games
-- hl.env("vk_xwayland_wait_ready", "false") -- skip XWayland VSync wait, cuts input latency

-- NOTE: AMD_VULKAN_ICD and LIBVA_DRIVER_NAME live in hosts/hyprcachyos.lua now.
--       They name a GPU vendor, and LIBVA_DRIVER_NAME=radeonsi on a non-AMD
--       host (an Intel laptop needs iHD) breaks VA-API hardware video decoding.

-- ▓▒░ HOST-SPECIFIC OVERRIDES
-- Anything tied to one machine's hardware (e.g. AMD_VULKAN_ICD naming a GPU
-- vendor) belongs in the host profile, not here.
for key, val in pairs((host and host.env) or {}) do
    hl.env(key, val)
end

-- NOTE: XDG_CURRENT_DESKTOP / XDG_SESSION_TYPE / XDG_SESSION_DESKTOP are set by
--       the session itself (hyprland.desktop carries DesktopNames=Hyprland) and
--       must not be set here.
