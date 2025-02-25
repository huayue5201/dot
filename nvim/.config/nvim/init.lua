-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- 设置配色方案
-- vim.cmd("colorscheme dawn")

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 加载配置文件
require("config.settings") -- 全局设置
require("config.autocmds_and_commands") -- 自动命令和用户命令
require("config.statusline") -- 状态栏配置
require("config.keymaps") -- 按键映射

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

-- 工作区配置 (shada 文件)
vim.opt.exrc = true -- 启用 exrc 配置
vim.opt.secure = true -- 启用安全模式

-- 生成唯一的 shada 文件路径
local workspace_path = vim.fn.getcwd()
local data_dir = vim.fn.stdpath("data")
local unique_id = vim.fn.fnamemodify(workspace_path, ":t") .. "_" .. vim.fn.sha256(workspace_path):sub(1, 8)
local shadafile = data_dir .. "/shada/" .. unique_id .. ".shada"
vim.opt.shadafile = shadafile

-- 清理过期的 shada 文件 (超过 7 天)
local function cleanup_shada()
	local days_old = 7
	local current_time = os.time()
	local shada_files = vim.fn.glob(data_dir .. "/shada/*.shada", true, true)
	if #shada_files == 0 then
		return -- 没有 shada 文件，直接返回
	end
	for _, filename in ipairs(shada_files) do
		local file_time = vim.fn.getftime(filename)
		-- 处理文件时间错误
		if file_time == -1 then
			vim.notify("Unable to get file time for: " .. filename, vim.log.levels.WARN)
			return
		end

		local age_in_days = os.difftime(current_time, file_time) / (24 * 60 * 60)

		if age_in_days > days_old then
			local success, err = pcall(vim.fn.delete, filename) -- 安全删除文件
			if not success then
				vim.notify("Error deleting file: " .. filename .. " - " .. err, vim.log.levels.ERROR)
			else
				print("Deleted file: " .. filename)
			end
		end
	end
end
-- 设置定时器每隔一天清理一次 shada 文件
vim.defer_fn(function()
	cleanup_shada()
end, 86400) -- 86400 秒 = 1 天
