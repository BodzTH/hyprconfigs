-- Host Profile Loader Helper
-- Automatically detects system hostname and loads matching profile with fallback

-- /proc first: always present on Linux, and no subprocess on every reload. The
-- `hostname` binary is only a fallback — on Arch it ships in inetutils, which is
-- not part of `base`, so a fresh host without it would silently load
-- hosts/default.lua (no AQ_DRM_DEVICES, no monitor rules) with no error at all.
local function read_hostname()
    local f = io.open("/proc/sys/kernel/hostname", "r")
    if f then
        local name = f:read("*l")
        f:close()
        if name and name ~= "" then
            return name
        end
    end
    local p = io.popen("hostname 2>/dev/null")
    local name = p and p:read("*l")
    if p then p:close() end
    return name
end

local hostname = read_hostname()

if not hostname or hostname == "" then
    hostname = "default"
end

local ok, profile = pcall(require, "hosts." .. hostname)
if not ok or type(profile) ~= "table" then
    profile = require("hosts.default")
end

return profile
