 -- lua/brickdag/init.lua
-- 插件主入口文件，负责初始化，加载模块及设置快捷键

local registry = require("brickdag.core.bricks_registry")
local loader = require("brickdag.core.brick_loader")
local task_loader = require("brickdag.core.task_loader")
local runner = require("brickdag.core.task_runner")
local task_queue = require("brickdag.core.task_queue")
local keymaps = require("brickdag.keymaps")

-- 默认的并行配置参数
local default_parallel_config = {
    enabled = true, -- 是否启用并行
    max_workers = 0, -- 最大工作线程数，0代表自动检测CPU核心数
    max_errors = 2, -- 最大容忍错误次数
    strategy = "balanced", -- 并行策略
    cpu_threshold = 80, -- CPU使用率阈值（百分比）
    mem_threshold = 90, -- 内存使用率阈值（百分比）
    resource_monitoring = true, -- 是否监控资源
}

local M = {
    _initialized = false, -- 是否已初始化
    parallel_config = vim.deepcopy(default_parallel_config), -- 当前并行配置（可被覆盖）
    runtime_tasks = {}, -- 运行时加载的任务模块
}

--- 插件初始化入口
--- @param opts table? 配置参数，可选
function M.setup(opts)
    opts = opts or {}

    -- 防止重复初始化
    if M._initialized then
        vim.notify("brickdag 已经初始化", vim.log.levels.WARN)
        return
    end

    -- 合并用户并行配置和默认配置
    if opts.parallel then
        M.parallel_config = vim.tbl_deep_extend("force", default_parallel_config, opts.parallel)
    end

    -- 清理之前的积木注册，避免冲突
    registry.clear()

    -- 加载所有积木模块 (先于任务加载)
    loader.load_all()

    -- 加载运行时指定的任务模块
    if opts.runtime_tasks then
        M.runtime_tasks = opts.runtime_tasks
        for _, task_module in ipairs(opts.runtime_tasks) do
            local ok, _ = pcall(require, task_module)
            if not ok then
                vim.notify("无法加载运行时任务模块: " .. task_module, vim.log.levels.WARN)
            end
        end
    end

    -- 通过拆分的keymap模块设置快捷键
    keymaps.setup_basic_keymaps(opts.keymaps, M)
    keymaps.setup_navigation_keymaps(opts.nav_keymaps or {}, M)

    -- 标记初始化完成
    M._initialized = true

    vim.notify("brickdag 初始化完成", vim.log.levels.INFO)
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
	-- 运行任务，传入回调函数处理成功/失败通知
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
--- @return table 并行配置表
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
--- @return table 新创建的任务对象
function M.create_task(name, task_type, config)
	local task = {
		name = name,
		type = task_type,
		[task_type] = config,
	}

	-- 添加到运行时任务集合中
	table.insert(M.runtime_tasks, task)
	return task
end

--- 检查插件是否已初始化
--- @return boolean
function M.is_initialized()
	return M._initialized
end

--- 获取当前任务队列中所有任务
--- @return table[] 任务列表
function M.get_queue()
	return task_queue.all()
end

--- 清空任务队列
function M.clear_queue()
	task_queue.clear()
end

--- 从任务队列中移除指定位置的任务
--- @param index integer 任务索引位置
function M.remove_from_queue(index)
	task_queue.remove(index)
end

--- 移动任务队列中的任务位置
--- @param index integer 当前任务索引
--- @param direction string "up" 或 "down"
function M.move_in_queue(index, direction)
	if direction == "up" then
		task_queue.move_up(index)
	elseif direction == "down" then
		task_queue.move_down(index)
	end
end

--- 运行任务队列中所有任务
function M.run_queue()
	local queue = M.get_queue()
	if #queue == 0 then
		vim.notify("任务队列为空", vim.log.levels.INFO)
		return
	end

	M.run_tasks(queue)
	-- 运行完毕后清空队列
	M.clear_queue()
end

--- 显示当前任务队列
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

	-- 使用 notify 显示队列内容，5秒后自动消失
	vim.notify(table.concat(content, "\n"), vim.log.levels.INFO, {
		title = "当前任务队列",
		timeout = 5000,
	})
end

return M
