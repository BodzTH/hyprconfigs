-- Wallpaper accent, written by ~/.config/hypr/scripts/sync_border.py to
-- ~/.local/state/hypr/accent. chadrc puts it in base_30.nord_blue (normal-mode
-- badge, tab close button, LSP name in the statusline).
--
-- base46 draws from a compiled cache, not from chadrc, so a changed accent needs
-- a recompile: sync() does it at startup when the cache was built for a different
-- accent, and sync_border.py calls reload() in every running nvim over RPC.

local M = {}

local state = (vim.env.XDG_STATE_HOME or vim.fn.expand "~/.local/state") .. "/hypr/accent"
local stamp = vim.g.base46_cache .. "accent" -- accent the cache was compiled with

local function read_hex(path)
  local f = io.open(path)
  if not f then
    return nil
  end
  local line = f:read "*l"
  f:close()
  return line and line:match "^#?(%x%x%x%x%x%x)%s*$"
end

-- "#rrggbb"; Platinum when sync_border.py hasn't run yet, as it does for
-- greyscale wallpapers.
M.get = function()
  local hex = read_hex(state)
  return "#" .. (hex and hex:lower() or "e5e5e5")
end

local function write_stamp(color)
  local f = io.open(stamp, "w")
  if f then
    f:write(color:sub(2), "\n")
    f:close()
  end
end

-- Startup, before the cache is loaded.
M.sync = function()
  local color = M.get()
  if read_hex(stamp) ~= color:sub(2) then
    require("base46").compile()
    write_stamp(color)
  end
end

-- Live, over RPC. Re-reads the state file rather than taking the colour as an
-- argument, so out-of-order calls from rapid wallpaper changes still end on the
-- latest accent.
M.reload = function()
  local color = M.get()
  local themes = require("nvconfig").base46.changed_themes
  themes.all = vim.tbl_deep_extend("force", themes.all or {}, { base_30 = { nord_blue = color } })
  require("base46").load_all_highlights()
  require("plenary.reload").reload_module "volt.highlights"
  require "volt.highlights"
  write_stamp(color)
end

return M
