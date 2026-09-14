require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"
local servers = { "gopls" }

local nvim_lspconfig = require "nvchad.configs.lspconfig"
local on_attach = nvim_lspconfig.on_attach
local on_init = nvim_lspconfig.on_init
local capabilities = nvim_lspconfig.capabilities

require("mason-lspconfig").setup {
  ensure_installed = servers,
  handlers = {
    function(server_name)
      if server_name == "lua_ls" then
        return
      end

      local opts = {
        on_attach = on_attach,
        on_init = on_init,
        capabilities = capabilities,
      }

      -- gopls: official Go language server (golang.org/x/tools/gopls)
      if server_name == "gopls" then
        opts.settings = {
          gopls = {
            analyses = {
              unusedparams = true,
              shadow = true,
            },
            staticcheck = true,
            gofumpt = false,
            codelenses = {
              gc_details = false,
              generate = true,
              regenerate_cgo = true,
              run_govulncheck = true,
              test = true,
              tidy = true,
              upgrade_dependency = true,
              vendor = true,
            },
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },
          },
        }
      end

      lspconfig[server_name].setup(opts)
    end,
  },
}
