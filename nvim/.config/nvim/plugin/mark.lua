local marks = {}
local current_index = nil
local preview_win = nil
local preview_buf = nil
local timer = vim.loop.new_timer()
local ns = vim.api.nvim_create_namespace("mark_preview")
local mark_display_ns = vim.api.nvim_create_namespace("mark_display")

-- 缓存：用于增量更新 & 预览
local last_marks_by_buf = {} -- [bufnr][line] = "a,b,C"
local last_preview_index = nil -- 上次高亮的行

-- 防抖工具函数
local function debounce(fn, delay)
	local timer = vim.loop.new_timer()
	return function(...)
		local args = { ... }
		timer:stop()
		timer:start(delay, 0, function()
			vim.schedule(function()
				fn(unpack(args))
			end)
		end)
	end
end

-- 获取所有大写 mark（全局）
-- 注意：m.pos = { bufnr, lnum(1-based), col(0-based), off }
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
				col = col, -- 0-based
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

-- 获取所有标记（包括大小写）
local function get_all_marks()
	local result = {}

	-- 1. 获取全局 mark（大写）
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

	-- 2. 获取当前 buffer 的小写 mark
	local cur_buf = vim.api.nvim_get_current_buf()
	for _, m in ipairs(vim.fn.getmarklist(cur_buf)) do
		local name = m.mark:match("%l")
		if name then
			table.insert(result, {
				name = name,
				buf = cur_buf,
				line = m.pos[2],
				col = m.pos[3], -- 0-based
				file = vim.api.nvim_buf_get_name(cur_buf),
				is_upper = false,
			})
		end
	end

	return result
end

-- 设置或更新浮窗
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

-- 显示预览浮窗（优化版：尽量复用窗口，只更新高亮）
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

	-- 只更新高亮
	vim.api.nvim_buf_clear_namespace(preview_buf, ns, 0, -1)
	if current_index and current_index >= 1 and current_index <= #lines then
		vim.api.nvim_buf_set_extmark(preview_buf, ns, current_index - 1, 0, {
			hl_group = "Visual",
			end_line = current_index,
		})
		last_preview_index = current_index
	else
		last_preview_index = nil
	end
end

-- 内部函数：真正更新左侧 mark 显示（增量版）
local function _display_marks_at_left_side()
	local cur_buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(cur_buf) then
		return
	end

	if not last_marks_by_buf[cur_buf] then
		last_marks_by_buf[cur_buf] = {}
	end
	local cache = last_marks_by_buf[cur_buf]

	local all_marks = get_all_marks()
	local marks_by_line = {}

	for _, m in ipairs(all_marks) do
		if m.buf == cur_buf then
			marks_by_line[m.line] = marks_by_line[m.line] or {}
			table.insert(marks_by_line[m.line], m)
		end
	end

	-- 1. 清理已经没有 mark 的行
	for line, _ in pairs(cache) do
		if not marks_by_line[line] then
			vim.api.nvim_buf_clear_namespace(cur_buf, mark_display_ns, line - 1, line)
			cache[line] = nil
		end
	end

	-- 2. 更新有变化的行
	for line_num, marks_in_line in pairs(marks_by_line) do
		local line_index = line_num - 1

		table.sort(marks_in_line, function(a, b)
			if a.is_upper ~= b.is_upper then
				return a.is_upper
			end
			return a.name < b.name
		end)

		local is_upper = marks_in_line[1].is_upper
		local mark_texts = {}
		for _, m in ipairs(marks_in_line) do
			table.insert(mark_texts, m.name)
		end

		local text_key = table.concat(mark_texts, ",")
		if cache[line_num] ~= text_key then
			local hl_group = is_upper and "MarkSignUpper" or "MarkSignLower"

			vim.api.nvim_buf_set_extmark(cur_buf, mark_display_ns, line_index, 0, {
				virt_text = {
					{ text_key, hl_group },
				},
				-- virt_text_pos = "right_align", -- 更兼容的显示方式
				virt_text_pos = "overlay",
				virt_text_win_col = -2,
				hl_mode = "combine",
				priority = 50,
			})

			cache[line_num] = text_key
		end
	end
end

-- 防抖后的显示函数（减少频繁刷新）
local display_marks_at_left_side = debounce(_display_marks_at_left_side, 80)

-- Harpoon 风格跳转：只切 buffer，不跳行列
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

	-- 关闭预览窗口
	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		vim.api.nvim_win_close(preview_win, true)
		preview_win = nil
	end

	-- 重置索引，避免下次从旧位置开始
	-- current_index = nil

	display_marks_at_left_side()
end

-- 防抖跳转（避免快速 H/L 时频繁切换）
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

-- 更新当前 mark 并显示预览
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

-- 用大写 mark 填充 quickfix 列表
local function populate_qf_list()
	marks = get_upper_marks()
	if #marks == 0 then
		return
	end

	local qf_items = {}
	for _, m in ipairs(marks) do
		table.insert(qf_items, {
			filename = m.file,
			lnum = m.line, -- 1-based
			col = m.col + 1, -- 转为 1-based
			text = string.format("%s:%d %s", m.file, m.line, m.name),
		})
	end

	vim.fn.setqflist(qf_items)
	vim.cmd("copen")
end

-- 用小写 mark 填充 loclist
local function populate_loclist_lower_marks()
	local cur_buf = vim.api.nvim_get_current_buf()
	local raw = vim.fn.getmarklist(cur_buf)
	local items = {}

	for _, m in ipairs(raw) do
		local name = m.mark:match("%l")
		if name then
			table.insert(items, {
				bufnr = cur_buf,
				lnum = m.pos[2], -- 1-based
				col = m.pos[3] + 1, -- 0-based -> 1-based
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

-- 高亮定义
vim.cmd([[
  highlight MarkSignUpper guifg=#FFFFFF guibg=#8B6969 gui=italic
  highlight MarkSignLower guifg=#FFFFFF guibg=#0088FF gui=italic
  highlight MarkIconUpperPrefix guifg=#DAA520 guibg=NONE gui=bold
  highlight MarkIconLowerPrefix guifg=#0088FF guibg=NONE gui=bold
  highlight MarkIconUpper guifg=#DAA520 guibg=NONE gui=bold
  highlight MarkIconLower guifg=#0088FF guibg=NONE gui=bold
]])

-- 监听标记设置事件：mark 变动时刷新（走防抖）
vim.api.nvim_create_autocmd("MarkSet", {
	callback = function()
		display_marks_at_left_side()
	end,
})

-- 监听各种事件以确保标记显示刷新（走防抖）
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

-- 清除所有标记的命令
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
	last_marks_by_buf = {}
	display_marks_at_left_side()
end, {})

-- 删除特定标记的命令
vim.keymap.set("n", "<leader>cm", function()
	local mark = vim.fn.input("Delete mark: ")
	if mark ~= "" then
		vim.cmd("delmarks " .. mark)
		display_marks_at_left_side()
	end
end, { desc = "Delete specific mark" })

-- 初始化显示
vim.schedule(function()
	display_marks_at_left_side()
end)

-- 键映射
vim.keymap.set("n", "<leader>cam", ":ClearAllMarks<CR>", { desc = "Delete all marks" })
vim.keymap.set("n", "H", next_mark)
vim.keymap.set("n", "L", prev_mark)
vim.keymap.set("n", "<leader>mq", populate_qf_list, { desc = "Populate quickfix list with uppercase marks" })
vim.keymap.set("n", "<leader>ml", populate_loclist_lower_marks, {
	desc = "Populate loclist with lowercase marks",
})
