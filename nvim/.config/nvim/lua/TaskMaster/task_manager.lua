-- 任务管理器 (task_manager.lua)

local ui = require("TaskMaster.ui_manager")

local TaskManager = {}
TaskManager.__index = TaskManager

function TaskManager:new()
	local state_machine = require("TaskMaster.task_state_machine"):new()
	local repository = require("TaskMaster.task_repository"):new()
	local queue = require("TaskMaster.task_queue"):new()

	local o = setmetatable({
		state_machine = state_machine,
		repository = repository,
		queue = queue,
		global_env = vim.fn.environ() or {},
		notification = require("TaskMaster.notification"),
	}, self)

	o.executor = require("TaskMaster.task_executor"):new(state_machine, repository, o)
	repository.manager = o

	return o
end

function TaskManager:_merge_params(task, override)
	return vim.tbl_extend("force", task.params or {}, override or {})
end

function TaskManager:run_task_interactive(initial_params)
	local tasks = self.repository:get_all_tasks()
	ui.show_task_picker(tasks, function(selected_task_id)
		if not selected_task_id then
			return
		end

		local task = self.repository:get_task_by_id(selected_task_id)
		if not task then
			return
		end

		local combined_params = self:_merge_params(task, initial_params)

		if task.params and next(task.params) then
			self:get_task_params_interactive(task, combined_params, function(final_params)
				self:run_task(selected_task_id, final_params)
			end)
		else
			self:run_task(selected_task_id, combined_params)
		end
	end)
end

function TaskManager:get_task_params_interactive(task, initial_params, callback)
	local form_spec = {}
	for key, default in pairs(task.params or {}) do
		table.insert(form_spec, {
			field = key,
			label = key:gsub("_", " "):upper(),
			default = tostring(initial_params[key] or default),
		})
	end
	ui.show_input_form(form_spec, callback)
end

function TaskManager:run_task(id, params, on_finish)
	local task = self.repository:get_task_by_id(id)
	if not task then
		if on_finish then
			on_finish(false)
		end
		vim.notify("任务不存在: " .. id, vim.log.levels.ERROR)
		return false
	end

	self.current_on_finish = on_finish

	if task.depends_on then
		self:run_dependency_chain(task.depends_on, function(success)
			if success then
				self:_execute_single_task(task, params)
			else
				if self.current_on_finish then
					self.current_on_finish(false)
					self.current_on_finish = nil
				end
			end
		end)
	else
		self:_execute_single_task(task, params)
	end
	return true
end

function TaskManager:_execute_single_task(task, params)
	local task_to_run = vim.deepcopy(task)
	task_to_run.params = self:_merge_params(task_to_run, params)
	self.queue.current_start_time = os.time()
	if task_to_run.on_start then
		task_to_run.on_start()
	end
	return self.executor:run_task(task_to_run)
end

function TaskManager:run_dependency_chain(dependencies, callback)
	local index = 1
	local function run_next()
		if index > #dependencies then
			callback(true)
			return
		end
		local dep_id = dependencies[index]
		index = index + 1
		self:run_task(dep_id, nil, function(success)
			if success then
				run_next()
			else
				callback(false)
			end
		end)
	end
	run_next()
end

function TaskManager:add_to_queue(task_id, priority, params)
	local task = self.repository:get_task_by_id(task_id)
	if not task then
		vim.notify("任务不存在: " .. task_id, vim.log.levels.ERROR)
		return false
	end

	local queued_task = vim.deepcopy(task)
	queued_task.params = self:_merge_params(queued_task, params)
	return self.queue:enqueue(queued_task, priority)
end

function TaskManager:cancel_current()
	return self.executor:cancel_current()
end

function TaskManager:run_next_queued()
	local item = self.queue:dequeue()
	if item and item.task then
		return self:run_task(item.task.id, item.task.params)
	end
	return false
end

