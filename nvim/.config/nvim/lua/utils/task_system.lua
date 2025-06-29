local M = {}

-- ======= 内部函数 =======
local cached_tasks = {}

-- 添加内容到 QuickFix
local function append_to_qf(data)
	if not data or #data == 0 then
		return
	end

	-- 过滤空行
	local lines = {}
	for _, line in ipairs(data) do
		if line ~= "" then
			table.insert(lines, line)
		end
	end

	if #lines == 0 then
		return
	end

	local qf_exists = false
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local buf = vim.api.nvim_win_get_buf(win)
		if vim.api.nvim_get_option_value("buftype", { buf = buf }) == "quickfix" then
			vim.fn.setqflist({}, "a", { lines = lines })
			-- 自动滚动到底部
			local line_count = vim.api.nvim_buf_line_count(buf)
			vim.api.nvim_win_set_cursor(win, { line_count, 0 })
			qf_exists = true
			break
		end
	end

	if not qf_exists then
		vim.fn.setqflist({}, "a", { lines = lines })
		vim.cmd("copen")
	end
end

-- 验证任务是否有效
local function is_valid_task(task)
	-- 单步任务验证
	if task.cmd then
		return true
	end

	-- 多步任务验证
	if task.steps and #task.steps > 0 then
		for _, step in ipairs(task.steps) do
			if step.cmd then
				return true
			end
		end
	end

	return false
end

local function load_tasks_from_dir(dir)
	if cached_tasks[dir] then
		return cached_tasks[dir]
	end

	local task_list = {}
	local task_path = vim.fn.stdpath("config") .. "/lua/" .. dir
	local handle = vim.loop.fs_scandir(task_path)

	if not handle then
		vim.notify("任务目录未找到: " .. task_path, vim.log.levels.ERROR)
		return {}
	end

	while true do
		local name, t = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end

		if t == "file" and name:match("%.lua$") then
			local mod_name = dir:gsub("/", ".") .. "." .. name:gsub("%.lua$", "")
			local ok, task = pcall(require, mod_name)

			if ok and type(task) == "table" then
				-- 使用增强的验证函数
				if not is_valid_task(task) then
					vim.notify("任务缺少有效的cmd或steps: " .. mod_name, vim.log.levels.ERROR)
				else
					-- 设置默认标签
					task.label = task.label or name:gsub("%.lua$", "")
					table.insert(task_list, task)
				end
			else
				vim.notify("加载任务失败: " .. mod_name, vim.log.levels.ERROR)
			end
		end
	end

	cached_tasks[dir] = task_list
	return task_list
end

local project_types = {
	make = { "Makefile" },
	cargo = { "Cargo.toml" },
	python = { "setup.py", "requirements.txt", "pyproject.toml" },
	node = { "package.json" },
	go = { "go.mod" },
	cmake = { "CMakeLists.txt" },
	rust = { "Cargo.toml" },
}

local function detect_project_type()
	local cwd = vim.fn.getcwd()
	for project_type, files in pairs(project_types) do
		for _, file in ipairs(files) do
			local path = cwd .. "/" .. file
			if vim.loop.fs_stat(path) then
				return project_type
			end
		end
	end
	return "unknown"
end

local function setup_errorformat(project_type)
	local formats = {
		make = " %f:%l:%c: %t%*[^:]: %m,%E%f:%l:%c: %t%*[^:]: %m,%C%.%#,%Z",
		cargo = " %f:%l:%c: %m,%Eerror: %m,%C%.%#,%Z",
		python = "%f:%l: %m,%C%.%#,%Z",
		node = "%f:%l:%c: %m,%C%.%#,%Z",
		rust = "%f:%l:%c: %m,%C%.%#,%Z",
		go = "%f:%l:%c: %m,%C%.%#,%Z",
	}

	vim.opt_local.errorformat = formats[project_type] or "%f:%l:%c: %m"
end

-- ======= 状态机实现 =======
local TaskState = {
	IDLE = "idle",
	RUNNING = "running",
	COMPLETED = "completed",
	FAILED = "failed",
}

local TaskFSM = {}
TaskFSM.__index = TaskFSM

function TaskFSM:new()
	local o = {
		state = TaskState.IDLE,
		job_id = nil,
		output_buffer = {},
		task = nil,
		on_complete = nil,
		on_fail = nil,
		current_step = 1, -- 当前执行的任务步骤
		step_results = {}, -- 存储每个步骤的输出
	}
	setmetatable(o, self)
	return o
