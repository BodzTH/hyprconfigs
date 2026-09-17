-- ▄▀█ █▄░█ █ █▀▄▀█ ▄▀█ ▀█▀ █ █▀█ █▄░█
-- █▀█ █░▀█ █ █░▀░█ █▀█ ░█░ █ █▄█ █░▀█
--
-- MODULE 6: ANIMATIONS & TRANSITIONS
-- Easing curves, window animations, and workspace transitions
-- See: https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- ═══════════════════════════════════════════════════════════════

hl.config({ animations = { enabled = true } })

-- ▓▒░ BEZIER CURVES — EASING FUNCTIONS
hl.curve("fluent_decel",  { type = "bezier", points = { {0, 0.2},    {0.4, 1}    } })
hl.curve("md3_decel",     { type = "bezier", points = { {0.05, 0.7}, {0.1, 1}    } })
hl.curve("md3_accel",     { type = "bezier", points = { {0.3, 0},    {0.8, 0.15} } })
hl.curve("winOut",        { type = "bezier", points = { {0.3, -0.3}, {0, 1}      } })
hl.curve("easeOutCirc",   { type = "bezier", points = { {0, 0.55},   {0.45, 1}   } })
hl.curve("easeOutCubic",  { type = "bezier", points = { {0.33, 1},   {0.68, 1}   } })
hl.curve("easeinoutsine", { type = "bezier", points = { {0.37, 0},   {0.63, 1}   } })

-- ▓▒░ WINDOW ANIMATIONS
hl.animation({ leaf = "global",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "windows",          enabled = true, speed = 2,   bezier = "easeOutCubic" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 3,   bezier = "md3_decel",    style = "popin 87%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 2.5, bezier = "winOut",       style = "popin 87%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 2.5, bezier = "easeinoutsine" })

-- ▓▒░ BORDER & FADE ANIMATIONS
hl.curve("linear",        { type = "bezier", points = { {0, 0},      {1, 1}      } })
hl.animation({ leaf = "border",           enabled = true, speed = 5,   bezier = "easeOutCirc" })
hl.animation({ leaf = "borderangle",      enabled = true, speed = 50,  bezier = "linear",       style = "loop" })
hl.animation({ leaf = "fade",             enabled = true, speed = 2,   bezier = "fluent_decel" })
hl.animation({ leaf = "fadeIn",           enabled = true, speed = 2,   bezier = "md3_decel" })
hl.animation({ leaf = "fadeOut",          enabled = true, speed = 1.5, bezier = "md3_accel" })

-- ▓▒░ LAYER ANIMATIONS (bar, OSD, popups)
hl.animation({ leaf = "layers",           enabled = true, speed = 2,   bezier = "md3_decel",    style = "slide bottom" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 2,   bezier = "md3_decel",    style = "slide bottom" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 1.5, bezier = "md3_accel" })
hl.animation({ leaf = "fadeLayersIn",     enabled = true, speed = 1.8, bezier = "fluent_decel" })
hl.animation({ leaf = "fadeLayersOut",    enabled = true, speed = 1.5, bezier = "md3_accel" })

-- ▓▒░ WORKSPACE TRANSITIONS
hl.animation({ leaf = "workspaces",       enabled = true, speed = 3,   bezier = "fluent_decel", style = "slidefade 20%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "md3_decel",    style = "slidevert" })
