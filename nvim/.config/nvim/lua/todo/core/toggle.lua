-- lua/todo/core/toggle.lua
local M = {}

---------------------------------------------------------------------
-- 切换任务状态（包含递归切换子任务）
---------------------------------------------------------------------

local function toggle_task_and_children(task, bufnr, new_status)
	-- 切换当前任务
	local line = vim.api.nvim_buf_get_lines(bufnr, task.line_num - 1, task.line_num, false)[1]
	if line then
		if new_status then
			-- 设置特定状态
			local new_line = new_status and line:gsub("%[ %]", "[x]") or line:gsub("%[[xX]%]", "[ ]")
			vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
			task.is_done = new_status
		else
			-- 切换状态
			if line:match("%[ %]") then
				local new_line = line:gsub("%[ %]", "[x]")
				vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
				task.is_done = true
				new_status = true
			else
				local new_line = line:gsub("%[[xX]%]", "[ ]")
				vim.api.nvim_buf_set_lines(bufnr, task.line_num - 1, task.line_num, false, { new_line })
				task.is_done = false
				new_status = false
			end
		end
	end

	-- 递归切换子任务
	for _, child in ipairs(task.children) do
		toggle_task_and_children(child, bufnr, new_status)
	end
end

function M.toggle_line(bufnr, lnum)
	local parser = require("todo.core.parser")
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local tasks = parser.parse_tasks(lines)

	-- 找到当前行的任务
	local current_task = nil
	for _, task in ipairs(tasks) do
		if task.line_num == lnum then
			current_task = task
			break
		end
	end

	if not current_task then
		return false, "不是任务行"
	end

	-- 切换任务及其子任务
	toggle_task_and_children(current_task, bufnr, nil)

	return true, current_task.is_done
end

return M
