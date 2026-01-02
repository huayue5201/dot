-- lua/todo/ui/operations.lua
local M = {}

local core = require("todo.core")

---------------------------------------------------------------------
-- 批量切换任务状态（统一处理可视模式）
---------------------------------------------------------------------
function M.toggle_selected_tasks(bufnr, win)
	local start_line = vim.fn.line("v")
	local end_line = vim.fn.line(".")

	if start_line > end_line then
		start_line, end_line = end_line, start_line
	end

	local changed_count = 0

	for lnum = start_line, end_line do
		local success, _ = core.toggle_line(bufnr, lnum)
		if success then
			changed_count = changed_count + 1
		end
	end

	-- 退出可视模式
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)

	return changed_count
end

---------------------------------------------------------------------
-- 插入任务函数
---------------------------------------------------------------------
function M.insert_task(text, indent_extra, bufnr, ui_module)
	local target_buf = bufnr or vim.api.nvim_get_current_buf()
	local lnum = vim.fn.line(".")

	-- 获取当前行缩进
	local current_line = vim.api.nvim_buf_get_lines(target_buf, lnum - 1, lnum, false)[1] or ""
	local indent = current_line:match("^(%s*)") or ""
	indent = indent .. string.rep(" ", indent_extra or 0)

	-- 插入任务行
	local new_task_line = indent .. "- [ ] " .. (text or "新任务")
	vim.api.nvim_buf_set_lines(target_buf, lnum, lnum, false, { new_task_line })

	-- 移动光标到新行
	local new_lnum = lnum + 1
	vim.fn.cursor(new_lnum, 1)

	-- 更新虚拟文本和高亮
	if ui_module and ui_module.refresh then
		ui_module.refresh(target_buf)
	end

	-- 进入插入模式（在行尾）
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
end

return M
