-- core/execution_context.lua
local StateMachine = require("BrickDAG.core.state_machine")

--- @class Context
--- @field dag table 任务DAG图对象
--- @field completed_tasks table<string, boolean> 标记哪些任务已完成
--- @field failed_tasks table<string, string> 标记失败的任务和错误信息
--- @field vars table<string, any> 任务间共享变量
--- @field task_states table<string, StateMachine> 每个任务的状态机
local Context = {}
Context.__index = Context

--- 创建新的上下文对象
--- @param dag table DAG对象
--- @return Context
function Context.new(dag)
	local self = setmetatable({}, Context)
	self.dag = dag
	self.completed_tasks = {} -- 已完成的任务
	self.failed_tasks = {} -- 失败任务及错误信息
	self.vars = {} -- 上下文变量容器
	self.task_states = {} -- 每个任务的状态机
	return self
end

--- 标记某个任务已成功完成
--- @param task_id string
function Context:mark_completed(task_id)
	self.completed_tasks[task_id] = true
	self:get_task_state(task_id):transition(StateMachine.STATE_SUCCESS)
end

--- 标记某个任务失败
--- @param task_id string
--- @param err string
function Context:mark_failed(task_id, err)
	self.failed_tasks[task_id] = err
	self:get_task_state(task_id):transition(StateMachine.STATE_FAILED)
end

--- 判断是否存在失败任务
--- @return boolean
function Context:is_failed()
	return next(self.failed_tasks) ~= nil
end

--- 获取失败任务及错误信息
--- @return table<string, string>
function Context:get_failed_tasks()
	return self.failed_tasks
end

--- 设置上下文变量（供任务间共享数据）
--- @param key string
--- @param value any
function Context:set_var(key, value)
	self.vars[key] = value
end

--- 获取上下文变量
--- @param key string
--- @return any
function Context:get_var(key)
	return self.vars[key]
end

--- 获取某个任务的状态机（如不存在则自动创建）
--- @param task_id string
--- @return StateMachine
function Context:get_task_state(task_id)
	if not self.task_states[task_id] then
		self.task_states[task_id] = StateMachine.new()
	end
	return self.task_states[task_id]
end

return Context
