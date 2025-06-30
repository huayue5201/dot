local TaskExecutor = {}
TaskExecutor.__index = TaskExecutor

function TaskExecutor:new(state_machine, repository, manager)
	return setmetatable({
		state_machine = state_machine,
		repository = repository,
		manager = manager,
		queue = {},
		output_buffer = {},
		current_task = nil,
		start_time = nil,
		timeout_timer = nil,
	}, self)
end

function TaskExecutor:run_task(task)
	if self.state_machine.state == "idle" then
		if self.state_machine:start(task) then
			return self:execute_task(task)
		end
		return false
	end

	table.insert(self.queue, task)
	return true
end

function TaskExecutor:execute_task(task)
	self.current_task = task
	self.start_time = os.time()

	local cmd = task.cmd
	if type(cmd) == "function" then
		cmd = cmd(task.params)
	end

	if not cmd or #cmd == 0 then
		self.state_machine:fail()
		return false
	end

	-- 准备环境变量
	local env = {}
	if task.env then
		for k, v in pairs(task.env) do
			env[k] = tostring(v)
		end
	end

	if self.manager.global_env then
		for k, v in pairs(self.manager.global_env) do
			if env[k] == nil then
				env[k] = tostring(v)
			end
		end
	end

	self.output_buffer = {}

	-- 设置超时
	if task.timeout and task.timeout > 0 then
		self:start_timeout_timer(task.timeout)
	end

	local job_opts = {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data)
			self:handle_output(data, false, task)
		end,
		on_stderr = function(_, data)
			self:handle_output(data, true, task)
		end,
		on_exit = function(_, code)
			self:handle_exit(code, task)
		end,
		env = env,
	}

	self.state_machine.job_id = vim.fn.jobstart(cmd, job_opts)

	if self.state_machine.job_id <= 0 then
		vim.notify("无法启动任务: " .. task.id, vim.log.levels.ERROR)
		self.state_machine:fail()
		return false
	end

	-- 通知任务开始
	if self.manager.notification then
		self.manager.notification.task_started(task)
	end

	return true
end

function TaskExecutor:start_timeout_timer(timeout_seconds)
	if self.timeout_timer then
		self.timeout_timer:stop()
		self.timeout_timer:close()
	end

	self.timeout_timer = vim.loop.new_timer()
	self.timeout_timer:start(
		timeout_seconds * 1000,
		0,
		vim.schedule_wrap(function()
			if self.state_machine.state == "running" then
				vim.fn.jobstop(self.state_machine.job_id)
				self.state_machine:fail()
				if self.current_task and self.current_task.on_timeout then
					self.current_task.on_timeout()
				end
				vim.notify("任务超时: " .. self.current_task.id, vim.log.levels.ERROR)
			end
		end)
	)
end

function TaskExecutor:handle_output(data, is_error, task)
	if not data then
		return
	end

	for _, line in ipairs(data) do
		if line ~= "" then
			table.insert(self.state_machine.output, line)
			table.insert(self.output_buffer, line)
		end
	end

	if task.on_output then
		task.on_output(data, is_error)
	end
end

function TaskExecutor:handle_exit(code, task)
	if self.timeout_timer then
		self.timeout_timer:stop()
		self.timeout_timer:close()
		self.timeout_timer = nil
	end

	local output = vim.deepcopy(self.output_buffer)
	local duration = os.difftime(os.time(), self.start_time)

	if code == 0 then
		self.state_machine:complete()
		if task.on_complete then
			task.on_complete(output)
		end
		-- 通知任务完成
		if self.manager.notification then
			self.manager.notification.task_completed(task, duration)
		end
	else
		self.state_machine:fail()
		if task.on_fail then
			task.on_fail(output)
		end
		-- 通知任务失败
		if self.manager.notification then
			self.manager.notification.task_failed(task, duration)
		end
	end

	-- 添加历史记录
	if self.manager and self.manager.queue then
		self.manager.queue:add_to_history(
			self.manager.current_task,
			code == 0 and "completed" or "failed",
			output,
			duration
		)
	end

	self.state_machine:reset()
	self:run_next_task()
end

function TaskExecutor:run_next_task()
	if #self.queue > 0 then
		local next_task = table.remove(self.queue, 1)
		self:run_task(next_task)
	end
end

function TaskExecutor:cancel_current()
	if self.timeout_timer then
		self.timeout_timer:stop()
		self.timeout_timer:close()
		self.timeout_timer = nil
	end
	return self.state_machine:cancel()
end

return TaskExecutor
