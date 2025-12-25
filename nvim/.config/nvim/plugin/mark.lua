local marks = {}
local current_index = nil
local preview_win = nil
local preview_buf = nil
local timer = vim.loop.new_timer()
local ns = vim.api.nvim_create_namespace("mark_preview")
local mark_display_ns = vim.api.nvim_create_namespace("mark_display")

-- 获取所有大写 mark
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
				col = m.pos[3],
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

-- 显示预览浮窗
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

	vim.api.nvim_buf_clear_namespace(preview_buf, ns, 0, -1)

	if current_index and current_index >= 1 and current_index <= #lines then
		vim.api.nvim_buf_set_extmark(preview_buf, ns, current_index - 1, 0, {
			hl_group = "Visual",
			end_line = current_index,
		})
	end
end

-- 在行首左侧悬浮显示标记符号（不挤压代码）
local function display_marks_at_left_side()
	local cur_buf = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(cur_buf) then
		return
	end

	vim.api.nvim_buf_clear_namespace(cur_buf, mark_display_ns, 0, -1)

	local all_marks = get_all_marks()

	local marks_by_line = {}
	for _, m in ipairs(all_marks) do
		if m.buf == cur_buf then
			marks_by_line[m.line] = marks_by_line[m.line] or {}
			table.insert(marks_by_line[m.line], m)
		end
	end

	for line_num, marks_in_line in pairs(marks_by_line) do
		local line_index = line_num - 1

		table.sort(marks_in_line, function(a, b)
			if a.is_upper ~= b.is_upper then
				return a.is_upper
			end
			return a.name < b.name
		end)

		local mark_texts = {}
		for _, m in ipairs(marks_in_line) do
			table.insert(mark_texts, m.name)
		end
		local display_text = table.concat(mark_texts, ",")

		local has_upper = false
		for _, m in ipairs(marks_in_line) do
			if m.is_upper then
				has_upper = true
				break
			end
		end
		local hl_group = has_upper and "MarkSignUpper" or "MarkSignLower"

		vim.api.nvim_buf_set_extmark(cur_buf, mark_display_ns, line_index, 0, {
			virt_text = { { display_text, hl_group } },
			virt_text_pos = "overlay",
			virt_text_win_col = -1,
			hl_mode = "blend",
			priority = 50,
		})
	end
end

-- 跳转函数
local function do_jump()
	if not current_index or not marks[current_index] then
		return
	end

	-- 记录跳转前的光标位置（即上次位置）
	local last_line = vim.fn.line("'\"")
	local last_col = vim.fn.col("'\"")

	local m = marks[current_index]

	pcall(function()
		if m.buf ~= 0 and vim.api.nvim_buf_is_valid(m.buf) then
			vim.api.nvim_set_current_buf(m.buf)
			vim.api.nvim_win_set_cursor(0, { m.line, m.col })
		else
			if m.file and m.file ~= "" then
				vim.cmd("edit " .. vim.fn.fnameescape(m.file))
				vim.api.nvim_win_set_cursor(0, { m.line, m.col })
			end
		end
	end)

	-- 关闭预览窗口
	if preview_win and vim.api.nvim_win_is_valid(preview_win) then
		vim.api.nvim_win_close(preview_win, true)
		preview_win = nil
	end

	display_marks_at_left_side()

	-- ⭐ 跳回上次光标位置（精确到行列）
	if last_line > 0 and last_col > 0 then
		pcall(function()
			vim.api.nvim_win_set_cursor(0, { last_line, last_col })
		end)
	end
end

-- 防抖跳转
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

-- 高亮定义
vim.cmd([[
  highlight MarkSignUpper guifg=#FFFFFF guibg=#DAA520 gui=italic
  highlight MarkSignLower guifg=#FFFFFF guibg=#0088FF gui=italic
]])

-- 监听标记设置事件
vim.api.nvim_create_autocmd("MarkSet", {
	callback = function()
		display_marks_at_left_side()
	end,
})

-- 监听各种事件以确保标记显示刷新
vim.api.nvim_create_autocmd({
	"BufEnter",
	"BufWritePost",
	"BufLeave",
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
