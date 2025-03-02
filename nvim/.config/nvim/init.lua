-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- 设置配色方案
-- vim.cmd("colorscheme dawn")

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.g.maplocalleader = vim.keycode(",")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })
vim.keymap.set({ "n", "v" }, ",", "<Nop>", { silent = true })

-- 加载配置文件
require("config.settings")
require("config.autocmds")
require("config.usercmds")
require("config.statusline")
require("config.keymaps")
require("config.shada")

-- 全局lsp配置
vim.lsp.config("*", {
	capabilities = {
		textDocument = {
			semanticTokens = {
				multilineTokenSupport = true,
			},
		},
	},
	root_markers = { ".git" },
})
-- 启用 LSP 服务器
vim.lsp.enable({ "lua_ls", "clangd", "taplo", "rust-analyzer" })

-- 插件管理：手动安装 mini.nvim
local path_package = vim.fn.stdpath("data") .. "/site/"
local mini_path = path_package .. "pack/deps/start/mini.nvim"
if not vim.loop.fs_stat(mini_path) then
	-- 克隆 mini.nvim 插件
	vim.cmd('echo "Installing `mini.nvim`" | redraw')
	local clone_cmd = {
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/echasnovski/mini.nvim",
		mini_path,
	}
	vim.fn.system(clone_cmd)
	vim.cmd("packadd mini.nvim | helptags ALL")
	vim.cmd('echo "Installed `mini.nvim`" | redraw')
end

-- 配置 MiniDeps 插件
require("mini.deps").setup({ path = { package = path_package } })

-- 加载 MiniDeps 插件
local MiniDeps = require("mini.deps")

-- 配置全局插件管理 API
vim.g.add, vim.g.now, vim.g.later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- 添加 fzf 到 runtimepath
vim.opt.runtimepath:append("/opt/homebrew/opt/fzf")
