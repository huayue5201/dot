-- lua/todo/manager.lua
local store = require("todo.store")
local json_store = require("user.json_store")
local M = {}

---------------------------------------------------------------------
-- qf: QuickFix 显示当前项目中代码文件的双链标记
---------------------------------------------------------------------
function M.show_project_links_qf()
	-- 获取当前项目信息
	local project_info = json_store.get_current_project()
	local project_root = project_info.root

	-- 获取所有代码链接
	local all_code = store.get_all_code_links() or {}

	local qf = {}

	for id, c in pairs(all_code) do
		-- 检查是否在当前项目目录下
		local is_in_project = c.path:sub(1, #project_root) == project_root

		if is_in_project then
			-- 获取对应的 TODO 链接信息
			local todo_link = store.get_todo_link(id)

			-- 构建显示文本
			local display_text = string.format("[%s] ", id)

			if todo_link then
				-- 显示对应的 TODO 文件信息
				local todo_filename = vim.fn.fnamemodify(todo_link.path, ":t")
				display_text = display_text .. string.format("→ %s:%d", todo_filename, todo_link.line)
			else
				display_text = display_text .. "孤立的标记"
			end

			table.insert(qf, {
				filename = c.path,
				lnum = c.line,
				text = display_text,
			})
		end
	end

	if #qf == 0 then
		vim.notify("当前项目中没有代码双链标记", vim.log.levels.WARN)
		return
	end

	-- 按文件名和行号排序
	table.sort(qf, function(a, b)
		if a.filename == b.filename then
			return a.lnum < b.lnum
		end
		return a.filename < b.filename
	end)

	vim.fn.setqflist(qf, "r")
	vim.cmd("copen")

	-- 添加 QuickFix 窗口的键盘映射
	vim.defer_fn(function()
		local qf_winid = vim.fn.getqflist({ winid = 0 }).winid
		if qf_winid > 0 then
			local bufnr = vim.api.nvim_win_get_buf(qf_winid)
			if bufnr > 0 then
				vim.keymap.set("n", "<CR>", function()
					local items = vim.fn.getqflist()
					local cur_line = vim.fn.line(".")
					local item = items[cur_line]
					if item then
						vim.cmd("cclose")
						vim.cmd("edit " .. vim.fn.fnameescape(item.filename))
						vim.fn.cursor(item.lnum, 1)
						vim.cmd("normal! zz")
					end
				end, { buffer = bufnr, desc = "跳转到标记位置" })

				vim.keymap.set("n", "q", function()
					vim.cmd("cclose")
				end, { buffer = bufnr, desc = "关闭 QuickFix" })
			end
		end
	end, 100)
end

---------------------------------------------------------------------
-- fx: LocList 显示当前 buffer 双链标记
---------------------------------------------------------------------
local function scan_buffer_links()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local links = {}

	for lnum, line in ipairs(lines) do
		local id = line:match("TODO:ref:(%w+)")
		if id then
			local todo = store.get_todo_link(id)
			table.insert(links, {
				filename = vim.api.nvim_buf_get_name(bufnr),
				lnum = lnum,
				text = todo and string.format("CODE → TODO %s:%d", todo.path, todo.line) or "孤立的代码标记",
			})
		end

		local id2 = line:match("{#(%w+)}")
		if id2 then
			local code = store.get_code_link(id2)
			table.insert(links, {
				filename = vim.api.nvim_buf_get_name(bufnr),
				lnum = lnum,
				text = code and string.format("TODO → CODE %s:%d", code.path, code.line) or "孤立的 TODO 标记",
			})
		end
	end

	return links
end

function M.show_buffer_links_loclist()
	local items = scan_buffer_links()
	if #items == 0 then
		vim.notify("当前 buffer 没有双链标记")
		return
	end

	vim.fn.setloclist(0, items, "r")
	vim.cmd("lopen")
end

---------------------------------------------------------------------
-- 快速修复：删除当前 buffer 的孤立标记
---------------------------------------------------------------------
function M.fix_orphan_links_in_buffer()
	local bufnr = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	local removed_count = 0

	-- 从后往前删除，避免行号变化
	for i = #lines, 1, -1 do
		local line = lines[i]
		local id = line:match("TODO:ref:(%w+)")
		if id then
			local todo = store.get_todo_link(id)
			if not todo then
				-- 询问是否删除
				local confirm =
					vim.fn.input(string.format("删除孤立的代码标记 '%s'? (y/n): ", line:sub(1, 40)))
				if confirm:lower() == "y" then
					vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, {})
					removed_count = removed_count + 1
				end
			end
		end

		local id2 = line:match("{#(%w+)}")
		if id2 then
			local code = store.get_code_link(id2)
			if not code then
				local confirm =
					vim.fn.input(string.format("删除孤立的 TODO 标记 '%s'? (y/n): ", line:sub(1, 40)))
				if confirm:lower() == "y" then
					vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, {})
					removed_count = removed_count + 1
				end
			end
		end
	end

	if removed_count > 0 then
		vim.notify(string.format("清理了 %d 个孤立的标记", removed_count), vim.log.levels.INFO)
	else
		vim.notify("没有发现孤立的标记", vim.log.levels.INFO)
	end
end

---------------------------------------------------------------------
-- 简单统计：只统计当前项目的代码标记
---------------------------------------------------------------------
function M.show_stats()
	-- 获取当前项目信息
	local project_info = json_store.get_current_project()
	local project_root = project_info.root

	-- 获取所有代码链接
	local all_code = store.get_all_code_links() or {}
	local all_todo = store.get_all_todo_links() or {}

	-- 统计当前项目的代码标记
	local project_code_count = 0
	for _, c in pairs(all_code) do
		if c.path:sub(1, #project_root) == project_root then
			project_code_count = project_code_count + 1
		end
	end

	-- 统计当前项目的 TODO 标记
	local project_todo_count = 0
	for _, t in pairs(all_todo) do
		if t.path:sub(1, #project_root) == project_root then
			project_todo_count = project_todo_count + 1
		end
	end

	-- 统计当前 buffer 的标记
	local buffer_links = scan_buffer_links()
	local buffer_orphan_count = 0
	for _, link in ipairs(buffer_links) do
		if link.text:match("孤立的") then
			buffer_orphan_count = buffer_orphan_count + 1
		end
	end

	-- 显示统计信息
	local message = string.format(
		"📊 双链标记统计（当前项目）\n"
			.. "━━━━━━━━━━━━━━━━━━━━\n"
			.. "• 项目代码标记: %d\n"
			.. "• 项目 TODO 标记: %d\n"
			.. "• 当前 buffer 标记: %d\n"
			.. "• 当前 buffer 孤立标记: %d\n\n"
			.. "💡 提示：\n"
			.. "  qf 只显示当前项目的代码标记\n"
			.. "  fx 显示当前 buffer 的所有标记",
		project_code_count,
		project_todo_count,
		#buffer_links,
		buffer_orphan_count
	)

	-- 创建浮动窗口显示统计
	local lines = vim.split(message, "\n")
	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, #line)
	end
	width = math.min(width + 4, 80)
	local height = #lines + 2

	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = "双链标记统计",
	})

	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_win_set_option(win, "winhl", "Normal:NormalFloat")

	-- 设置关闭键
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf })

	vim.keymap.set("n", "<ESC>", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf })
end

return M
