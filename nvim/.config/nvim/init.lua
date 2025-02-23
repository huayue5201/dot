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

-- -------------- 工作区配置 (`shada` 文件) --------------
vim.opt.exrc = true -- 启用 exrc 配置，允许在当前工作目录加载配置文件
vim.opt.secure = true -- 启用安全模式，防止加载不安全的配置文件
local workspace_path = vim.fn.getcwd() -- 当前工作目录路径
local data_dir = vim.fn.stdpath("data") -- 缓存目录路径
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") .. "_" .. vim.fn.sha256(workspace_path):sub(1, 8) -- 生成唯一 ID
local shadafile = data_dir .. "/shada/" .. unique_id .. ".shada" -- 设置 `shada` 文件路径
vim.opt.shadafile = shadafile -- 设置 `shada` 文件路径
-- 删除超过 7 天的 `shada` 文件
local function cleanup_shada()
	local days_old = 7
	local current_time = os.time()
	local shada_files = vim.fn.glob(data_dir .. "/shada/*.shada", true, true)
	if #shada_files == 0 then
		print("No shada files found.")
		return
	end
	for _, filename in ipairs(shada_files) do
		local file_time = vim.fn.getftime(filename)
		if file_time ~= -1 then
			local age_in_days = os.difftime(current_time, file_time) / (24 * 60 * 60)
			if age_in_days > days_old then
				vim.fn.delete(filename) -- 删除过期文件
				print("Deleted file: " .. filename)
			end
		else
			print("Unable to get file time for: " .. filename)
		end
	end
end
-- 设置定时器每隔一天运行一次清理操作
vim.defer_fn(function()
	cleanup_shada()
end, 86400) -- 86400 秒 = 1 天
