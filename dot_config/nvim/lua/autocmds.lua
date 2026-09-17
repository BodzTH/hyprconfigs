require "nvchad.autocmds"

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank (micro-animation feedback)
autocmd("TextYankPost", {
  desc = "Highlight text briefly when yanked (copied)",
  group = augroup("YankHighlight", { clear = true }),
  callback = function()
    vim.hl.on_yank({ hlgroup = "IncSearch", timeout = 150 })
  end,
})

-- Go to last cursor position when opening a file
autocmd("BufReadPost", {
  desc = "Return to last cursor position when reopening a file",
  group = augroup("LastCursorPosition", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Auto-resize window splits on resize
autocmd("VimResized", {
  desc = "Automatically resize split layouts when window is resized",
  group = augroup("WindowResizeReset", { clear = true }),
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})
