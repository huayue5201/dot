-- lua/todo/link/renderer.lua
local M = {}

-- ✅ 新写法（lazy require）
local store

local function get_store()
	if not store then
		store = require("todo2.store")
	end
	return store
end

---------------------------------------------------------------------
-- 自动同步：代码文件状态渲染
---------------------------------------------------------------------
local ns = vim.api.nvim_create_namespace("todo_status")

function M.render_code_status(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	local current_file = vim.api.nvim_buf_get_name(bufnr)
	if not current_file or current_file == "" then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if not lines then
		return
	end

	for i, line in ipairs(lines) do
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		local id = line:match("TODO:ref:(%w+)")
		if id then
			-- 使用 store 模块获取 TODO 链接
			local todo = get_store().get_todo_link(id)

			if todo then
				local file_ok, todo_lines = pcall(vim.fn.readfile, todo.path)
				if file_ok then
					local todo_line = todo_lines[todo.line]
					local status = todo_line and todo_line:match("%[(.)%]")

					local icon = (status == "x" or status == "X") and "✓" or "☐" -- ☑
					local text = (status == "x" or status == "X") and "已完成" or "未完成"

					-- 根据状态选择颜色
					local hl_group = (status == "x" or status == "X") and "String" or "Error"

					if vim.api.nvim_buf_is_valid(bufnr) then
						vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, -1, {
							virt_text = {
								{ "  " .. icon .. " " .. text, hl_group },
							},
							virt_text_pos = "eol",
							hl_mode = "combine",
						})
					end
				end
			end
		end
	end
end

return M
