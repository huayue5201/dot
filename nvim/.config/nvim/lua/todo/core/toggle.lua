-- lua/todo/core/toggle.lua
local M = {}

local function replace_status(bufnr, lnum, from, to)
	local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1]
	if not line then
		return false
	end

	local start_col, end_col = line:find(from)
	if not start_col then
		return false
	end

	vim.api.nvim_buf_set_text(bufnr, lnum - 1, start_col - 1, lnum - 1, end_col, { to })

	return true
end

local function toggle_task_and_children(task, bufnr, new_status)
	if new_status == nil then
		new_status = not task.is_done
	end

	local success
	if new_status then
		success = replace_status(bufnr, task.line_num, "%[ %]", "[x]")
	else
		success = replace_status(bufnr, task.line_num, "%[[xX]%]", "[ ]")
	end

	if success then
		task.is_done = new_status
	end

	-- 递归切换子任务（无论父任务是否成功）
	for _, child in ipairs(task.children) do
		toggle_task_and_children(child, bufnr, new_status)
	end
end

function M.toggle_line(bufnr, lnum)
	local parser = require("todo.core.parser")
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = parser.parse_tasks(lines)

	local current_task
	for _, task in ipairs(tasks) do
		if task.line_num == lnum then
			current_task = task
			break
		end
	end

	if not current_task then
		return false, "不是任务行"
	end

	toggle_task_and_children(current_task, bufnr, nil)
	return true, current_task.is_done
end

return M
