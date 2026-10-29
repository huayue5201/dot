-- https://github.com/wsdjeg/calendar.nvim
-- 本地 fork：~/neovim-plugins/calendar.nvim（上游 marked_days 不重置的 bug 已在 fork 修掉，
-- PR 见分支 fix/marks-reset；上游合并后把 dir 换成 src 即可）
--
-- 集成方式：只做「时间维度提示」——把当前项目里有到期日（todo2 的 @YYYY-MM-DD）的任务
-- 在月历上打点，<CR> 的作用域留给 calendar 自己的 extension actions。
-- 任务本体仍在 <leader>md 抽屉 / <leader>mtD 里操作。

local function due_marks(year, month)
	local marks = {}
	local ok, files = pcall(function()
		local project = require("todo2.utils.project")
		local fm = require("todo2.ui.file_manager")
		return fm.get_todo_files(project.get_project_name()) or {}
	end)
	if not ok then
		return marks
	end
	local sched = require("todo2.render.scheduler")
	local types = require("todo2.store.types")
	local prefix = ("%04d-%02d-"):format(year, month)

	local function walk(node, acc)
		-- 注意：parser 会把 status 置 nil（状态真源在 store），这里用 checkbox 反推
		if node.due and node.checkbox then
			local status = types.checkbox_to_status(node.checkbox:lower())
			if status ~= "completed" and status ~= "archived" then
				if vim.startswith(node.due, prefix) then
					local day = tonumber(node.due:sub(9, 10))
					if day and day >= 1 and day <= 31 then
						acc[#acc + 1] = { year = year, month = month, day = day }
					end
				end
			end
		end
		for _, child in ipairs(node.children or {}) do
			walk(child, acc)
		end
	end

	for _, path in ipairs(files) do
		local _, roots = sched.get_parse_tree(path)
		for _, root in ipairs(roots or {}) do
			walk(root, marks)
		end
	end
	return marks
end

return {
	dir = "~/neovim-plugins/calendar.nvim",
	name = "calendar.nvim",
	config = function()
		require("calendar").setup({
			mark_icon = "●",
			first_day_of_week = "monday",
			show_adjacent_days = true,
			highlights = { mark = "Todo2CalendarMark" },
		})

		vim.api.nvim_set_hl(0, "Todo2CalendarMark", { link = "DiagnosticWarn", default = true })

		require("calendar.extensions").register("todo2_due", { get = due_marks })

		-- 视图组（与 todo2 的 mf-/mt-/ma-/mv- 约定一致）
		vim.keymap.set("n", "<leader>mvc", "<cmd>Calendar<cr>", { desc = "日历：月历 + 任务到期标记" })
	end,
}
