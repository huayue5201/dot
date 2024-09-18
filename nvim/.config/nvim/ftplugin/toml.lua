-- start the LSP and get the client id
-- it will re-use the running client if one is found matching name and root_dir
-- see `:h vim.lsp.start()` for more info
vim.lsp.start({
	name = "taplo",
	cmd = { "taplo", "lsp", "stdio" },
	filetypes = { "toml" },
	root_dir = vim.fs.root(0, {
		"*.toml",
		".git",
	}),
})
-- 调用lsp配置
require("utils.lspopts").lspSetup()
