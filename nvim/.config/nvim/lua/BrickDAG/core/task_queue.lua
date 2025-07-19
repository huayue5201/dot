-- lua/brickdag/core/task_queue.lua
local M = {}

-- 内部任务队列表
local task_queue = {}

-- 回调函数列表
local change_callbacks = {}

--- 添加队列变化回调
--- @param callback function 回调函数
function M.register_callback(callback)
	table.insert(change_callbacks, callback)
end

--- 通知队列变化
local function notify_change()
	for _, callback in ipairs(change_callbacks) do
		pcall(callback, task_queue)
	end
end

--- 添加任务到队列
--- @param task table
function M.enqueue(task)
	table.insert(task_queue, task)
	notify_change()
end

--- 返回当前队列中的所有任务
--- @return table[]
function M.all()
	return task_queue
end

--- 检查任务是否在队列中
--- @param task_id string 任务ID
--- @return boolean
function M.contains(task_id)
	for _, task in ipairs(task_queue) do
		if task.id == task_id then
			return true
		end
	end
	return false
end

--- 切换任务在队列中的状态
--- @param task table 任务对象
--- @return boolean 操作后任务是否在队列中
function M.toggle(task)
	local found_index = nil

	for i, t in ipairs(task_queue) do
		if t.id == task.id then
			found_index = i
			break
		end
	end

	if found_index then
		table.remove(task_queue, found_index)
		notify_change()
		return false
	else
		table.insert(task_queue, task)
		notify_change()
		return true
	end
end

--- 清空整个任务队列
function M.clear()
	task_queue = {}
	notify_change()
end

--- 移除指定位置的任务
--- @param index integer
function M.remove(index)
	table.remove(task_queue, index)
	notify_change()
end

--- 将任务上移一位
--- @param index integer
function M.move_up(index)
	if index > 1 and index <= #task_queue then
		task_queue[index], task_queue[index - 1] = task_queue[index - 1], task_queue[index]
		notify_change()
	end
end

--- 将任务下移一位
--- @param index integer
function M.move_down(index)
	if index < #task_queue then
		task_queue[index], task_queue[index + 1] = task_queue[index + 1], task_queue[index]
		notify_change()
	end
end

return M