end

function TaskFSM:transition(new_state)
	if self.state == new_state then
		return
	end

	local handlers = {
		[TaskState.RUNNING] = function()
			self.state = TaskState.RUNNING

			-- 检查是否有多个步骤
			if self.task.steps and #self.task.steps > 0 then
				append_to_qf({ ">>> 开始步骤 1: " .. self.task.steps[1].label })
				self:run_current_step()
			else
				-- 单个任务
				local cmd = self.task.cmd
				if type(cmd) == "function" then
					cmd = cmd()
				end

				-- 验证命令是否有效
				if not cmd or #cmd == 0 then
					vim.notify("任务命令为空", vim.log.levels.ERROR)
					self:transition(TaskState.FAILED)
					return
				end

				self.job_id = M.start_job(cmd, {
					on_stdout = function(_, data)
						self:handle_output(data)
						append_to_qf(data)
					end,
					on_stderr = function(_, data)
						self:handle_output(data)
						append_to_qf(data)
					end,
					on_exit = function(_, code)
						self:handle_exit(code)
					end,
				})
			end
		end,

		[TaskState.COMPLETED] = function()
			self.state = TaskState.COMPLETED
			if type(self.on_complete) == "function" then
				self.on_complete(self.output_buffer)
			end
			self:cleanup()
			append_to_qf({ "任务完成: " .. self.task.label })
		end,

		[TaskState.FAILED] = function()
			self.state = TaskState.FAILED
			if type(self.on_fail) == "function" then
				self.on_fail(self.output_buffer)
			end
			append_to_qf({ "任务执行失败: " .. self.task.label })
			self:cleanup()
		end,
	}

	if handlers[new_state] then
		handlers[new_state]() -- 无参数调用
	else
		self.state = new_state
	end
end

function TaskFSM:handle_output(data)
	if not data then
		return
	end

	-- 过滤空行
	local filtered = {}
	for _, line in ipairs(data) do
		if line ~= "" then
			table.insert(filtered, line)
		end
	end

	if #filtered == 0 then
		return
	end

	-- 缓存输出
	vim.list_extend(self.output_buffer, filtered)

	-- 调用任务自定义输出处理器
	if type(self.task.on_output) == "function" then
		self.task.on_output(filtered)
	end
end

function TaskFSM:handle_exit(code)
	-- 保存当前步骤的输出
	self.step_results[self.current_step] = self.output_buffer
	self.output_buffer = {}

	local current_step = self.task.steps and self.task.steps[self.current_step]

	-- 检查当前步骤是否失败
	if code ~= 0 then
		if current_step and current_step.on_fail then
			current_step.on_fail(self.step_results[self.current_step])
		end
	else
		if current_step and current_step.on_complete then
			current_step.on_complete(self.step_results[self.current_step])
		end
	end

	-- 任务链处理
	if self.task.steps and #self.task.steps > 0 then
		-- 移动到下一步
		self.current_step = self.current_step + 1

		if self.current_step <= #self.task.steps then
			-- 执行下一步
			append_to_qf({
				">>> 开始步骤 " .. self.current_step .. ": " .. self.task.steps[self.current_step].label,
			})
			self:run_current_step()
			return
		end
	end

	-- 整个任务完成
	if code == 0 then
		self:transition(TaskState.COMPLETED)
	else
		self:transition(TaskState.FAILED)
	end
end

function TaskFSM:run_current_step()
	local step = self.task.steps and self.task.steps[self.current_step]
	if not step then
		return
	end

	local cmd = step.cmd
	if type(cmd) == "function" then
		cmd = cmd()
	end

	if not cmd or #cmd == 0 then
		append_to_qf({ "跳过步骤 " .. self.current_step })
		self:handle_exit(0) -- 模拟成功退出以继续下一步
		return
	end

	self.job_id = M.start_job(cmd, {
		on_stdout = function(_, data)
			self:handle_output(data)
			append_to_qf(data)
		end,
		on_stderr = function(_, data)
			self:handle_output(data)
			append_to_qf(data)
		end,
		on_exit = function(_, code)
			self:handle_exit(code)
		end,
	})
end

