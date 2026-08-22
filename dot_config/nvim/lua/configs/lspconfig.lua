require("nvchad.configs.lspconfig").defaults()

local lspconfig = require "lspconfig"
local servers = {}

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

      lspconfig[server_name].setup(opts)
    end,
  },
} 
