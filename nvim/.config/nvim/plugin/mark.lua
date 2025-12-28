local marks = {}
local current_index = nil
local preview_win = nil
local preview_buf = nil
local timer = vim.loop.new_timer()

-- namespaces
local ns = vim.api.nvim_create_namespace("mark_preview")
local mark_display_ns = vim.api.nvim_create_namespace("mark_display")

-- 每行绑定 extmark id：cache[bufnr][line] = { { key="A", id=11 }, { key="a", id=12 } }
local mark_cache = {}

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
			local lnum = m.pos[2]
			local col = m.pos[3]

			local file
			if bufnr ~= 0 and vim.api.nvim_buf_is_valid(bufnr) then
				file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
			else
				file = m.file and vim.fn.fnamemodify(m.file, ":p") or ""
			end

			table.insert(result, {
				name = name,
				buf = bufnr,
				line = lnum,
				col = col,
				file = file,
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
-- 获取所有标记（包括大小写）
---------------------------------------------------------
local function get_all_marks()
	local result = {}

	-- 大写 mark（全局）
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

	-- 小写 mark（当前 buffer）
	local cur_buf = vim.api.nvim_get_current_buf()
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
-- 预览窗口
---------------------------------------------------------
local function setup_preview_win(win_width, win_height, win_col)
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
end

local function show_preview()
	if not preview_buf or not vim.api.nvim_buf_is_valid(preview_buf) then
		preview_buf = vim.api.nvim_create_buf(false, true)
	end

	local lines = {}
	local max_width = 0

	for _, m in ipairs(marks) do
		local line = string.format("%s %s:%d", m.name, m.file, m.line)
		table.insert(lines, line)
		local w = vim.fn.strdisplaywidth(line)
		if w > max_width then
			max_width = w
		end
	end

	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

	local win_width = math.min(max_width + 4, math.floor(vim.o.columns * 0.5))
	local win_height = math.min(#lines, 10)
	local win_col = math.max(2, vim.o.columns - win_width - 2)

	setup_preview_win(win_width, win_height, win_col)

	-- 清理旧高亮
	vim.api.nvim_buf_clear_namespace(preview_buf, ns, 0, -1)

	if current_index and current_index >= 1 and current_index <= #lines then
		vim.api.nvim_buf_set_extmark(preview_buf, ns, current_index - 1, 0, {
			hl_group = "Visual",
			end_line = current_index,
		})
	end
end

---------------------------------------------------------
-- 左侧 UI：每个标记独立 extmark（独立背景色）
---------------------------------------------------------
local function clear_mark_line(buf, line)
	local buf_cache = mark_cache[buf]
	if not buf_cache then
		return
	end

	local entries = buf_cache[line]
	if entries then
		for _, entry in ipairs(entries) do
			pcall(vim.api.nvim_buf_del_extmark, buf, mark_display_ns, entry.id)
		end
	end

	buf_cache[line] = nil
end

local function render_mark_line(buf, line, marks_in_line)
	mark_cache[buf] = mark_cache[buf] or {}
	local buf_cache = mark_cache[buf]

	-- 删除旧 extmark
	clear_mark_line(buf, line)
	buf_cache[line] = {}

	-- 排序：大写优先，然后字母排序
	table.sort(marks_in_line, function(a, b)
		if a.is_upper ~= b.is_upper then
			return a.is_upper
		end
		return a.name < b.name
	end)

	-- 从右往左渲染
	local col_offset = -2

	for _, m in ipairs(marks_in_line) do
		local hl = m.is_upper and "MarkSignUpper" or "MarkSignLower"

		local id = vim.api.nvim_buf_set_extmark(buf, mark_display_ns, line - 1, 0, {
			virt_text = { { m.name, hl } },
			virt_text_pos = "overlay",
			virt_text_win_col = col_offset,
			hl_mode = "combine",
			priority = 50,
		})

		table.insert(buf_cache[line], {
			key = m.name,
			id = id,
			hl = hl,
		})

		col_offset = col_offset - #m.name
	end
end

local function display_marks_at_left_side()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local all_marks = get_all_marks()
	local marks_by_line = {}

	for _, m in ipairs(all_marks) do
		if m.buf == buf then
			marks_by_line[m.line] = marks_by_line[m.line] or {}
			table.insert(marks_by_line[m.line], m)
		end
	end

	mark_cache[buf] = mark_cache[buf] or {}
	local buf_cache = mark_cache[buf]

	-- 清理无 mark 的行
	for line, _ in pairs(buf_cache) do
		if not marks_by_line[line] then
			clear_mark_line(buf, line)
		end
	end

	-- 渲染有 mark 的行
	for line, marks_in_line in pairs(marks_by_line) do
		render_mark_line(buf, line, marks_in_line)
	end
end

---------------------------------------------------------
-- 跳转逻辑
---------------------------------------------------------
local function do_jump()
	if not current_index or not marks[current_index] then
		return
	end

	local m = marks[current_index]

	pcall(function()
		if m.buf ~= 0 and vim.api.nvim_buf_is_valid(m.buf) then
			vim.api.nvim_set_current_buf(m.buf)
		else
			if m.file and m.file ~= "" then
				vim.cmd("edit " .. vim.fn.fnameescape(m.file))
			end
		end
	end)

	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		vim.api.nvim_win_close(preview_win, true)
		preview_win = nil
	end

	display_marks_at_left_side()
end

-- 防抖跳转（可保留）
local pending = false
local function schedule_jump()
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
			do_jump()
		end)
	)
end

local function update_mark(direction)
	marks = get_upper_marks()
	if #marks == 0 then
		return
	end

	if not current_index then
		current_index = 1
	else
		current_index = current_index + direction
		if current_index > #marks then
			current_index = 1
		elseif current_index < 1 then
			current_index = #marks
		end
	end

	show_preview()
	schedule_jump()
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
	marks = get_upper_marks()
	if #marks == 0 then
		return
	end

	local qf_items = {}
	for _, m in ipairs(marks) do
		table.insert(qf_items, {
			filename = m.file,
			lnum = m.line,
			col = m.col + 1,
			text = string.format("%s:%d %s", m.file, m.line, m.name),
		})
	end

	vim.fn.setqflist(qf_items)
	vim.cmd("copen")
end

local function populate_loclist_lower_marks()
	local cur_buf = vim.api.nvim_get_current_buf()
	local raw = vim.fn.getmarklist(cur_buf)
	local items = {}

	for _, m in ipairs(raw) do
		local name = m.mark:match("%l")
		if name then
			table.insert(items, {
				bufnr = cur_buf,
				lnum = m.pos[2],
				col = m.pos[3] + 1,
				text = string.format("%s:%d %s", vim.api.nvim_buf_get_name(cur_buf), m.pos[2], name),
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
vim.api.nvim_create_autocmd("MarkSet", {
	callback = function()
		display_marks_at_left_side()
	end,
})

vim.api.nvim_create_autocmd({
	"BufEnter",
	"BufWritePost",
	"CursorMoved",
	"TextChanged",
	"TextChangedI",
	"InsertLeave",
}, {
	callback = display_marks_at_left_side,
})

---------------------------------------------------------
-- 清除所有标记
---------------------------------------------------------
vim.api.nvim_create_user_command("ClearAllMarks", function()
	vim.cmd("delmarks a-zA-Z0-9")
	vim.cmd("delmarks \"'[]<>")

	local marks_list = vim.fn.getmarklist()
	for _, mark in ipairs(marks_list) do
		local m = mark.mark
		if m:match("[A-Z]") then
			vim.cmd("delmarks " .. m)
		end
	end

	mark_cache = {}
	display_marks_at_left_side()
end, {})

---------------------------------------------------------
-- 删除单个标记
---------------------------------------------------------
vim.keymap.set("n", "<leader>cm", function()
	local mark = vim.fn.input("Delete mark: ")
	if mark ~= "" then
		vim.cmd("delmarks " .. mark)
		display_marks_at_left_side()
	end
end, { desc = "Delete specific mark" })

---------------------------------------------------------
-- 初始化
---------------------------------------------------------
vim.schedule(function()
	display_marks_at_left_side()
end)

---------------------------------------------------------
-- 键映射
---------------------------------------------------------
vim.keymap.set("n", "<leader>cam", ":ClearAllMarks<CR>", { desc = "Delete all marks" })
vim.keymap.set("n", "H", next_mark)
vim.keymap.set("n", "L", prev_mark)
vim.keymap.set("n", "<leader>mq", populate_qf_list, { desc = "Populate quickfix list with uppercase marks" })
vim.keymap.set("n", "<leader>ml", populate_loclist_lower_marks, {
	desc = "Populate loclist with lowercase marks",
})
