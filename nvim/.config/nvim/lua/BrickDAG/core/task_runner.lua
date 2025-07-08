-- core/task_runner.lua
local TaskDAG = require("BrickDAG.core.task_dag")
local Context = require("BrickDAG.core.context")
local Executor = require("BrickDAG.core.task_executor")

local M = {}

-- 运行任务的核心方法
--- @param tasks table|table[] 任务或任务列表
--- @param on_done fun(success: boolean, err?: string) 执行完成回调
--- @param services table? 依赖服务
--- @return boolean 启动成功
function M.run(tasks, on_done, services)
	-- 参数验证
	if not on_done or type(on_done) ~= "function" then
		vim.notify("必须提供on_done回调函数", vim.log.levels.ERROR)
		return false
	end

	-- 确保tasks是列表
	if not vim.isarray(tasks) then
		tasks = { tasks }
	end

	-- 创建DAG
	local dag = TaskDAG.new()
	for _, task in ipairs(tasks) do
		dag:add_task(task)
	end

	-- 创建执行上下文
	local context = Context.new(dag)

	-- 创建执行器（注入服务）
	local executor = Executor.new(services)

	-- 获取拓扑排序
	local sorted_ids
	local ok, err = pcall(function()
		sorted_ids = dag:topo_sort()
	end)

	if not ok then
		on_done(false, "拓扑排序失败: " .. tostring(err))
		return false
	end

	-- 任务执行索引
	local index = 1

	-- 递归执行下一个任务
	local function run_next()
		if index > #sorted_ids then
			-- 所有任务完成
			if context:is_failed() then
				local errors = {}
				for task_id, err_msg in pairs(context.failed_tasks) do
					local task = dag:get_task(task_id)
					table.insert(errors, string.format("%s (%s): %s", task.name, task.type, err_msg))
				end
				on_done(false, "部分任务失败:\n" .. table.concat(errors, "\n"))
			else
				on_done(true, "所有任务成功完成")
			end
			return
		end

		local task_id = sorted_ids[index]
		local task = dag.nodes[task_id]

		if not task then
			on_done(false, "找不到任务: " .. task_id)
			return
		end

		-- 执行当前任务
		local success, err = executor:execute_task(context, task_id, task)

		-- 更新索引
		index = index + 1

		-- 无论成功失败都继续执行
		vim.schedule(run_next)
	end

	-- 开始执行
	vim.schedule(run_next)

	return true
end

return M
