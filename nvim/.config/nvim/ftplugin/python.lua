-- start the LSP and get the client id
-- it will re-use the running client if one is found matching name and root_dir
-- see `:h vim.lsp.start()` for more info
vim.lsp.start({
  name = "pylyzer",
  cmd = { "pylyzer", "--server" },
  root_dir = vim.fs.root(0, {
    "setup.py",
    "tox.ini",
    "requirements.txt",
    "Pipfile",
    "pyproject.toml",
  }),
  filetypes = { "python" },
  single_file_support = true,
  settings = {
    python = {
      diagnostics = true,
      inlayHints = true,
      smartCompletion = true,
      checkOnType = false,
    },
  },
})

-- 调用lsp配置
require("utils.lsp_config").lspSetup()
