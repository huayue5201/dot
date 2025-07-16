local registry = require("BrickDAG.core.bricks_registry")
local loader = require("BrickDAG.core.brick_loader")
local task_loader = require("BrickDAG.core.task_loader")
local runner = require("BrickDAG.core.task_runner")
local task_queue = require("BrickDAG.core.task_queue")
local ui = require("BrickDAG.ui.init") -- 引入UI模块

-- 默认并行配置
local default_parallel_config = {
	enabled = true,
	max_workers = 0, -- 0 = 自动检测
	max_errors = 2,
	strategy = "balanced",
	cpu_threshold = 80,
	mem_threshold = 90,
	resource_monitoring = true,
}

local M = {
	-- 配置状态
	_initialized = false,
	parallel_config = vim.deepcopy(default_parallel_config),

	-- 运行时任务模块
	runtime_tasks = {},
}

--- 设置任务系统
--- @param opts table? 配置选项
function M.setup(opts)
	opts = opts or {}

	-- 只初始化一次
	if M._initialized then
		vim.notify("BrickDAG 已经初始化", vim.log.levels.WARN)
		return
	end

	-- 合并并行配置
	if opts.parallel then
		M.parallel_config = vim.tbl_deep_extend("force", default_parallel_config, opts.parallel)
	end

	-- 清除之前的注册
	registry.clear()

	-- 加载所有积木
	loader.load_all()

	-- 加载运行时任务模块
	if opts.runtime_tasks then
		M.runtime_tasks = opts.runtime_tasks
		for _, task_module in ipairs(opts.runtime_tasks) do
			local ok, _ = pcall(require, task_module)
			if not ok then
				vim.notify("无法加载运行时任务模块: " .. task_module, vim.log.levels.WARN)
			end
		end
	end

	-- 设置基本快捷键映射
	M.setup_basic_keymaps(opts.keymaps)

	-- 添加全局导航快捷键
	M.setup_navigation_keymaps(opts.nav_keymaps or {})

	-- 标记已初始化
	M._initialized = true

	vim.notify("BrickDAG 初始化完成", vim.log.levels.INFO)
end

--- 设置基本快捷键映射
--- @param keymaps table? 自定义键位映射
function M.setup_basic_keymaps(keymaps)
	local default_keymaps = {
		enqueue_task = "<leader>ta", -- 添加任务到队列
		run_task = "<leader>tr", -- 运行单个任务
		show_queue = "<leader>tq", -- 显示任务队列
	}

	local km = vim.tbl_extend("force", default_keymaps, keymaps or {})

	-- 添加任务到队列的映射
	vim.keymap.set("n", km.enqueue_task, function()
		M.pick_and_enqueue_task()
	end, { desc = "添加任务到队列" })

	-- 运行单个任务的映射
	vim.keymap.set("n", km.run_task, function()
		M.pick_and_run_task()
	end, { desc = "选择并运行任务" })

	-- 显示任务队列
	vim.keymap.set("n", km.show_queue, function()
		M.show_task_queue()
	end, { desc = "显示任务队列" })
end

--- 设置导航快捷键映射
--- @param keymaps table? 自定义导航键位
function M.setup_navigation_keymaps(keymaps)
	local default_keymaps = {
		open_nav = "<leader>tn", -- 打开任务导航
		close_nav = "<leader>tc", -- 关闭任务导航
		nav_back = "h", -- ← 返回上层
		nav_enter = "l", -- → 进入依赖
		nav_up = "k", -- ↑ 上移
		nav_down = "j", -- ↓ 下移
	}

	local km = vim.tbl_extend("force", default_keymaps, keymaps or {})

	-- 打开任务导航
	vim.keymap.set("n", km.open_nav, function()
		ui.show_all_tasks()
	end, { desc = "打开任务导航" })

	-- 关闭任务导航
	vim.keymap.set("n", km.close_nav, function()
		ui.close_navigation()
	end, { desc = "关闭任务导航" })

	-- 返回上层（左移）
	vim.keymap.set("n", km.nav_back, function()
		if ui.is_in_navigation() then
			ui.navigate_back()
			return ""
		end
		return "h"
	end, { desc = "任务导航返回", expr = true, noremap = true })

	-- 进入依赖（右移）
	vim.keymap.set("n", km.nav_enter, function()
		if ui.is_in_navigation() then
			ui.navigate_into()
			return ""
		end
		return "l"
	end, { desc = "任务导航进入", expr = true, noremap = true })

	-- 上移选择
	vim.keymap.set("n", km.nav_up, function()
		if ui.is_in_navigation() then
			ui.navigate_selection(-1)
			return ""
		end
		return "k"
	end, { desc = "任务导航上移", expr = true, noremap = true })

	-- 下移选择
	vim.keymap.set("n", km.nav_down, function()
		if ui.is_in_navigation() then
			ui.navigate_selection(1)
			return ""
		end
		return "j"
	end, { desc = "任务导航下移", expr = true, noremap = true })
