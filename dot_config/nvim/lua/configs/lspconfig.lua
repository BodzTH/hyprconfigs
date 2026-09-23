require("nvchad.configs.lspconfig").defaults()

-- lua_ls is already configured + enabled by nvchad.configs.lspconfig.defaults()
-- taplo/marksman use their stock nvim-lspconfig configs as-is.
-- Nothing here installs anything: if a server binary isn't on PATH, it just
-- doesn't attach (verified: no error, 0 clients, editor unaffected).
-- python: ty (types, completion, goto) + ruff (lint, imports, format). Both are
-- single Rust binaries, node-free.
-- qmlls: quickshell's QML. Arch ships it as qmlls6. It resolves Quickshell's
-- types through ~/.config/quickshell/.qmlls.ini, which quickshell itself fills
-- in with its import paths once the (empty) file exists.
-- lua_ls in ~/.config/hypr picks up the Hyprland API (hl.*) from that tree's
-- .luarc.json, which points it at /usr/share/hypr/stubs.
vim.lsp.config("qmlls", { cmd = { "qmlls6" } })
vim.lsp.enable { "taplo", "marksman", "ty", "ruff", "qmlls" }

-- ty reports no type errors for a file outside any project (no pyproject.toml,
-- .git, ...). Fall back to the file's own directory so standalone scripts work.
vim.lsp.config("ty", {
  root_dir = function(bufnr, on_dir)
    local markers = { "ty.toml", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" }
    on_dir(vim.fs.root(bufnr, markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
  end,
})

-- ruff and ty both answer hover; keep ty's.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
  end,
})
