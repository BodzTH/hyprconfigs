-- Host Profile Loader Helper
-- Automatically detects system hostname and loads matching profile with fallback
local f = io.popen("hostname 2>/dev/null")
local hostname = f and f:read("*l")
if f then f:close() end

if not hostname or hostname == "" then
    hostname = "default"
end

local ok, profile = pcall(require, "hosts." .. hostname)
if not ok or type(profile) ~= "table" then
    profile = require("hosts.default")
end

return profile
