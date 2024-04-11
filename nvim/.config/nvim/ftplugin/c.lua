local root_files = {
	"main.c",
	"Makefile",
	".clangd",
	".clang-tidy",
	".clang-format",
	"compile_commands.json",
	"compile_flags.txt",
	"configure.ac", -- AutoTools
}

local default_capabilities = vim.lsp.protocol.make_client_capabilities()
default_capabilities.textDocument.completion.editsNearCursor = true

local config = {
	name = "clangd", -- 语言服务器名称
	cmd = { "clangd" }, -- 启动命令
	root_dir = vim.fs.dirname(vim.fs.find(root_files, { upward = true, stop = vim.env.HOME })[1]),
	capabilities = default_capabilities,
}

-- 启动 LSP
vim.lsp.start(config, {
	reuse_client = function(client, conf)
		return (client.name == conf.name and (client.config.root_dir == conf.root_dir or conf.root_dir == nil))
	end,
})

-- 调用自定义的 LSP 配置模块
require("util.lspconfig").lspSetup()
