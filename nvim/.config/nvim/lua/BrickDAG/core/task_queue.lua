-- lua/BrickDAG/core/task_queue.lua

local M = {}

-- 内部任务队列表
local task_queue = {}

--- 添加任务到队列
---@param task table
function M.enqueue(task)
	table.insert(task_queue, task)
end

--- 返回当前队列中的所有任务
---@return table[]
function M.all()
	return task_queue
end

--- 清空整个任务队列
function M.clear()
	task_queue = {}
end

--- 移除指定位置的任务
---@param index integer
function M.remove(index)
	table.remove(task_queue, index)
end

--- 将任务上移一位
---@param index integer
function M.move_up(index)
	if index > 1 and index <= #task_queue then
		task_queue[index], task_queue[index - 1] = task_queue[index - 1], task_queue[index]
	end
end

--- 将任务下移一位
---@param index integer
function M.move_down(index)
	if index < #task_queue then
		task_queue[index], task_queue[index + 1] = task_queue[index + 1], task_queue[index]
	end
end

return M
