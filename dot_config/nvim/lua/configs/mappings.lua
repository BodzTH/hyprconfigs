-- Helper variables
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- =======================================================
-- 1. DELETE vs CUT SEPARATION
-- =======================================================
-- d = delete silently (black hole, nothing goes to clipboard)
map({"n", "v"}, "d", '"_d', { desc = "Delete (no clipboard)" })
map("n", "dd", '"_dd', { desc = "Delete line (no clipboard)" })
map({"n", "v"}, "c", '"_c', { desc = "Change (no clipboard)" })
map("n", "cc", '"_cc', { desc = "Change line (no clipboard)" })

-- x = cut to system clipboard (the VS Code Ctrl+X equivalent for chars)
map({"n", "v"}, "x", '"+d', { desc = "Cut to clipboard" })
map("n", "X", '"+dd', { desc = "Cut line to clipboard" })

-- Fix "Paste Over Selection" behavior
map("v", "p", '"_dP', { desc = "Paste without overwriting clipboard" })

-- =======================================================
-- 2. VS CODE CLIPBOARD (System Clipboard)
-- =======================================================
-- Copy (Ctrl+C)
map("v", "<C-c>", '"+y', { desc = "Copy selection to clipboard" }) 
map("n", "<C-c>", '"+yy', { desc = "Copy line to clipboard" })
map("i", "<C-c>", '<Esc>"+yygi', { desc = "Copy line in insert mode" })

-- Cut (Ctrl+X)
map("v", "<C-x>", '"+d', { desc = "Cut selection to clipboard" })
map("n", "<C-x>", '"+dd', { desc = "Cut line to clipboard" })
map("i", "<C-x>", '<Esc>"+ddgi', { desc = "Cut line in insert mode" })

-- Paste (Ctrl+V)
map("n", "<C-v>", '"+p', { desc = "Paste from clipboard" })
map("i", "<C-v>", '<C-r>+', { desc = "Paste in insert mode" })
map("v", "<C-v>", '"+p', { desc = "Paste (replace selection)" })
map("c", "<C-v>", "<C-r>+", { desc = "Paste in command line" })

-- =======================================================
-- 3. VS CODE EDITING & MANIPULATION
-- =======================================================
-- Undo/Redo
map("n", "<C-z>", "u", { desc = "Undo" })
map("i", "<C-z>", "<C-o>u", { desc = "Undo in insert mode" })
map("n", "<C-y>", "<C-r>", { desc = "Redo" })
map("i", "<C-y>", "<C-o><C-r>", { desc = "Redo in insert mode" })

-- Select All
map("n", "<C-a>", "ggVG", { desc = "Select all text" })
map("i", "<C-a>", "<Esc>ggVG", { desc = "Select all in insert mode" })

-- Save File
map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>", { desc = "Save file" })

-- Delete Line
map("n", "<C-S-k>", '"_dd', { desc = "Delete line" })
map("i", "<C-S-k>", '<C-o>"_dd', { desc = "Delete line in insert mode" })

