local options = {
  formatters_by_ft = {
    lua = { "stylua" },
    toml = { "taplo" },
    json = { "jq" },
    yaml = { "yamlfmt" },
    sh = { "shfmt" },
    bash = { "shfmt" },
  },

  format_on_save = {
    -- These options will be passed to conform.format()
    timeout_ms = 500,
    lsp_format = "fallback",
  },
}

return options
