-- lua/user/todo/render.lua
local M = {}

-- 你的命名空间
local ns = vim.api.nvim_create_namespace("todo_render")

---------------------------------------------------------------------
-- 清除所有 extmark
---------------------------------------------------------------------
function M.clear(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

---------------------------------------------------------------------
-- 渲染单个任务（删除线、灰色高亮、EOL 统计）
---------------------------------------------------------------------
function M.render_task(bufnr, task)
	local row = task.line_num - 1
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	local line_length = #line

	-------------------------------------------------------------------
	-- 删除线 + 灰色高亮（整行）
	-------------------------------------------------------------------
	if task.is_done then
		-- 删除线
		vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
			end_row = row,
			end_col = line_length,
			hl_group = "TodoStrikethrough",
			hl_mode = "combine",
			priority = 50,
		})

		-- 灰色高亮
		vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
			end_row = row,
			end_col = line_length,
			hl_group = "TodoCompleted",
			hl_mode = "combine",
			priority = 49,
		})
	end

	-------------------------------------------------------------------
	-- EOL 虚拟文本（统计）
	-------------------------------------------------------------------
	if task.children and #task.children > 0 and task.stats then
		vim.api.nvim_buf_set_extmark(bufnr, ns, row, -1, {
			virt_text = {
				{ string.format(" (%d/%d)", task.stats.done, task.stats.total), "Comment" },
			},
			virt_text_pos = "eol",
			hl_mode = "combine",
			right_gravity = false,
			priority = 100,
		})
	end
end

---------------------------------------------------------------------
-- 渲染所有根任务（递归）
---------------------------------------------------------------------
local function render_tree(bufnr, task)
	M.render_task(bufnr, task)
	for _, child in ipairs(task.children) do
		render_tree(bufnr, child)
	end
end

function M.render_all(bufnr, root_tasks)
	M.clear(bufnr)
	for _, t in ipairs(root_tasks) do
		render_tree(bufnr, t)
	end
end

return M
