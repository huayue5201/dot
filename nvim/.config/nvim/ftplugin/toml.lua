-- https://taplo.tamasfe.dev/cli/usage/language-server.html
local utils = require("user.utils")

local toml_config = {
	cmd = { "taplo", "lsp", "stdio" },
	filetypes = { "toml" },
}

-- 启动 LSP
vim.lsp.start(toml_config, {
	-- 重用现有的 LSP 客户端
	reuse_client = utils.reuse_client,
})

-- 调用自定义的 LSP 配置模块
require("user.lspconfig").lspSetup()
