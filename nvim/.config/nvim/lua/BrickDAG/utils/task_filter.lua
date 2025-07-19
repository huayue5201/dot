-- lua/brickdag/utils/task_filter.lua
local M = {}

--- 条件评估辅助函数
--- @param condition any 条件配置（函数、表或值）
--- @param context_value any 当前上下文值
--- @return boolean 是否满足条件
local function evaluate_condition(condition, context_value)
	if condition == nil then
		-- 未配置条件，视为匹配
		return true
	elseif type(condition) == "function" then
		-- 动态函数条件
		return condition(context_value) == true
	elseif type(condition) == "table" then
		-- 静态列表条件
		for _, value in ipairs(condition) do
			if value == context_value then
				return true
			end
		end
		return false
	else
		-- 静态值条件
		return condition == context_value
	end
end

--- 任务过滤主函数
--- @param tasks table[] 任务列表
--- @return table[] 过滤后的任务列表
function M.filter(tasks)
	if not tasks or type(tasks) ~= "table" then
		return {}
	end

	local result = {}

	-- 获取当前上下文值
	local current_filetype = vim.bo.filetype or ""
	local current_cwd = vim.fn.getcwd()

	for _, task in ipairs(tasks) do
		-- 基本任务验证
		if type(task) == "table" and task.name and task.type then
			-- 文件类型过滤：有配置则按配置过滤，无配置则通过
			local filetype_ok = evaluate_condition(task.filetypes, current_filetype)

			-- 根目录过滤：有配置则按配置过滤，无配置则通过
			local root_ok = evaluate_condition(task.root_patterns, current_cwd)

			-- 组合条件（两者都必须通过）
			if filetype_ok and root_ok then
				table.insert(result, task)
			end
		end
	end

	return result
end

return M
