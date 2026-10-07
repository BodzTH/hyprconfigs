-- Filetypes not listed format through their language server (lsp_format =
-- "fallback"): go (gopls), tex (texlab -> latexindent), rust (rust-analyzer ->
-- rustfmt).
local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    toml = { "taplo" },
    json = { "biome" },
    jsonc = { "biome" },
    css = { "biome" },
    html = { "biome" },
    yaml = { "yamlfmt" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    python = { "ruff_organize_imports", "ruff_format" },
  },

  formatters = {
    -- Biome's HTML formatter is off by default; turn it on unless the project
    -- has its own biome.json. (Without one, conform already passes the buffer's
    -- indent settings.)
    biome = {
      append_args = function(_, ctx)
        if vim.fs.root(ctx.dirname, { "biome.json", "biome.jsonc", ".biome.json", ".biome.jsonc" }) then
          return {}
        end
        return { "--html-formatter-enabled=true" }
      end,
    },
  },

  format_on_save = function(bufnr)
    -- latexindent is slow to start
    return { timeout_ms = vim.bo[bufnr].filetype == "tex" and 3000 or 1000, lsp_format = "fallback" }
  end,
}

return options