end

--- 选择任务并加入队列
function M.pick_and_enqueue_task()
	local tasks = M.get_available_tasks()

	if #tasks == 0 then
		vim.notify("没有可用的任务", vim.log.levels.INFO)
		return
	end

	vim.ui.select(tasks, {
		prompt = "选择要加入队列的任务:",
		format_item = function(task)
			return task.name
		end,
	}, function(selected)
		if selected then
			M.add_to_queue(selected)
		end
	end)
end

--- 选择任务并运行
function M.pick_and_run_task()
	local tasks = M.get_available_tasks()

	if #tasks == 0 then
		vim.notify("没有可用的任务", vim.log.levels.INFO)
		return
	end

	vim.ui.select(tasks, {
		prompt = "选择要运行的任务:",
		format_item = function(task)
			return task.name
		end,
	}, function(selected)
		if selected then
			M.run_task(selected)
		end
	end)
end

--- 运行单个任务
--- @param task table 任务对象
function M.run_task(task)
	-- 运行任务
	runner.run({ task }, function(success, err)
		if success then
			vim.notify("✅ 任务完成: " .. task.name, vim.log.levels.INFO)
		else
			vim.notify("❌ 任务失败: " .. task.name .. "\n" .. (err or ""), vim.log.levels.ERROR)
		end
	end)
end

--- 运行多个任务
--- @param tasks table[] 任务列表
function M.run_tasks(tasks)
	runner.run(tasks, function(success, err)
		if success then
			vim.notify("✅ 所有任务完成", vim.log.levels.INFO)
		else
			vim.notify("❌ 任务执行失败: " .. (err or ""), vim.log.levels.ERROR)
		end
	end)
end

--- 获取所有可用任务
--- @return table[] 任务列表
function M.get_available_tasks()
	return task_loader.load_tasks()
end

--- 获取并行配置
--- @return table 并行配置
function M.get_parallel_config()
	return M.parallel_config
end

--- 添加自定义积木
--- @param brick_type string "base" 或 "frame"
--- @param brick_def table 积木定义
function M.register_brick(brick_type, brick_def)
	if brick_type == "base" then
		registry.runtime_register_base_brick(brick_def)
	elseif brick_type == "frame" then
		registry.runtime_register_frame_brick(brick_def)
	end
end

--- 添加任务到队列
--- @param task table 任务对象
function M.add_to_queue(task)
	task_queue.enqueue(task)
	vim.notify("已添加到队列: " .. task.name)
end

--- 创建简单任务
--- @param name string 任务名称
--- @param task_type string 任务类型
--- @param config table 任务配置
function M.create_task(name, task_type, config)
	local task = {
		name = name,
		type = task_type,
		[task_type] = config,
	}

	-- 添加到运行时任务
	table.insert(M.runtime_tasks, task)
	return task
end

--- 检查是否已初始化
--- @return boolean
function M.is_initialized()
	return M._initialized
end

--- 获取任务队列
--- @return table[] 当前队列中的所有任务
function M.get_queue()
	return task_queue.all()
end

--- 清空任务队列
function M.clear_queue()
	task_queue.clear()
end

--- 移除队列中的任务
--- @param index integer 任务在队列中的位置
function M.remove_from_queue(index)
	task_queue.remove(index)
end

--- 移动队列中的任务
--- @param index integer 任务位置
--- @param direction string "up" 或 "down"
function M.move_in_queue(index, direction)
	if direction == "up" then
		task_queue.move_up(index)
	elseif direction == "down" then
		task_queue.move_down(index)
	end
end

--- 运行队列中的所有任务
function M.run_queue()
	local queue = M.get_queue()
	if #queue == 0 then
		vim.notify("任务队列为空", vim.log.levels.INFO)
		return
	end

	M.run_tasks(queue)
	M.clear_queue()
end

--- 显示任务队列
function M.show_task_queue()
	local queue = M.get_queue()
	if #queue == 0 then
		vim.notify("任务队列为空", vim.log.levels.INFO)
		return
	end

	local content = { "📋 任务队列:", "" }
	for i, task in ipairs(queue) do
		table.insert(content, string.format("[%d] %s", i, task.name))
	end

	vim.notify(table.concat(content, "\n"), vim.log.levels.INFO, {
		title = "当前任务队列",
		timeout = 5000,
	})
end

return M
