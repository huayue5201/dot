-- https://github.com/neovim/neovim
-- https://github.com/neovim/neovim/releases/
-- https://vim.rtorr.com/lang/zh_cn vim 操作手册
-- 启用 Lua 加载器以提高启动速度
vim.loader.enable()

-- colorscheme 设置
vim.cmd("colorscheme dawn")

-- 设置前置按键
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 模块列表
local modules = {
	"statusline", -- 自定义状态栏
}
-- 加载模块
for _, module in ipairs(modules) do
	local ok, module_func = pcall(require, module)
	if ok and type(module_func) == "function" then
		module_func()
	elseif not ok then
		print("加载", module, "时发生错误:", module_func)
	end
end

-- 插件管理器
-- Clone 'mini.nvim' manually in a way that it gets managed by 'mini.deps'
local path_package = vim.fn.stdpath("data") .. "/site/"
local mini_path = path_package .. "pack/deps/start/mini.nvim"
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

-- Set up 'mini.deps' (customize to your liking)
require("mini.deps").setup({ path = { package = path_package } })

-- 加载 MiniDeps
local MiniDeps = require("mini.deps")

-- 将 `add` 和 `later` 设置为全局变量
vim.g.add = MiniDeps.add
vim.g.now = MiniDeps.now
vim.g.later = MiniDeps.later

local plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins"
for _, plugin in ipairs(vim.fn.readdir(plugin_dir)) do
	local plugin_file = plugin_dir .. "/" .. plugin
	if plugin:match("%.lua$") then
		dofile(plugin_file)
	end
end
