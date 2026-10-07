require("nvchad.configs.lspconfig").defaults()

-- Servers come from official pacman packages only, none needing Node.js:
--   python ty + ruff · go gopls · latex texlab · html/css/json biome · toml taplo-cli
--   markdown marksman · lua lua-language-server · qml qmlls6 · rust rust-analyzer
-- yaml has no Node-free server: yamllint (configs/lint.lua) + yamlfmt instead.
-- Nginx and .conf files get Neovim's built-in syntax, no server.
-- lua_ls is already configured + enabled by nvchad.configs.lspconfig.defaults().
-- Nothing here installs anything: if a server binary isn't on PATH, it just
-- doesn't attach (verified: no error, 0 clients, editor unaffected). That keeps
-- rust_analyzer harmless until Rust is installed.
-- NvChad puts Mason's bin/ first on PATH, so don't install servers through
-- Mason too, or its copy shadows the pacman one.
-- python: ty (types, completion, goto) + ruff (lint, imports, format). Both are
-- single Rust binaries, node-free.
-- qmlls: quickshell's QML. Arch ships it as qmlls6. It resolves Quickshell's
-- types through ~/.config/quickshell/.qmlls.ini, which quickshell itself fills
-- in with its import paths once the (empty) file exists.
-- lua_ls in ~/.config/hypr picks up the Hyprland API (hl.*) from that tree's
-- .luarc.json, which points it at /usr/share/hypr/stubs.
vim.lsp.config("qmlls", { cmd = { "qmlls6" } })
vim.lsp.enable { "taplo", "marksman", "ty", "ruff", "qmlls", "gopls", "texlab", "biome", "rust_analyzer" }

-- ty reports no type errors for a file outside any project (no pyproject.toml,
-- .git, ...). Fall back to the file's own directory so standalone scripts work.
vim.lsp.config("ty", {
  root_dir = function(bufnr, on_dir)
    local markers = { "ty.toml", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" }
    on_dir(vim.fs.root(bufnr, markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
  end,
})

-- Biome only attaches where a biome.json exists. Use the project (or the file's
-- directory) anyway, so standalone HTML/CSS/JSON get biome's defaults.
vim.lsp.config("biome", {
  workspace_required = false,
  root_dir = function(bufnr, on_dir)
    local markers = { "biome.json", "biome.jsonc", "package.json", ".git" }
    on_dir(vim.fs.root(bufnr, markers) or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))
  end,
})

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      staticcheck = true,
      analyses = { unusedparams = true, unusedvariable = true, shadow = true },
      hints = {
        assignVariableTypes = true,
        compositeLiteralFields = true,
        constantValues = true,
        functionTypeParameters = true,
        parameterNames = true,
        rangeVariableTypes = true,
      },
    },
  },
})

-- Go: organize imports before conform formats on save. From gopls' own Neovim
-- docs (golang/tools gopls/doc/vim.md), formatting left to conform.
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.go",
  callback = function(args)
    local client = vim.lsp.get_clients({ bufnr = args.buf, name = "gopls" })[1]
    if not client then
      return
    end
    local params = vim.lsp.util.make_range_params(0, client.offset_encoding)
    params.context = { only = { "source.organizeImports" } }
    local result = client:request_sync("textDocument/codeAction", params, 3000, args.buf)
    for _, action in ipairs(result and result.result or {}) do
      if action.edit then
        vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
      end
    end
  end,
})

-- LaTeX: chktex lint, latexindent format. Build with <leader>lb (latexmk), not
-- on save: latexmk runs a project's latexmkrc, which is Perl code, so a
-- downloaded project's code should only run when asked to.
vim.lsp.config("texlab", {
  settings = {
    texlab = {
      build = { onSave = false },
      chktex = { onOpenAndSave = true, onEdit = false },
      latexFormatter = "latexindent",
    },
  },
})

-- TOML: keep taplo offline. It downloads a JSON-schema catalog from
-- schemastore.org while initializing, before any settings reach it, so the
-- setting alone can't stop it: run it in an empty network namespace (util-linux
-- unshare) as well. TOML still gets syntax errors and formatting.
vim.lsp.config("taplo", {
  cmd = { "unshare", "--user", "--map-current-user", "--net", "taplo", "lsp", "stdio" },
  settings = { evenBetterToml = { schema = { enabled = false } } },
})

vim.lsp.config("lua_ls", { settings = { Lua = { hint = { enable = true } } } })

-- Rust (not installed yet): clippy instead of cargo check for diagnostics.
vim.lsp.config("rust_analyzer", {
  settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
})

-- ruff and ty both answer hover; keep ty's.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end
    if client and client.name == "texlab" then
      vim.keymap.set("n", "<leader>lb", "<cmd>LspTexlabBuild<cr>", { buffer = args.buf, desc = "Build PDF (latexmk)" })
    end
  end,
})

-- Diagnostics: squiggly underlines (theme colours, see chadrc hl_add), messages
-- drawn inline by tiny-inline-diagnostic (lua/plugins/init.lua) instead of the
-- truncated built-in virtual text, worst first.
vim.diagnostic.config {
  virtual_text = false,
  severity_sort = true,
  float = { border = "rounded", source = "if_many" },
}

-- Inferred types / parameter names inline (x: int, f(value=...)); <leader>ui toggles.
vim.lsp.inlay_hint.enable()

-- Hover popup (mouse + K) with type, docs and errors in one place.
require("configs.hover").setup()

-- yamllint diagnostics (yaml has no Node-free language server).
require("configs.lint").setup()
