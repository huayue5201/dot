-- lua/BrickDAG/core/task_expander.lua

local M = {}

--- 展开任务结构，递归处理 composite/subtasks，生成完整扁平任务表
---@param task table 任务配置（可能包含 subtasks）
---@param parent_prefix string? 父任务路径前缀
---@return table[] 展开后的任务列表（每个带唯一 ID）
function M.expand(task, parent_prefix)
	assert(task.name, "任务必须包含 name 字段")

	local id = parent_prefix and (parent_prefix .. "/" .. task.name) or task.name
	local result = {}

	local flat_task = vim.deepcopy(task)
	flat_task.id = id
	flat_task.subtasks = nil -- 删除 subtasks，避免 DAG 误处理
	table.insert(result, flat_task)

	-- 处理 subtasks
	if task.subtasks and type(task.subtasks) == "table" then
		for _, subtask in ipairs(task.subtasks) do
			local subtasks = M.expand(subtask, id)
			vim.list_extend(result, subtasks)
		end
	end

	return result
end

--- 展开任务列表（多个根任务）
---@param tasks table[]
---@return table[]
function M.expand_all(tasks)
	local all = {}
	for _, task in ipairs(tasks) do
		local expanded = M.expand(task)
		vim.list_extend(all, expanded)
	end
	return all
end

return M
