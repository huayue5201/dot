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
	local set = vim.api.nvim_buf_set_keymap

	-- 向右进入：l
	set(bufnr, "n", "l", "", {
		callback = function()
			display_ctrl.navigate_into_task()
		end,
		desc = "进入任务依赖",
	})

	-- 向左返回：h
	set(bufnr, "n", "h", "", {
		callback = function()
			display_ctrl.navigate_back()
		end,
		desc = "返回上层任务",
	})

	-- 向下选择：j
	set(bufnr, "n", "j", "", {
		callback = function()
			display_ctrl.navigate_selection(1)
		end,
		desc = "选择下一个任务",
	})

	-- 向上选择：k
	set(bufnr, "n", "k", "", {
		callback = function()
			display_ctrl.navigate_selection(-1)
		end,
		desc = "选择上一个任务",
	})
end

return M
