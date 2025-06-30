-- 任务队列 (task_queue.lua)

local TaskQueue = {}
TaskQueue.__index = TaskQueue

local MIN_PRIORITY = 1
local MAX_PRIORITY = 10
local DEFAULT_PRIORITY = 5

function TaskQueue:new()
	return setmetatable({
		queue = {},
		history = {},
		max_history = 50,
		current_start_time = nil,
	}, self)
end

function TaskQueue:enqueue(task, priority)
	priority = priority or DEFAULT_PRIORITY

	if type(priority) ~= "number" or priority < MIN_PRIORITY or priority > MAX_PRIORITY then
		vim.notify(
			string.format("无效优先级 %d，使用默认值 %d", priority, DEFAULT_PRIORITY),
			vim.log.levels.WARN
		)
		priority = DEFAULT_PRIORITY
	else
		priority = math.floor(priority)
	end

	local item = {
		task = task,
		priority = priority,
		enqueue_time = os.time(),
	}

	table.insert(self.queue, item)

	table.sort(self.queue, function(a, b)
		if a.priority == b.priority then
			return a.enqueue_time < b.enqueue_time
		end
		return a.priority < b.priority
	end)

	return true
end

function TaskQueue:dequeue()
	return #self.queue > 0 and table.remove(self.queue, 1) or nil
end

function TaskQueue:remove(task_id)
	for i, item in ipairs(self.queue) do
		if item.task.id == task_id then
			table.remove(self.queue, i)
			return true
		end
	end
	return false
end

function TaskQueue:update_priority(task_id, new_priority)
	if type(new_priority) ~= "number" or new_priority < MIN_PRIORITY or new_priority > MAX_PRIORITY then
		vim.notify(string.format("更新优先级失败：无效优先级 %d", new_priority), vim.log.levels.ERROR)
		return false
	end

	new_priority = math.floor(new_priority)

	local found = false
	for _, item in ipairs(self.queue) do
		if item.task.id == task_id then
			item.priority = new_priority
			item.enqueue_time = os.time()
			found = true
			break
		end
	end

	if not found then
		vim.notify(string.format("更新优先级失败：未找到任务 %s", task_id), vim.log.levels.WARN)
		return false
	end

	table.sort(self.queue, function(a, b)
		if a.priority == b.priority then
			return a.enqueue_time < b.enqueue_time
		end
		return a.priority < b.priority
	end)

	return true
end

function TaskQueue:add_to_history(task, status, output, duration)
	local entry = {
		task = vim.deepcopy(task),
		status = status,
		output = output,
		start_time = self.current_start_time,
		end_time = os.time(),
		duration = duration,
	}

	table.insert(self.history, 1, entry)

	if #self.history > self.max_history then
		table.remove(self.history)
	end
end

function TaskQueue:get_history_by_task(task_id)
	return vim.tbl_filter(function(item)
		return item.task.id == task_id
	end, self.history)
end

function TaskQueue:clear()
	self.queue = {}
end

function TaskQueue:get_queue_items()
	return self.queue
end

function TaskQueue:get_history()
	return self.history
end

return TaskQueue
