-- 引用 Neovim 官方文档和操作手册链接
-- https://github.com/neovim/neovim
-- https://github.com/neovim/neovim/releases/
-- https://vim.rtorr.com/lang/zh_cn vim 操作手册

-- 启用 Lua 加载器以提高启动速度
vim.loader.enable()

-- 设置配色方案
vim.cmd("colorscheme dawn")

-- 设置前置按键为空格键
vim.g.mapleader = vim.keycode("<space>") -- 设置 Leader 键为空格
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true }) -- 禁用空格键默认的功能

-- 插件管理器：手动克隆 `mini.nvim` 插件并通过 `mini.deps` 管理
local path_package = vim.fn.stdpath("data") .. "/site/" -- 获取插件安装路径
local mini_path = path_package .. "pack/deps/start/mini.nvim" -- 定义 `mini.nvim` 插件路径

-- 如果 `mini.nvim` 插件未安装，则进行克隆
if not vim.loop.fs_stat(mini_path) then
	vim.cmd('echo "Installing `mini.nvim`" | redraw') -- 显示安装信息
	local clone_cmd = {
		"git",
		"clone",
		"--filter=blob:none", -- 只克隆所需的文件
		"https://github.com/echasnovski/mini.nvim", -- 插件的 GitHub 地址
		mini_path, -- 插件安装路径
	}
	vim.fn.system(clone_cmd) -- 执行克隆命令
	vim.cmd("packadd mini.nvim | helptags ALL") -- 加载插件并生成帮助标签
	vim.cmd('echo "Installed `mini.nvim`" | redraw') -- 显示安装完成信息
end

-- 设置 `mini.deps` 插件的安装路径
require("mini.deps").setup({ path = { package = path_package } })

-- 加载 MiniDeps 插件
local MiniDeps = require("mini.deps")

-- 将 `add`、`now` 和 `later` 设置为全局变量，方便后续使用
vim.g.add, vim.g.now, vim.g.later = MiniDeps.add, MiniDeps.now, MiniDeps.later

-- 加载配置目录下的所有插件配置文件
local plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins"
for _, plugin in ipairs(vim.fn.readdir(plugin_dir)) do
	local plugin_file = plugin_dir .. "/" .. plugin
	if plugin:match("%.lua$") then -- 仅加载 `.lua` 后缀的文件
		dofile(plugin_file) -- 执行插件配置文件
	end
end
