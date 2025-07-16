local M = {}

--- 获取任务中的可视字段名
--- @param task table
--- @return string[]
function M.get_task_fields(task)
	local result = {}

	-- 如果任务类型是 frame 或 base
	local task_type = task.type
	if task_type and task[task_type] and type(task[task_type]) == "table" then
		for k, _ in pairs(task[task_type]) do
			table.insert(result, k)
		end
	end

	return result
end

--- 获取任务中某字段的值（分解为展示列表）
--- @param task table
--- @param field string
--- @return string[]|table[] 值列表（统一格式化为字符串）
function M.get_field_values(task, field)
	local values = {}
	local task_type = task.type

	if not task_type or not task[task_type] then
		return values
	end

	local raw = task[task_type][field]
	if raw == nil then
		return values
	end

	if type(raw) == "table" then
		for _, item in ipairs(raw) do
			table.insert(values, tostring(item))
		end
	elseif type(raw) == "string" or type(raw) == "number" or type(raw) == "boolean" then
		table.insert(values, tostring(raw))
	else
		table.insert(values, vim.inspect(raw)) -- fallback
	end

	return values
end

return M
