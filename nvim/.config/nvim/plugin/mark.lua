---------------------------------------------------------
-- State
---------------------------------------------------------
local current_index = nil
local preview_win = nil
local preview_buf = nil
local timer = vim.loop.new_timer()
local pending = false

local ns_preview = vim.api.nvim_create_namespace("mark_preview")
local ns_display = vim.api.nvim_create_namespace("mark_display")

---------------------------------------------------------
-- 获取所有大写 mark（全局）
---------------------------------------------------------
local function get_upper_marks()
	local raw = vim.fn.getmarklist()
	local result = {}

	for _, m in ipairs(raw) do
		local name = m.mark:match("%u")
		if name then
			local bufnr = m.pos[1]
			local file = bufnr ~= 0 and vim.api.nvim_buf_get_name(bufnr) or m.file or ""
			table.insert(result, {
				name = name,
				buf = bufnr,
				line = m.pos[2],
				col = m.pos[3],
				file = vim.fn.fnamemodify(file, ":p"),
			})
		end
	end

	table.sort(result, function(a, b)
		if a.file == b.file then
			return a.line < b.line
		else
			return a.file < b.file
		end
	end)

	return result
end

---------------------------------------------------------
-- 获取所有标记（大小写）
---------------------------------------------------------
local function get_all_marks()
	local result = {}
	local cur_buf = vim.api.nvim_get_current_buf()

	-- 大写（全局）
	for _, m in ipairs(vim.fn.getmarklist()) do
		local name = m.mark:match("%u")
		if name then
			table.insert(result, {
				name = name,
				buf = m.pos[1],
				line = m.pos[2],
				col = m.pos[3],
				file = m.file or "",
				is_upper = true,
			})
		end
	end

	-- 小写（当前 buffer）
	for _, m in ipairs(vim.fn.getmarklist(cur_buf)) do
		local name = m.mark:match("%l")
		if name then
			table.insert(result, {
				name = name,
				buf = cur_buf,
				line = m.pos[2],
				col = m.pos[3],
				file = vim.api.nvim_buf_get_name(cur_buf),
				is_upper = false,
			})
		end
	end

	return result
end

---------------------------------------------------------
-- 左侧 UI：直接清空 namespace 再渲染
---------------------------------------------------------
local function display_marks_at_left_side()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local all = get_all_marks()
	local marks_by_line = {}

	for _, m in ipairs(all) do
		if m.buf == buf then
			marks_by_line[m.line] = marks_by_line[m.line] or {}
			table.insert(marks_by_line[m.line], m)
		end
	end

	vim.api.nvim_buf_clear_namespace(buf, ns_display, 0, -1)

	for line, list in pairs(marks_by_line) do
		table.sort(list, function(a, b)
			if a.is_upper ~= b.is_upper then
				return a.is_upper
			end
			return a.name < b.name
		end)

		local col_offset = -2
		for _, m in ipairs(list) do
			local hl = m.is_upper and "MarkSignUpper" or "MarkSignLower"
			vim.api.nvim_buf_set_extmark(buf, ns_display, line - 1, 0, {
				virt_text = { { m.name, hl } },
				virt_text_pos = "overlay",
				virt_text_win_col = col_offset,
				hl_mode = "combine",
				priority = 50,
			})
			col_offset = col_offset - 1
		end
	end
end

