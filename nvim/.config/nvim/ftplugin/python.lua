-- lua/ftplugin/python.lua
-- https://github.com/mtshiba/pylyzer

local utils = require("user.utils")

-- 定义潜在的 python 项目根文件
local python_root_files = {
	"setup.py",
	"tox.ini",
	"requirements.txt",
	"Pipfile",
	"pyproject.toml",
}

-- 查找项目的根目录
local root_dir = utils.find_root_dir(python_root_files) -- C/C++ LSP 配置

local python_config = {
	name = "pylyzer",
	cmd = { "pylyzer", "--server" },
	root_dir = root_dir,
	settings = {
		python = {
			diagnostics = true,
			inlayHints = true,
			smartCompletion = true,
			checkOnType = false,
		},
	},
}

-- 启动 LSP
vim.lsp.start(python_config, {
	-- 重用现有的 LSP 客户端
	reuse_client = utils.reuse_client,
})

-- 调用自定义的 LSP 配置模块
require("user.lspconfig").lspSetup()
