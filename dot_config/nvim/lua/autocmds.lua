require "nvchad.autocmds"

local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- Highlight on yank (micro-animation feedback)
autocmd("TextYankPost", {
  desc = "Highlight text briefly when yanked (copied)",
  group = augroup("YankHighlight", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ hlgroup = "IncSearch", timeout = 150 })
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

-- Go: organize imports on save via gopls
autocmd("BufWritePre", {
  desc = "Go: organize imports before save",
  group = augroup("GoOrganizeImports", { clear = true }),
  pattern = "*.go",
  callback = function()
    local params = vim.lsp.util.make_range_params()
    params.context = { only = { "source.organizeImports" } }
    local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
    for _, res in pairs(result or {}) do
      for _, r in pairs(res.result or {}) do
        if r.edit then
          vim.lsp.util.apply_workspace_edit(r.edit, "utf-16")
        end
      end
    end
  end,
})