function TaskFSM:start(task, callbacks)
	if self.state ~= TaskState.IDLE then
		vim.notify("任务已在运行中", vim.log.levels.WARN)
		return false
	end

	self.task = task
	self.on_complete = callbacks and callbacks.on_complete
	self.on_fail = callbacks and callbacks.on_fail
	self.output_buffer = {}
	self.current_step = 1
	self.step_results = {}

	-- 检查任务是否有多个步骤
	local is_multi_step = task.steps and #task.steps > 0

	-- 初始化QuickFix
	local title = is_multi_step and ("任务链: " .. task.label) or ("任务输出: " .. task.label)

	vim.fn.setqflist({}, " ", {
		title = title,
		lines = { "任务开始执行: " .. task.label },
	})
	vim.cmd("copen")

	self:transition(TaskState.RUNNING)
	return true
end

function TaskFSM:cleanup()
	self.job_id = nil
	self.task = nil
	self.output_buffer = {}
	self.current_step = 1
	self.step_results = {}
end

function TaskFSM:cancel()
	if self.state == TaskState.RUNNING and self.job_id then
		-- 使用 jobstop 替代 uv.process_kill
		vim.fn.jobstop(self.job_id)
		append_to_qf({ "任务已取消: " .. self.task.label })
	end
	self:cleanup()
	self.state = TaskState.IDLE
end

-- ======= 任务执行函数 =======
function M.start_job(cmd, opts)
	opts = opts or {}
	return vim.fn.jobstart(cmd, {
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = opts.on_stdout,
		on_stderr = opts.on_stderr,
		on_exit = opts.on_exit,
	})
end

-- ======= 对外暴露 =======
M.tasks = load_tasks_from_dir("tasks")

-- 活动任务状态机
M.active_task_fsm = TaskFSM:new()

function M.clear_task_cache()
	cached_tasks = {}
	vim.notify("任务缓存已清除", vim.log.levels.INFO)
end

function M.run_task(task)
	-- 验证任务是否有效
	if not task or not is_valid_task(task) then
		vim.notify("无效的任务", vim.log.levels.ERROR)
		return
	end

	-- 设置错误格式
	setup_errorformat(detect_project_type())

	-- 启动任务状态机
	M.active_task_fsm:start(task, {
		on_complete = function(output)
			vim.notify("任务完成: " .. task.label, vim.log.levels.INFO)
			if task.on_complete then
				task.on_complete(output)
			end
		end,
		on_fail = function(output)
			vim.notify("任务失败: " .. task.label, vim.log.levels.ERROR)
			if task.on_fail then
				task.on_fail(output)
			end
		end,
	})
end

function M.cancel_task()
	M.active_task_fsm:cancel()
	vim.notify("当前任务已取消", vim.log.levels.WARN)
end

function M.get_task_status()
	return M.active_task_fsm.state
end

function M.get_active_task()
	if M.active_task_fsm.state ~= TaskState.IDLE then
		return M.active_task_fsm.task
	end
	return nil
end

function M.build()
	local project_type = detect_project_type()
	local available_tasks = {}

	for _, task in ipairs(M.tasks) do
		if task.project_type == project_type or task.project_type == "any" then
			table.insert(available_tasks, task)
		end
	end

	if #available_tasks == 0 then
		vim.notify("没有可用构建任务", vim.log.levels.WARN)
		return
	end

	vim.ui.select(available_tasks, {
		prompt = " 任务列表   ",
		format_item = function(item)
			local status_icon = ""
			local active_task = M.get_active_task()

			if active_task and active_task == item then
				if M.active_task_fsm.state == TaskState.RUNNING then
					status_icon = " " -- 运行中图标
				elseif M.active_task_fsm.state == TaskState.COMPLETED then
					status_icon = " " -- 完成图标
				elseif M.active_task_fsm.state == TaskState.FAILED then
					status_icon = " " -- 失败图标
				end
			end
			return item.label .. status_icon
		end,
	}, function(choice)
		if choice then
			M.run_task(choice)
		end
	end)
end

-- 注册用户命令
vim.api.nvim_create_user_command("Build", function()
	M.build()
end, {})

vim.api.nvim_create_user_command("CancelTask", function()
	M.cancel_task()
end, {})

-- 自动命令：当退出 Neovim 时取消正在运行的任务
vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		if M.active_task_fsm.state == TaskState.RUNNING then
			M.cancel_task()
		end
	end,
})

return M