---------------------------------------------------------
-- 预览窗口（纯函数）
---------------------------------------------------------
local function show_preview(marks, idx)
	if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then
		preview_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = preview_buf })
	end

	---------------------------------------------------------
	-- 构造内容（两行结构：路径行 + 代码行）
	---------------------------------------------------------
	local lines = {}
	local max_width = 0

	for _, m in ipairs(marks) do
		local path = vim.fn.fnamemodify(m.file, ":p")

		-- 读取代码行
		local code = ""
		if m.buf ~= 0 and vim.api.nvim_buf_is_valid(m.buf) then
			local ok, text = pcall(vim.api.nvim_buf_get_lines, m.buf, m.line - 1, m.line, false)
			if ok and text and text[1] then
				code = text[1]:gsub("^%s+", "")
			end
		end

		-- 第一行：路径
		local line1 = string.format("%s  %s  %d", m.name, path, m.line)

		-- 第二行：缩进 4 空格 + 代码
		local line2 = "     " .. code

		table.insert(lines, line1)
		table.insert(lines, line2)

		max_width = math.max(max_width, vim.fn.strdisplaywidth(line1), vim.fn.strdisplaywidth(line2))
	end

	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

	---------------------------------------------------------
	-- 自动匹配内容宽度
	---------------------------------------------------------
	local content_width = max_width + 4
	local max_allowed = vim.o.columns - 4
	local win_width = math.min(content_width, max_allowed)
	local win_height = math.min(#lines, 20)
	local win_col = vim.o.columns - win_width - 2

	local config = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = 2,
		col = win_col,
		style = "minimal",
		border = "shadow",
		focusable = false,
	}

	if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
		preview_win = vim.api.nvim_open_win(preview_buf, false, config)
	else
		vim.api.nvim_win_set_config(preview_win, config)
	end

	---------------------------------------------------------
	-- 清除旧高亮
	---------------------------------------------------------
	vim.api.nvim_buf_clear_namespace(preview_buf, ns_preview, 0, -1)

	---------------------------------------------------------
	-- 高亮（路径行 + 代码行）
	---------------------------------------------------------
	local row = 0
	for _, m in ipairs(marks) do
		local path = vim.fn.fnamemodify(m.file, ":p")
		local dir = vim.fn.fnamemodify(path, ":h") .. "/"
		local file = vim.fn.fnamemodify(path, ":t")

		-- 第一行：路径行
		local name_col = 0
		local dir_col_start = 3
		local dir_col_end = dir_col_start + #dir
		local file_col_start = dir_col_end
		local file_col_end = file_col_start + #file
		local line_col = file_col_end + 2
		local line_len = #tostring(m.line)

		-- mark 名字
		vim.api.nvim_buf_set_extmark(preview_buf, ns_preview, row, name_col, {
			end_col = 1,
			hl_group = "MarkPreviewName",
		})

		-- 目录
		vim.api.nvim_buf_set_extmark(preview_buf, ns_preview, row, dir_col_start, {
			end_col = dir_col_end,
			hl_group = "MarkPreviewDir",
		})

		-- 文件名
		vim.api.nvim_buf_set_extmark(preview_buf, ns_preview, row, file_col_start, {
			end_col = file_col_end,
			hl_group = "MarkPreviewFile",
		})

		-- 行号
		vim.api.nvim_buf_set_extmark(preview_buf, ns_preview, row, line_col, {
			end_col = line_col + line_len,
			hl_group = "MarkPreviewLine",
		})

		-- 第二行：代码行（整行高亮）
		vim.api.nvim_buf_set_extmark(preview_buf, ns_preview, row + 1, 4, {
			end_col = #lines[row + 2] or 999,
			hl_group = "MarkPreviewCode",
		})

		row = row + 2
	end

	---------------------------------------------------------
	-- 高亮当前项（整行背景）
	---------------------------------------------------------
	if idx then
		local start_row = (idx - 1) * 2
		vim.api.nvim_buf_set_extmark(preview_buf, ns_preview, start_row, 0, {
			hl_group = "MarkPreviewCurrent",
			end_line = start_row + 2,
		})
	end
end

---------------------------------------------------------
-- 跳转 + 防抖
---------------------------------------------------------
local function do_jump(mark)
	if not mark then
		return
	end

	pcall(function()
		if mark.buf ~= 0 and vim.api.nvim_buf_is_valid(mark.buf) then
			vim.api.nvim_set_current_buf(mark.buf)
		else
			if mark.file and mark.file ~= "" then
				vim.cmd("edit " .. vim.fn.fnameescape(mark.file))
			end
		end
		-- vim.api.nvim_win_set_cursor(0, { mark.line, mark.col })
		vim.api.nvim_win_set_cursor(0, { mark.line, mark.col + 1 })
	end)

	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		vim.api.nvim_win_close(preview_win, true)
	end

	display_marks_at_left_side()
end

local function schedule_jump(fn)
	if pending then
		return
	end
	pending = true

	timer:stop()
	timer:start(
		300,
		0,
		vim.schedule_wrap(function()
			pending = false
			fn()
		end)
	)
end

