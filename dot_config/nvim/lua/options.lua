require "nvchad.options"

-- add yours here!

local o = vim.o
o.cursorlineopt ='both' -- to enable cursorline!
o.cursorline = true

-- Additional UX enhancements
o.relativenumber = true -- Relative line numbers for easy jumping
o.scrolloff = 8         -- Minimum lines to keep above/below cursor
o.sidescrolloff = 8     -- Minimum columns to keep left/right of cursor

-- Arabic text rendering:
-- Delegate shaping/Bidi to the terminal emulator instead of Neovim.
-- This prevents broken cursor behavior and mispositioned characters.
-- NOTE: Your terminal must support Arabic shaping (Kitty, WezTerm, foot).
-- Do NOT set 'arabic' (forces RTL) or 'arabicshape' (broken legacy shaping).
o.termbidi = true
