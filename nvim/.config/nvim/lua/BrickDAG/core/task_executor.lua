-- core/task_executor.lua
local Executor = {}
Executor.__index = Executor

local StateMachine = require("BrickDAG.core.state_machine")
local BricksRegistry = require("BrickDAG.core.bricks_registry")

--- 创建新的执行器实例
--- @param services table? 依赖服务
--- @return Executor
function Executor.new(services)
	local self = setmetatable({}, Executor)
	self.state_machine = StateMachine.new()

	-- 默认服务
	self.services = services
		or {
			resolver = require("BrickDAG.core.value_resolver"),
			logger = function(msg, level)
				vim.notify("[Executor] " .. msg, level or vim.log.levels.INFO)
			end,
		}

	return self
end

-- 执行任务的核心方法
--- @param context table 执行上下文
--- @param task_id string 任务ID
--- @param task table 任务配置
--- @return boolean success
--- @return string? error_message
function Executor:execute_task(context, task_id, task)
	-- 调试日志：开始执行任务
	self.services.logger(string.format("开始执行任务: %s (%s)", task_id, task.type), vim.log.levels.DEBUG)

	-- 1. 检查任务依赖是否完成
	if not self:check_dependencies(context, task_id, task) then
		local missing_deps = {}
		if task.deps then
			for _, dep_id in ipairs(task.deps) do
				if not context.completed_tasks[dep_id] then
					table.insert(missing_deps, dep_id)
				end
			end
		end
		local err_msg = "未完成所有依赖任务: " .. table.concat(missing_deps, ", ")
		context:mark_failed(task_id, err_msg)
		self.services.logger(err_msg, vim.log.levels.WARN)
		return false, err_msg
	end

	-- 2. 更新状态为运行中
	local success, err = self.state_machine:transition(StateMachine.STATE_RUNNING)
	if not success then
		context:mark_failed(task_id, "状态转换失败: " .. err)
		return false, "状态转换失败: " .. err
	end

	-- 3. 获取任务类型对应的框架积木
	local framework = BricksRegistry.get_frame(task.type)
	if not framework then
		context:mark_failed(task_id, "找不到框架: " .. task.type)
		return false, "框架未注册: " .. task.type
	end

	-- 4. 获取框架专用配置
	local frame_config = task[task.type]
	if not frame_config then
		context:mark_failed(task_id, "缺少框架配置")
		return false, "缺少框架配置"
	end

	-- 5. 创建执行上下文
	local exec_context = {
		config = frame_config,
		task_id = task_id,
		task = task,
		services = self.services,
		global_context = context,
	}

	-- 6. 执行框架
	local ok, success, result = pcall(framework.execute, exec_context)
	if not ok then
		-- 框架执行抛出了异常
		context:mark_failed(task_id, "框架执行错误: " .. tostring(success))
		return false, "框架执行错误: " .. tostring(success)
	end

	-- 7. 处理执行结果
	if success then
		context:mark_completed(task_id)
		self.state_machine:transition(StateMachine.STATE_SUCCESS)
		return true
	else
		local err_msg = result or "未知错误"
		context:mark_failed(task_id, err_msg)
		self.state_machine:transition(StateMachine.STATE_FAILED)
		return false, err_msg
	end
end

-- 检查任务依赖
--- @param context table 执行上下文
--- @param task_id string 任务ID
--- @param task table 任务配置
--- @return boolean
function Executor:check_dependencies(context, task_id, task)
	if not task.deps or #task.deps == 0 then
		return true
	end

	for _, dep_id in ipairs(task.deps) do
		if not context.completed_tasks[dep_id] then
			return false
		end
	end

	return true
end

return Executor