local function update_mark(direction)
	local marks = get_upper_marks()
	if #marks == 0 then
		return
	end

	current_index = (current_index or 1) + direction
	if current_index > #marks then
		current_index = 1
	end
	if current_index < 1 then
		current_index = #marks
	end

	show_preview(marks, current_index)
	schedule_jump(function()
		do_jump(marks[current_index])
	end)
end

local function next_mark()
	update_mark(1)
end
local function prev_mark()
	update_mark(-1)
end

---------------------------------------------------------
-- Quickfix / Loclist
---------------------------------------------------------
local function populate_qf_list()
	local marks = get_upper_marks()
	if #marks == 0 then
		return
	end

	local qf = {}
	for _, m in ipairs(marks) do
		table.insert(qf, {
			filename = m.file,
			lnum = m.line,
			col = m.col + 1,
			text = string.format("%s:%d %s", m.file, m.line, m.name),
		})
	end

	vim.fn.setqflist(qf)
	vim.cmd("copen")
end

local function populate_loclist_lower_marks()
	local buf = vim.api.nvim_get_current_buf()
	local raw = vim.fn.getmarklist(buf)
	local items = {}

	for _, m in ipairs(raw) do
		local name = m.mark:match("%l")
		if name then
			table.insert(items, {
				bufnr = buf,
				lnum = m.pos[2],
				col = m.pos[3] + 1,
				text = string.format("%s:%d %s", vim.api.nvim_buf_get_name(buf), m.pos[2], name),
			})
		end
	end

	if #items == 0 then
		print("No lowercase marks in current buffer")
		return
	end

	vim.fn.setloclist(0, items)
	vim.cmd("lopen")
end

---------------------------------------------------------
-- 高亮
---------------------------------------------------------
vim.cmd([[
  highlight MarkSignUpper guifg=#FFFFFF guibg=#8B6969 gui=italic
  highlight MarkSignLower guifg=#FFFFFF guibg=#0088FF gui=italic
   highlight MarkPreviewDir  guifg=#de773f
  highlight MarkPreviewFile guifg=#00D7FF gui=bold
  highlight MarkPreviewLine guifg=#87FF5F gui=bold
  highlight MarkPreviewName guifg=#d64f44 gui=bold
  highlight MarkPreviewCode   guifg=#7c8577
  highlight MarkPreviewCurrent guibg=#3A3A3A
]])

---------------------------------------------------------
-- 自动刷新事件
---------------------------------------------------------
vim.api.nvim_create_autocmd({ "MarkSet" }, {
	callback = display_marks_at_left_side,
})

-- 使用 CursorHold 替代 CursorMoved 事件
vim.api.nvim_create_autocmd("CursorHold", {
	callback = display_marks_at_left_side,
})
---------------------------------------------------------
-- 清除所有标记
---------------------------------------------------------
vim.keymap.set("n", "<leader>cam", function()
	vim.cmd("delmarks a-zA-Z0-9")
	-- vim.cmd("delmarks \"'[]<>")
end, { desc = "Delete all marks" })

---------------------------------------------------------
-- 删除单个标记
---------------------------------------------------------
vim.keymap.set("n", "<leader>cm", function()
	local marks = get_all_marks()
	if #marks == 0 then
		print("No marks to delete")
		return
	end

	-- 打开预览窗口（复用你已有的 show_preview）
	show_preview(marks, nil)

	-- 输入 mark 名字
	local mark = vim.fn.input("Delete mark: ")

	-- 输入结束后关闭预览窗口
	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		vim.api.nvim_win_close(preview_win, true)
	end

	if mark ~= "" then
		vim.cmd("delmarks " .. mark)
		vim.schedule(function()
			display_marks_at_left_side()
		end)
	end
end, { desc = "Delete specific mark" })

---------------------------------------------------------
-- 初始化
---------------------------------------------------------
vim.schedule(display_marks_at_left_side)

---------------------------------------------------------
-- 键映射
---------------------------------------------------------
vim.keymap.set("n", "H", next_mark, {
	desc = "Jump to next uppercase mark",
})

vim.keymap.set("n", "L", prev_mark, {
	desc = "Jump to previous uppercase mark",
})

vim.keymap.set("n", "<leader>mq", populate_qf_list, {
	desc = "Populate quickfix list with uppercase marks",
})

vim.keymap.set("n", "<leader>ml", populate_loclist_lower_marks, {
	desc = "Populate loclist with lowercase marks",
})
