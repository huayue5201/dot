-- 任务状态机 (task_state_machine.lua)

local TaskState = {
	IDLE = "idle",
	RUNNING = "running",
	COMPLETED = "completed",
	FAILED = "failed",
	CANCELLED = "cancelled",
}

local TaskStateMachine = {}
TaskStateMachine.__index = TaskStateMachine

function TaskStateMachine:new()
	return setmetatable({
		state = TaskState.IDLE,
		job_id = nil,
		task = nil,
		output = {},
	}, self)
end

function TaskStateMachine:start(task)
	if self.state ~= TaskState.IDLE then
		return false
	end
	self.state = TaskState.RUNNING
	self.task = task
	self.output = {}
	return true
end

function TaskStateMachine:complete()
	if self.state == TaskState.RUNNING then
		self.state = TaskState.COMPLETED
		return true
	end
	return false
end

function TaskStateMachine:fail()
	if self.state == TaskState.RUNNING then
		self.state = TaskState.FAILED
		return true
	end
	return false
end

function TaskStateMachine:cancel()
	if self.state == TaskState.RUNNING then
		if self.job_id then
			vim.fn.jobstop(self.job_id)
		end
		self.state = TaskState.CANCELLED
		return true
	end
	return false
end

function TaskStateMachine:reset()
	self.state = TaskState.IDLE
	self.job_id = nil
	self.task = nil
	self.output = {}
end

return TaskStateMachine
