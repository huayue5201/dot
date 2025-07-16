-- BrickDAG/ui/views/brick_list_view.lua

local M = {}

function M.render(bufnr, ctx)
	local bricks = ctx.data or {}
	local lines = {}
	M.line_map = {}

	for i, brick in ipairs(bricks) do
		local line = string.format("[%d] 🧱 %s (%s)", i, brick.type or "<未知类型>", brick.status or "未知")
		table.insert(lines, line)
		M.line_map[i] = brick
	end

	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].bufhidden = "wipe"

	M.attach_keymaps(bufnr, ctx)
end

function M.attach_keymaps(bufnr, ctx)
	vim.api.nvim_buf_set_keymap(bufnr, "n", "<CR>", "", {
		nowait = true,
		noremap = true,
		silent = true,
		callback = function()
			local row = vim.api.nvim_win_get_cursor(ctx.win)[1]
			local brick = M.line_map[row]
			if brick then
				-- 调用控制器展开积木详情或子积木
				local display = require("BrickDAG.ui.task_display_controller")
				display.show_brick(brick)
			end
		end,
	})
end

return M
