-- █░█░█ █ █▄░█ █▀▄ █▀█ █░█░█ █▀█ █░█ █░░ █▀▀ █▀
-- ▀▄▀▄▀ █ █░▀█ █▄▀ █▄█ ▀▄▀▄▀ █▀▄ █▄█ █▄▄ ██▄ ▄█
--
-- MODULE 10: WINDOW RULES & PERMISSIONS
-- Application-specific window behavior and layer rules
-- See: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- ═══════════════════════════════════════════════════════════════

-- ▓▒░ GENERAL WINDOW BEHAVIOR
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- ▓▒░ LAYER RULES — UI Elements, Notifications, Panels
-- Blur all quickshell bar, launcher, screenshot, clipboard, and OSD layers
hl.layer_rule({
    name  = "blur-quickshell-bar",
    match = { namespace = "quickshell" },
    blur  = true,
    blur_popups = true,
    ignore_alpha = 0.01,
})

hl.layer_rule({
    name  = "blur-quickshell-panels",
    match = { namespace = "^(quickshell-launcher|quickshell-clipboard|quickshell-screenshot|notification-osd|quickshell-wallpaper-selector|quickshell-shortcuts|quickshell-notifications|quickshell-osd|quickshell-overview|quickshell-network)$" },
    blur  = true,
    blur_popups = true,
    ignore_alpha = 0.2,
})

-- Clipboard history holds whatever was copied — passwords, tokens, keys. Keep
-- the panel out of screen shares and recordings; it is drawn there as a black
-- box instead.
hl.layer_rule({
    name            = "clipboard-no-screenshare",
    match           = { namespace = "^quickshell-clipboard$" },
    no_screen_share = true,
})

-- Blur hyprtoolkit & hyprshutdown layers & dialogs
hl.layer_rule({
    name         = "blur-hyprtoolkit",
    match        = { namespace = "^(hyprtoolkit.*|hyprshutdown.*|hyprpolkitagent.*|hyprland-.*)$" },
    blur         = true,
    blur_popups  = true,
    ignore_alpha = 0.01,
    dim_around   = true,
})

-- NOTE: wofi and dunst blur rules removed — neither tool is used any more.
-- wofi → replaced by quickshell AppLauncher
-- dunst → replaced by quickshell NotificationOSD


-- ▓▒░ SMART GAPS (No gaps when only one tiled window or fullscreen)
hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })
hl.window_rule({
    name  = "smart-gaps-tiled",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding = 0,
})
hl.window_rule({
    name  = "smart-gaps-fullscreen",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding = 0,
})

-- ▓▒░ SYSTEM UTILITY DIALOGS
hl.window_rule({
    name   = "cachy-update-floating",
    match  = { class = "^(cachy-update|cachy\\.update|org\\.cachyos\\.update)$" },
    float  = true,
    center = true,
    size   = { 1150, 720 },
})

hl.window_rule({
    name   = "satty-floating",
    match  = { class = "^(com.gabm.satty)$" },
    float  = true,
    center = true,
})

-- ▓▒░ AUTHENTICATION PROMPTS
-- hyprpolkitagent (polkit), gcr-prompter (ssh key passphrases for
-- gcr-ssh-agent) and any pinentry. stay_focused is the point: with
-- follow_mouse = 1, nudging the mouse onto another window mid-password moves
-- keyboard focus there, and the rest of the password is typed into it.
-- NOTE: hyprpolkitagent is a plain Qt window, not a layer surface, so the
--       hyprpolkitagent alternative in blur-hyprtoolkit above never matches
--       it. dim_around here is what actually dims behind the polkit prompt.
hl.window_rule({
    name         = "auth-prompts",
    match        = { class = "^(hyprpolkitagent|gcr-prompter|pinentry-.*)$" },
    float        = true,
    center       = true,
    stay_focused = true,
    dim_around   = true,
})

