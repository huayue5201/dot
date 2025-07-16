local display_ctrl = require("BrickDAG.ui.task_display_controller")

local M = {}

function M.render(bufnr, ctx)
	local tasks = ctx.data or {}
	local selected_index = ctx.selected_index or 1

	local lines = {}
	for i, task in ipairs(tasks) do
		local status = task.done and "✔" or "⏳"
		local prefix = (i == selected_index) and "> " or "  "
		local line = string.format("%s[%d] %s %s", prefix, i, status, task.name or "(未命名)")
		table.insert(lines, line)
	end

	if #tasks == 0 then
		table.insert(lines, "> 无任务")
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false

	M.attach_keymaps(bufnr)
end

function M.attach_keymaps(bufnr)
	-- 回车键：深入任务
	vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		callback = function()
			display_ctrl.navigate_into_task()
		end,
	})

	-- 退格键：返回上层
	vim.api.nvim_buf_set_keymap(bufnr, "n", "<BS>", "", {
		callback = function()
			display_ctrl.navigate_back()
		end,
	})

	-- 上下导航
	vim.api.nvim_buf_set_keymap(bufnr, "n", "<Up>", "", {
		callback = function()
			display_ctrl.navigate_selection(-1)
		end,
	})

	vim.api.nvim_buf_set_keymap(bufnr, "n", "<Down>", "", {
		callback = function()
			display_ctrl.navigate_selection(1)
		end,
	})
end

return M
