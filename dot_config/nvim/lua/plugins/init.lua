return {
  {
    "stevearc/conform.nvim",
    event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter",
    -- nvim-treesitter (main) keeps highlight queries in runtime/queries and only
    -- copies them into place on :TSInstall. Parsers installed by the system
    -- package manager (e.g. pacman's tree-sitter-python) never get them, so the
    -- buffer renders all white. Append (not prepend) so Neovim's bundled queries
    -- still win for its bundled parsers (lua, vim, markdown, ...).
    init = function(plugin)
      vim.opt.rtp:append(plugin.dir .. "/runtime")
    end,
    opts = {
      ensure_installed = {
        "vim", "vimdoc", "query",
        "lua", "luadoc",
        "json", "jsonc", "yaml", "toml",
        "markdown", "markdown_inline",
        "bash", "diff", "gitcommit",
        "python",
        "qmljs", "fish",
      },
    },
  },
}
