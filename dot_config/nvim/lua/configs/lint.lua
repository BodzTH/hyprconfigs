-- Linters that aren't language servers, fed into vim.diagnostic (so they show in
-- the squiggles, inline messages, hover popup and Problems panel like any LSP).
-- yaml: yamllint, since its only language server needs Node.js.

local M = {}

local ns = vim.api.nvim_create_namespace "lint"

local linters = {
  yaml = {
    -- lints stdin; parsable lines look like: stdin:3:5: [error] message (rule)
    cmd = { "yamllint", "-f", "parsable", "-" },
    source = "yamllint",
    parse = function(line)
      local lnum, col, level, msg = line:match "^[^:]+:(%d+):(%d+): %[(%a+)%] (.+)$"
      if not lnum then
        return
      end
      local code
      msg = msg:gsub("%s*%(([%w-]+)%)$", function(rule)
        code = rule
        return ""
      end)
      return {
        lnum = tonumber(lnum) - 1,
        col = tonumber(col) - 1,
        severity = level == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
        message = msg,
        code = code,
      }
    end,
  },
}

local function lint(buf)
  local linter = linters[vim.bo[buf].filetype]
  if not linter or vim.fn.executable(linter.cmd[1]) == 0 then
    return
  end
  local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
  local tick = vim.b[buf].changedtick
  vim.system(linter.cmd, {
    stdin = text,
    text = true,
    -- run where the file lives so a project .yamllint config is picked up
    cwd = vim.fs.dirname(vim.api.nvim_buf_get_name(buf)),
  }, function(out)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      -- the buffer changed while linting (this also happens once right after
      -- the file loads): lint the current text instead
      if vim.b[buf].changedtick ~= tick then
        return lint(buf)
      end
      local diags = {}
      for _, line in ipairs(vim.split(out.stdout or "", "\n", { trimempty = true })) do
        local d = linter.parse(line)
        if d then
          d.source = linter.source
          diags[#diags + 1] = d
        end
      end
      vim.diagnostic.set(ns, buf, diags)
    end)
  end)
end

M.setup = function()
  vim.api.nvim_create_autocmd({ "FileType", "BufWritePost", "InsertLeave", "TextChanged" }, {
    group = vim.api.nvim_create_augroup("Lint", { clear = true }),
    callback = function(args)
      lint(args.buf)
    end,
  })
  -- buffers opened before this module loaded (it loads with lspconfig)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      lint(buf)
    end
  end
end

return M
