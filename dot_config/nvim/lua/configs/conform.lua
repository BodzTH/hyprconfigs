local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    toml = { "taplo" },
    json = { "jq" },
    yaml = { "yamlfmt" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    python = { "ruff_organize_imports", "ruff_format" },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 500,
    lsp_format = "fallback",
  },
}

return options
