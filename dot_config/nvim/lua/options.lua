require "nvchad.options"

-- add yours here!

local o = vim.o
o.cursorlineopt ='both' -- to enable cursorline!
o.cursorline = true

-- Additional UX enhancements
o.scrolloff = 8         -- Minimum lines to keep above/below cursor
o.sidescrolloff = 8     -- Minimum columns to keep left/right of cursor

-- Arabic text rendering:
-- Delegate shaping/Bidi to the terminal emulator instead of Neovim.
-- This prevents broken cursor behavior and mispositioned characters.
-- NOTE: Your terminal must support Arabic shaping (Kitty, WezTerm, foot).
-- Do NOT set 'arabic' (forces RTL) or 'arabicshape' (broken legacy shaping).
o.termbidi = true

-- Providers: use python3, or python where that's the only name (portable across
-- distros). Other providers are unused, so skip them. The python provider needs
-- the `pynvim` module; without it only :python commands fail, nothing else.
local py = vim.fn.exepath "python3"
if py == "" then py = vim.fn.exepath "python" end
if py ~= "" then vim.g.python3_host_prog = py end
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
