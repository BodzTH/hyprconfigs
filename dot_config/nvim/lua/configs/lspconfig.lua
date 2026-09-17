require("nvchad.configs.lspconfig").defaults()

-- lua_ls is already configured + enabled by nvchad.configs.lspconfig.defaults()
-- taplo/marksman use their stock nvim-lspconfig configs as-is.
-- Nothing here installs anything: if a server binary isn't on PATH, it just
-- doesn't attach (verified: no error, 0 clients, editor unaffected).
vim.lsp.enable { "taplo", "marksman" }
