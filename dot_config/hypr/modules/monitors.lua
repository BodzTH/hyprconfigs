-- █▀▄▀█ █▀█ █▄░█ █ ▀█▀ █▀█ █▀█ █▀
-- █░▀░█ █▄█ █░▀█ █ ░█░ █▄█ █▀▄ ▄█
--
-- MODULE 3: MONITORS & WORKSPACES
-- Display configuration and workspace assignments
-- Dynamically loaded from hosts profile for hardware portability
-- See: https://wiki.hypr.land/Configuring/Basics/Monitors/
-- ═══════════════════════════════════════════════════════════════

local host = require("hosts")

for _, mon in ipairs(host.monitors or {}) do
    hl.monitor(mon)
end
