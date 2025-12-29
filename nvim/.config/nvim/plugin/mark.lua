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
	end

	local lines = {}
	local max_width = 0

	for _, m in ipairs(marks) do
		local line = string.format("%s %s:%d", m.name, m.file, m.line)
		table.insert(lines, line)
		max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
	end

	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

	local win_width = math.min(max_width + 4, math.floor(vim.o.columns * 0.5))
	local win_height = math.min(#lines, 10)
	local win_col = math.max(2, vim.o.columns - win_width - 2)

	local config = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = 2,
		col = win_col,
		style = "minimal",
		border = "shadow",
	}

	if not preview_win or not vim.api.nvim_win_is_valid(preview_win) then
		preview_win = vim.api.nvim_open_win(preview_buf, false, config)
	else
		vim.api.nvim_win_set_config(preview_win, config)
	end

	vim.api.nvim_buf_clear_namespace(preview_buf, ns_preview, 0, -1)
	if idx then
		vim.api.nvim_buf_set_extmark(preview_buf, ns_preview, idx - 1, 0, {
			hl_group = "Visual",
			end_line = idx,
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
		vim.api.nvim_win_set_cursor(0, { mark.line, mark.col })
	end)

	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		vim.api.nvim_win_close(preview_win, true)
		preview_win = nil
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
		200,
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
	local mark = vim.fn.input("Delete mark: ")
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