-- Move Lines
map("n", "<M-Up>", ":m .-2<CR>==", { desc = "Move line up" })
map("n", "<M-Down>", ":m .+1<CR>==", { desc = "Move line down" })
map("i", "<M-Up>", "<Esc>:m .-2<CR>==gi", { desc = "Move line up" })
map("i", "<M-Down>", "<Esc>:m .+1<CR>==gi", { desc = "Move line down" })
map("v", "<M-Up>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
map("v", "<M-Down>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })

-- Duplicate Line
map("n", "<S-M-Down>", "yyp", { desc = "Duplicate line down" })
map("i", "<S-M-Down>", "<Esc>yypgi", { desc = "Duplicate line down" })

-- =======================================================
-- 4. VS CODE NAVIGATION & TOOLS
-- =======================================================
-- Find/Search
map("n", "<C-f>", "<cmd> Telescope live_grep <cr>", { desc = "Find Text (Live Grep)" })
map("n", "<C-p>", "<cmd> Telescope find_files <cr>", { desc = "Find File" })

-- Sidebar & Comments
map("n", "<C-b>", "<cmd> NvimTreeToggle <cr>", { desc = "Toggle Explorer" })
map({ "n", "i", "v" }, "<C-_>", "<cmd>lua require('Comment.api').toggle.linewise.current()<CR>", { desc = "Toggle Comment" })
map({ "n", "i", "v" }, "<C-/>", "<cmd>lua require('Comment.api').toggle.linewise.current()<CR>", { desc = "Toggle Comment" })
map("n", "<C-S-p>", "<cmd> Telescope commands <cr>", { desc = "Command Palette" })

-- =======================================================
-- 5. KEYBOARD QOL TWEAKS
-- =======================================================

-- Map ; to : (So you don't need Shift for commands)
map("n", ";", ":", { desc = "Enter command mode", nowait = true })

-- Visual mode indentation (keeps selection active)
map("v", "<", "<gv", { desc = "Indent line left and keep selection" })
map("v", ">", ">gv", { desc = "Indent line right and keep selection" })

-- Optional: Map : back to ; just in case you ever need the repeat finding feature
-- map("n", ":", ";", { desc = "Repeat find char" })

-- =======================================================
-- 6. LEADER (SPACE) MAPPINGS — shown in which-key
-- =======================================================

-- Register which-key groups so Space shows a labelled menu
local ok, wk = pcall(require, "which-key")
if ok then
  wk.add({
    { "<leader>f", group = "Find / File" },
    { "<leader>b", group = "Buffers" },
    { "<leader>l", group = "LSP" },
    { "<leader>g", group = "Git" },
    { "<leader>t", group = "Terminal" },
    { "<leader>u", group = "UI" },
  })
end

-- File / Find
map("n", "<leader>ff", "<cmd>Telescope find_files<cr>",           { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<cr>",            { desc = "Live grep" })
map("n", "<leader>fb", "<cmd>Telescope buffers<cr>",              { desc = "Find buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<cr>",            { desc = "Help tags" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<cr>",             { desc = "Recent files" })
map("n", "<leader>fs", "<cmd>w<cr>",                              { desc = "Save file" })
map("n", "<leader>fe", "<cmd>NvimTreeToggle<cr>",                 { desc = "Explorer" })

-- Buffers
map("n", "<leader>bd", "<cmd>bd<cr>",                             { desc = "Delete buffer" })
map("n", "<leader>bn", "<cmd>bnext<cr>",                          { desc = "Next buffer" })
map("n", "<leader>bp", "<cmd>bprev<cr>",                          { desc = "Prev buffer" })
map("n", "<leader>bD", "<cmd>%bd|e#|bd#<cr>",                    { desc = "Delete all others" })

-- LSP
map("n", "<leader>ld", "<cmd>lua vim.lsp.buf.definition()<cr>",   { desc = "Go to definition" })
map("n", "<leader>lD", "<cmd>lua vim.lsp.buf.declaration()<cr>",  { desc = "Go to declaration" })
map("n", "<leader>lr", "<cmd>lua vim.lsp.buf.references()<cr>",   { desc = "References" })
map("n", "<leader>li", "<cmd>lua vim.lsp.buf.implementation()<cr>",{ desc = "Implementation" })
map("n", "<leader>lR", "<cmd>lua vim.lsp.buf.rename()<cr>",       { desc = "Rename symbol" })
map("n", "<leader>la", "<cmd>lua vim.lsp.buf.code_action()<cr>",  { desc = "Code actions" })
map("n", "<leader>lf", "<cmd>lua vim.lsp.buf.format()<cr>",       { desc = "Format file" })
map("n", "<leader>lk", "<cmd>lua vim.lsp.buf.hover()<cr>",        { desc = "Hover docs" })
map("n", "<leader>le", "<cmd>lua vim.diagnostic.open_float()<cr>",{ desc = "Line diagnostics" })
map("n", "<leader>lq", "<cmd>lua vim.diagnostic.setloclist()<cr>",{ desc = "Diagnostics list" })
map("n", "<leader>ln", "<cmd>lua vim.diagnostic.goto_next()<cr>", { desc = "Next diagnostic" })
map("n", "<leader>lp", "<cmd>lua vim.diagnostic.goto_prev()<cr>", { desc = "Prev diagnostic" })

-- Git (requires gitsigns, already in NvChad)
map("n", "<leader>gp", "<cmd>lua require('gitsigns').preview_hunk()<cr>",     { desc = "Preview hunk" })
map("n", "<leader>gb", "<cmd>lua require('gitsigns').blame_line()<cr>",       { desc = "Blame line" })
map("n", "<leader>gs", "<cmd>lua require('gitsigns').stage_hunk()<cr>",       { desc = "Stage hunk" })
map("n", "<leader>gr", "<cmd>lua require('gitsigns').reset_hunk()<cr>",       { desc = "Reset hunk" })
map("n", "<leader>gS", "<cmd>lua require('gitsigns').stage_buffer()<cr>",     { desc = "Stage buffer" })
map("n", "<leader>gR", "<cmd>lua require('gitsigns').reset_buffer()<cr>",     { desc = "Reset buffer" })
map("n", "<leader>gd", "<cmd>lua require('gitsigns').diffthis()<cr>",         { desc = "Diff this" })
map("n", "<leader>gl", "<cmd>Telescope git_commits<cr>",                      { desc = "Git log" })

-- Terminal
map("n", "<leader>tt", "<cmd>lua require('nvchad.term').toggle { pos = 'float' }<cr>",    { desc = "Float terminal" })
map("n", "<leader>th", "<cmd>lua require('nvchad.term').toggle { pos = 'sp' }<cr>",       { desc = "Horizontal terminal" })
map("n", "<leader>tv", "<cmd>lua require('nvchad.term').toggle { pos = 'vsp' }<cr>",      { desc = "Vertical terminal" })

-- UI toggles
map("n", "<leader>uw", "<cmd>set wrap!<cr>",                      { desc = "Toggle wrap" })
map("n", "<leader>un", "<cmd>set number!<cr>",                    { desc = "Toggle line numbers" })
map("n", "<leader>ur", "<cmd>set relativenumber!<cr>",            { desc = "Toggle relative numbers" })
map("n", "<leader>uh", "<cmd>nohlsearch<cr>",                     { desc = "Clear search highlight" })
map("n", "<leader>ut", "<cmd>lua require('nvchad.themes').open()<cr>", { desc = "Change theme" })
