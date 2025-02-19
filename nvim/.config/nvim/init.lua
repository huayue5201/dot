-- Neovim 官方 GitHub
-- https://github.com/neovim/neovim
-- Neovim 官方发布
-- https://github.com/neovim/neovim/releases/
-- Vim 中文操作手册
-- https://vim.rtorr.com/lang/zh_cn

-- 启动时开启 Lua 的内置加载器，可以加速 Neovim 启动过程
vim.loader.enable()

-- 设置配色方案
vim.cmd("colorscheme dawn")

-- 将 Leader 键设置为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

require("config.settings") -- 加载全局设置
require("config.autocmds_and_commands") -- 加载自动命令和用户命令配置
require("config.statusline") -- 加载状态栏配置
require("config.largefile") -- 加载大文件配置
require("config.keymaps") -- 加载按键映射配置

-- 开启lsp-servers
vim.lsp.enable({ "lua_ls", "clangd", "taplo" })

-- 插件管理器：手动克隆 `mini.nvim` 插件并通过 `mini.deps` 管理
local path_package = vim.fn.stdpath("data") .. "/site/" -- 获取插件安装路径
local mini_path = path_package .. "pack/deps/start/mini.nvim" -- 定义 `mini.nvim` 插件路径

-- 如果 `mini.nvim` 插件未安装，则进行克隆
if not vim.loop.fs_stat(mini_path) then
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

-- 设置 `mini.deps` 插件的安装路径
require("mini.deps").setup({ path = { package = path_package } })

-- 加载 MiniDeps 插件
local MiniDeps = require("mini.deps")

-- `add`, `now`, 和 `later` 是 MiniDeps 插件的核心 API，直接赋值为全局变量
vim.g.add, vim.g.now, vim.g.later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- 将/opt/homebrew/opt/fzf 添加到 runtimepath 运行时
vim.opt.runtimepath:append("/opt/homebrew/opt/fzf")
