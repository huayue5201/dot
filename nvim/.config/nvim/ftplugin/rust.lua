-- start the LSP and get the client id
-- it will re-use the running client if one is found matching name and root_dir
-- see `:h vim.lsp.start()` for more info
vim.lsp.start({
  name = "rust-analyzer",
  cmd = { "rust-analyzer" },
  root_dir = vim.fs.root(0, {
    "Cargo.toml",
    "rust-project.json",
  }),
  filetypes = { "rust" },
  single_file_support = true,
  settings = {
    ["rust-analyzer"] = {
      experimental = {
        serverStatusNotification = true,
      },
      imports = {
        granularity = {
          group = "module",
        },
        prefix = "self",
      },
      cargo = {
        buildScripts = {
          enable = true,
        },
      },
      procMacro = {
        enable = true,
      },
      hint = {
        enable = true,
      },
      codelens = {
        enable = true,
      },
    },
  },
})
-- 调用lsp配置
require("utils.lsp_config").lspSetup()