function TaskManager:interactive_add_to_queue()
	local tasks = self.repository:get_all_tasks()
	ui.show_task_picker(tasks, function(selected_task_id)
		if not selected_task_id then
			return
		end
		ui.show_priority_picker(function(priority)
			if priority then
				self:add_to_queue(selected_task_id, priority)
				vim.notify(
					string.format("任务 '%s' 已添加到队列 (优先级: P%d)", selected_task_id, priority),
					vim.log.levels.INFO
				)
			end
		end)
	end)
end

function TaskManager:init()
	self.repository:async_load_tasks(function()
		vim.defer_fn(function()
			local task_count = #vim.tbl_keys(self.repository:get_all_tasks())
			vim.notify("任务系统已初始化，加载了 " .. task_count .. " 个任务", vim.log.levels.INFO)
		end, 50)
	end)

	self:setup_commands()

	self.executor.state_machine.on_complete = function()
		if self.current_on_finish then
			self.current_on_finish(true)
			self.current_on_finish = nil
		end
		self:run_next_queued()
	end

	self.executor.state_machine.on_fail = function()
		if self.current_on_finish then
			self.current_on_finish(false)
			self.current_on_finish = nil
		end
		self:run_next_queued()
	end
end

function TaskManager:setup_commands()
	local function command(name, fn, opts)
		vim.api.nvim_create_user_command(name, fn, opts or {})
	end

	command("TaskRun", function(opts)
		local args = vim.split(opts.args, "%s+")
		local task_id = table.remove(args, 1)
		local params = {}
		for _, arg in ipairs(args) do
			local key, value = arg:match("([^=]+)=([^=]+)")
			if key and value then
				params[key] = value
			end
		end
		if task_id then
			self:run_task(task_id, params)
		else
			self:run_task_interactive(params)
		end
	end, { nargs = "*" })

	command("TaskQueueAdd", function()
		self:interactive_add_to_queue()
	end)
	command("TaskCancel", function()
		self:cancel_current()
	end)
	command("TaskList", function()
		self:show_task_list()
	end)
	command("TaskReload", function()
		self.repository:load_tasks()
		vim.notify("任务已重新加载")
	end)
	command("TaskPicker", function()
		self:open_task_picker()
	end)
	command("TaskQueueUI", function()
		ui.show_task_queue(self.queue, self)
	end)

	command("TaskEnvSet", function(opts)
		local key, value = opts.args:match("([^=]+)=([^=]+)")
		if key and value then
			self.global_env[key] = value
			vim.notify("设置环境变量: " .. key .. "=" .. value)
		else
			vim.notify("格式错误，请使用 key=value 格式", vim.log.levels.ERROR)
		end
	end, { nargs = 1 })
	command("TaskMaster", function()
		self:open_main_ui()
	end)
end

function TaskManager:open_main_ui()
	local actions = {
		{ id = "run", label = "🚀 运行任务" },
		{ id = "queue", label = "📋 任务队列" },
		{ id = "history", label = "🕒 执行历史" },
		{ id = "env", label = "⚙️ 环境变量" },
		{ id = "reload", label = "🔄 重新加载" },
	}

	ui.show_action_picker(actions, function(selected)
		if selected == "run" then
			self:run_task_interactive()
		elseif selected == "queue" then
			ui.show_task_queue(self.queue, self)
		elseif selected == "history" then
			ui.show_task_history(self.queue)
		elseif selected == "env" then
			ui.show_env_manager(self.global_env)
		elseif selected == "reload" then
			self.repository:load_tasks()
			vim.notify("任务已重新加载")
		end
	end)
end

function TaskManager:open_task_picker()
	local tasks = self.repository:get_all_tasks()
	ui.show_task_picker(tasks, function(task_id)
		self:run_task(task_id)
	end)
end

function TaskManager:show_output_ui(task_id, output)
	local task = self.repository:get_task_by_id(task_id)
	ui.show_task_output(output, task and task.label or "任务输出")
end

function TaskManager:show_task_list()
	local tasks = self.repository:get_all_tasks()
	local lines = { "可用任务列表:", "" }
	for id, task in pairs(tasks) do
		table.insert(lines, string.format("  %-20s : %s", id, task.label))
	end
	vim.api.nvim_echo({ { table.concat(lines, "\n") } }, false, {})
end

return TaskManager
