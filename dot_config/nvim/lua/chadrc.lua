-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

-- M.base46 = {
-- 	theme = "nord",
--
-- 	-- hl_override = {
-- 	-- 	Comment = { italic = true },
-- 	-- 	["@comment"] = { italic = true },
-- 	-- },
-- }

M.base46 = {
    -- Must match the key under changed_themes below, or the custom palette is ignored.
    -- Note: the theme picker (<leader>ut) rewrites this line.
    theme = "onedark",
    integrations = { "trouble" },
    -- VSCode-style squiggles under errors (kitty draws coloured undercurls).
    hl_add = {
        DiagnosticUnderlineError = { undercurl = true, sp = "red" },
        DiagnosticUnderlineWarn  = { undercurl = true, sp = "yellow" },
        DiagnosticUnderlineInfo  = { undercurl = true, sp = "green" },
        DiagnosticUnderlineHint  = { undercurl = true, sp = "purple" },
    },
    changed_themes = {
        -- Wallpaper accent (lua/accent.lua), under `all` so it survives the theme picker.
        all = { base_30 = { nord_blue = require("accent").get() } },
        onedark = {
            base_30 = {
                white          = "#e5e5e5", -- Platinum White text
                black          = "#111111", -- Obsidian Black main background
                darker_black   = "#0a0a0a", -- Darker background for file managers (NvimTree)
                black2         = "#161616", 
                one_bg         = "#1c1c1c", -- Muted Charcoal for panels and UI containers
                one_bg2        = "#262626",
                one_bg3        = "#3d3d3d",
                grey           = "#555555", -- Muted UI elements / borders
                grey_dark      = "#3d3d3d",
                line_bg        = "#161616",
                light_grey     = "#888888",
                red            = "#d75f5f", -- Muted functional syntax tones
                green          = "#87af87",
                yellow         = "#dfaf87",
                blue           = "#87afaf",
                purple         = "#af87af",
                cyan           = "#87afd7",
                statusline_bg  = "#1c1c1c",
                pmenu_bg       = "#87afaf", -- selected dropdown row (text on it is `black`)
                folder_bg      = "#87afaf",
            },
            base_16 = {
                base00 = "#111111", -- Editor background
                base01 = "#1c1c1c", -- Lighter background (status lines)
                base02 = "#262626", -- Selection highlight background
                base03 = "#888888", -- Comments and invisible marks
                base04 = "#888888", -- Dark foreground text
                base05 = "#e5e5e5", -- Default code text color (Platinum White)
                base06 = "#ffffff", -- Light foreground accent
                base07 = "#ffffff", -- Light background element
                base08 = "#d75f5f", -- Variables and tags
                base09 = "#dfaf87", -- Numbers and Booleans
                base0A = "#dfaf87", -- Classes and internal structures
                base0B = "#87af87", -- Strings
                base0C = "#87afd7", -- Escape characters
                base0D = "#87afaf", -- Functions and Methods
                base0E = "#af87af", -- Keywords and storage types
                base0F = "#d75f5f", -- Errors and structural anomalies
            }
        }
    }
}
-- M.nvdash = { load_on_startup = true }
-- M.ui = {
--       tabufline = {
--          lazyload = false
--      }
-- }

return M
