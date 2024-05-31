-- lua/ftplugin/c.lua
-- https://clangd.llvm.org/installation
local utils = require("user.utils")

-- 定义潜在的 C/C++ 项目根文件
local c_root_files = {
	"main.c",
	"Makefile",
	".clangd",
	".clang-tidy",
	".clang-format",
	"compile_commands.json",
	"compile_flags.txt",
	"configure.ac", -- AutoTools
}

-- 查找项目的根目录
local root_dir = utils.find_root_dir(c_root_files)

-- 默认 LSP 客户端能力
local default_capabilities = vim.lsp.protocol.make_client_capabilities()
default_capabilities.textDocument.completion.editsNearCursor = true

-- C/C++ LSP 配置
local c_config = {
	name = "clangd",
	cmd = { "clangd" },
	root_dir = root_dir,
	capabilities = default_capabilities,
  single_file_support = true,
}

-- 启动 LSP
vim.lsp.start(c_config, {
	-- 重用现有的 LSP 客户端
	reuse_client = utils.reuse_client,
})

-- 调用自定义的 LSP 配置模块
require("user.lspconfig").lspSetup()
