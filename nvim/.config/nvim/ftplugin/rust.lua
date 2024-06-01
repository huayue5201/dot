-- https://github.com/rust-analyzer/rust-analyzer

local utils = require("user.utils")

-- 定义潜在的 rust 项目根文件
local rust_root_files = {
  "Cargo.toml",
  "rust-project.json",
}

-- 查找项目的根目录
local root_dir = utils.find_root_dir(rust_root_files)

local rust_config = {
	name = "rust-analyzer",
	cmd = { "rust-analyzer" },
	root_dir = root_dir,
}

-- 启动 LSP
vim.lsp.start(rust_config, {
	-- 重用现有的 LSP 客户端
	reuse_client = utils.reuse_client,
})

-- 调用自定义的 LSP 配置模块
require("user.lspconfig").lspSetup()
