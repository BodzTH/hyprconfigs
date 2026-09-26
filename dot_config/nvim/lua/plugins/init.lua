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

  -- Diagnostic messages as wrapped bubbles at the end of the line, instead of
  -- virtual text that runs off the screen. Errors show on every line; warnings
  -- and hints only on the cursor line (hover or K shows them anywhere).
  -- vim.diagnostic.config's virtual_text = false lives in configs/lspconfig.lua.
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "VeryLazy",
    priority = 1000,
    opts = {
      preset = "modern",
      options = {
        show_source = { enabled = true, if_many = true }, -- ty vs ruff
        multilines = {
          enabled = true,
          always_show = true,
          severity = { vim.diagnostic.severity.ERROR },
        },
      },
    },
  },

  -- Problems panel (VSCode Ctrl+Shift+M): <C-S-m>, <leader>lx / <leader>lX.
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    config = function(_, opts)
      dofile(vim.g.base46_cache .. "trouble")
      require("trouble").setup(opts)
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
