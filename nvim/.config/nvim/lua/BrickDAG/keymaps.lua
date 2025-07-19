-- lua/brickdag/keymaps.lua
-- 负责定义全局快捷键映射，拆分出入口文件保持简洁

local ui = require("brickdag.ui.init")

local M = {}

--- 设置基本任务快捷键映射
--- @param keymaps table? 自定义快捷键表
--- @param brickdag table 插件主模块（用于调用相关接口）
function M.setup_basic_keymaps(keymaps, brickdag)
	-- 默认快捷键定义
	local default_keymaps = {
		enqueue_task = "<leader>ta", -- 添加任务到队列
		run_task = "<leader>tr", -- 运行单个任务
		show_queue = "<leader>tq", -- 显示任务队列
	}

	-- 合并默认和用户自定义快捷键
	local km = vim.tbl_extend("force", default_keymaps, keymaps or {})

	-- 映射：添加任务到队列
	vim.keymap.set("n", km.enqueue_task, function()
		brickdag.pick_and_enqueue_task()
	end, { desc = "添加任务到队列" })

	-- 映射：选择并运行任务
	vim.keymap.set("n", km.run_task, function()
		brickdag.pick_and_run_task()
	end, { desc = "选择并运行任务" })

	-- 映射：显示当前任务队列
	vim.keymap.set("n", km.show_queue, function()
		brickdag.show_task_queue()
	end, { desc = "显示任务队列" })
end

--- 设置任务导航相关的快捷键映射
--- @param keymaps table? 自定义导航键位表
--- @param brickdag table 插件主模块（一般传nil或不使用）
function M.setup_navigation_keymaps(keymaps, brickdag)
	-- 默认导航快捷键定义
	local default_keymaps = {
		open_nav = "<leader>tn", -- 打开任务导航窗口
		close_nav = "<leader>tc", -- 关闭任务导航窗口
		nav_back = "h", -- 返回上层目录
		nav_enter = "l", -- 进入依赖层级
		nav_up = "k", -- 上移选择
		nav_down = "j", -- 下移选择
	}

	-- 合并默认和用户自定义快捷键
	local km = vim.tbl_extend("force", default_keymaps, keymaps or {})

	-- 映射：打开任务导航（调用ui层）
	vim.keymap.set("n", km.open_nav, function()
		ui.show_all_tasks()
	end, { desc = "打开任务导航" })

	-- 映射：关闭任务导航
	vim.keymap.set("n", km.close_nav, function()
		ui.close_navigation()
	end, { desc = "关闭任务导航" })

	-- 映射：返回上层（左移）
	vim.keymap.set("n", km.nav_back, function()
		if ui.is_in_navigation() then
			ui.navigate_back()
			return "" -- 阻止键盘默认行为
		end
		return "h" -- 非导航窗口时保留原功能
	end, { desc = "任务导航返回", expr = true, noremap = true })

	-- 映射：进入依赖（右移）
	vim.keymap.set("n", km.nav_enter, function()
		if ui.is_in_navigation() then
			ui.navigate_into()
			return ""
		end
		return "l"
	end, { desc = "任务导航进入", expr = true, noremap = true })

	-- 映射：选择上移
	vim.keymap.set("n", km.nav_up, function()
		if ui.is_in_navigation() then
			ui.navigate_selection(-1)
			return ""
		end
		return "k"
	end, { desc = "任务导航上移", expr = true, noremap = true })

	-- 映射：选择下移
	vim.keymap.set("n", km.nav_down, function()
		if ui.is_in_navigation() then
			ui.navigate_selection(1)
			return ""
		end
		return "j"
	end, { desc = "任务导航下移", expr = true, noremap = true })
end

return M
