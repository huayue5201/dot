local marks = {}
local current_index = nil
local preview_win = nil
local preview_buf = nil
local timer = vim.loop.new_timer()
local ns = vim.api.nvim_create_namespace("mark_preview") -- 固定 namespace

-- 获取所有大写 mark（更健壮）
local function get_upper_marks()
	local raw = vim.fn.getmarklist()
	local result = {}

	for _, m in ipairs(raw) do
		-- 提取大写字母（更安全）
		local name = m.mark:match("%u")
		if name then
			local bufnr = m.pos[1]
			local lnum = m.pos[2]
			local col = m.pos[3]

			local file
			if bufnr ~= 0 and vim.api.nvim_buf_is_valid(bufnr) then
				file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":p")
			else
				-- 文件 mark（无有效 buffer）
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

	-- 按文件路径排序（更符合用户预期）
	table.sort(result, function(a, b)
		if a.file == b.file then
			return a.line < b.line
		else
			return a.file < b.file
		end
	end)

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

	for i, m in ipairs(marks) do
		local line = string.format("%s %s:%d", m.name, m.file, m.line)
		table.insert(lines, line)

		local w = vim.fn.strdisplaywidth(line)
		if w > max_width then
			max_width = w
		end
	end

	vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)

	-- 限制最大宽度，避免超出屏幕
	local win_width = math.min(max_width + 4, math.floor(vim.o.columns * 0.5))
	local win_height = math.min(#lines, 10)
	local win_col = math.max(2, vim.o.columns - win_width - 2)

	setup_preview_win(win_width, win_height, win_col)

	-- 清除旧高亮
	vim.api.nvim_buf_clear_namespace(preview_buf, ns, 0, -1)

	vim.api.nvim_buf_set_extmark(preview_buf, ns, current_index - 1, 0, {
		hl_group = "Visual",
		end_line = current_index,
	})
end

-- 跳转函数，确保跳转前的文件加载和缓冲区状态正确
local last_cursor = {}

vim.api.nvim_create_autocmd("CursorMoved", {
	callback = function()
		local bufnr = vim.api.nvim_get_current_buf()
		last_cursor[bufnr] = vim.api.nvim_win_get_cursor(0)
	end,
})

local function do_jump()
	if not current_index or not marks[current_index] then
		return
	end

	-- ⭐ 记录当前 buffer 的光标位置
	local cur_buf = vim.api.nvim_get_current_buf()
	last_cursor[cur_buf] = vim.api.nvim_win_get_cursor(0)

	local tried = 0

	while tried < #marks do
		local m = marks[current_index]

		if not (vim.api.nvim_buf_is_valid(m.buf) and m.buf == cur_buf) then
			local bufnr

			if not vim.api.nvim_buf_is_valid(m.buf) then
				vim.cmd("edit " .. vim.fn.fnameescape(m.file))
				bufnr = vim.api.nvim_get_current_buf()
			else
				bufnr = m.buf
				vim.api.nvim_set_current_buf(bufnr)
			end

			vim.bo[bufnr].buflisted = true

			-- ⭐ 跳转后恢复该 buffer 的上一次光标位置
			if last_cursor[bufnr] then
				pcall(vim.api.nvim_win_set_cursor, 0, last_cursor[bufnr])
			end

			-- 关闭预览窗口
			if preview_win then
				vim.api.nvim_win_close(preview_win, true)
				preview_win = nil
			end

			return
		end

		tried = tried + 1
		current_index = current_index + 1
		if current_index > #marks then
			current_index = 1
		end
	end

	-- 如果走到这里，说明所有大写 mark 都在当前 buffer → 不跳
	-- 你可以选择在这里关闭预览窗口或者什么都不做
	if preview_win then
		vim.api.nvim_win_close(preview_win, true)
		preview_win = nil
	end
end

-- 防抖跳转（避免闪烁）
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

-- 下一个 mark
local function next_mark()
	update_mark(1)
end

-- 上一个 mark
local function prev_mark()
	update_mark(-1)
end

-- 将所有大写标记放入 QuickFix List
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
			col = m.col + 1, -- 修复 col 0-based 问题
			text = string.format("%s:%d %s", m.file, m.line, m.name),
		})
	end

	vim.fn.setqflist(qf_items)
	vim.cmd("copen")
end

vim.keymap.set("n", "<c-h>", next_mark)
vim.keymap.set("n", "<c-l>", prev_mark)
vim.keymap.set("n", "<leader>mq", populate_qf_list, { desc = "Populate quickfix list with uppercase marks" })
