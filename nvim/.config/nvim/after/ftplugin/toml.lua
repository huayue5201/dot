-- 调用lsp配置
require("config.lsp").lspSetup()

-- https://github.com/saecki/crates.nvim
vim.g.add({ source = "saecki/crates.nvim" })
require("crates").setup()
