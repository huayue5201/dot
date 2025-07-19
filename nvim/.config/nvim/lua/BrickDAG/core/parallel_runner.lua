-- lua/brickdag/core/parallel_runner.lua
local uv = vim.loop
local StateMachine = require("brickdag.core.state_machine")

local M = {}

--- 获取系统资源信息
function M.get_system_resources()
	local cpu_info = uv.cpu_info()
	local logical_cores = #cpu_info
	return {
		logical_cores = logical_cores,
		free_memory = uv.get_free_memory(),
		total_memory = uv.get_total_memory(),
	}
end

--- 计算最佳并行任务数
--- @return integer
function M.calculate_optimal_workers()
	local config = require("brickdag").get_parallel_config()
	if config.max_workers > 0 then
		return config.max_workers
	end

	-- 自动检测最佳并行数
	local resources = M.get_system_resources()
	local safe_workers = math.max(1, resources.logical_cores - 1)
	return math.min(8, safe_workers)
end

--- 并行执行任务组
--- @param task_group table[] 任务列表 [{id, task}, ...]
--- @param executor table 任务执行器实例
--- @param context table 全局上下文
--- @param on_group_done function 任务组完成回调
function M.run_parallel(task_group, executor, context, on_group_done)
	local config = require("brickdag").get_parallel_config()
	local max_workers = M.calculate_optimal_workers()

	local running = 0
	local completed = 0
	local total = #task_group
	local errors = {}
	local is_cancelled = false

	-- 按优先级排序
	table.sort(task_group, function(a, b)
		return (a.task.priority or 5) > (b.task.priority or 5)
	end)

	-- 任务完成处理器
	local function task_completed(success, err)
		running = running - 1
		completed = completed + 1

		if not success then
			table.insert(errors, err)

			-- 错误熔断：达到最大错误数时取消所有任务
			if #errors >= config.max_errors then
				is_cancelled = true
				vim.notify("❌ 错误过多，已取消剩余任务", vim.log.levels.ERROR)
			end
		end

		-- 所有任务完成或取消
		if completed == total or is_cancelled then
			on_group_done(#errors == 0, errors)
		-- 还有任务待执行且未取消
		elseif not is_cancelled and running < max_workers then
			start_next()
		end
	end

	-- 启动下一个任务
	local function start_next()
		if #task_group == 0 then
			return
		end

		local task_info = table.remove(task_group, 1)
		running = running + 1

		-- 更新任务状态为运行中
		context:get_task_state(task_info.id):transition(StateMachine.STATE_RUNNING)

		-- 执行任务
		executor:execute_task(context, task_info.id, task_info.task, task_completed)
	end

	-- 在 run_parallel 函数中添加资源检查
	local function check_resources()
		if not config.resource_monitoring then
			return true
		end

		local loadavg = uv.loadavg()
		local mem_used = 1 - (uv.get_free_memory() / uv.get_total_memory())

		return loadavg[1] < config.cpu_threshold / 100 and mem_used < config.mem_threshold / 100
	end

	-- 资源检查
	for i = 1, math.min(max_workers, total) do
		if check_resources() then
			start_next()
		else
			-- 资源不足，降级为顺序执行
			vim.notify("⚠️ 系统资源紧张，降级为顺序执行", vim.log.levels.WARN)
			max_workers = 1
			break
		end
	end
end

return M
