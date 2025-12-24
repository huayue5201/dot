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
local function do_jump()
	if not current_index or not marks[current_index] then
		return
	end

	local m = marks[current_index]
	local cur_buf = vim.api.nvim_get_current_buf()

	-- ⭐ 如果 mark 属于当前 buffer，则跳到下一个 mark
	if vim.api.nvim_buf_is_valid(m.buf) and m.buf == cur_buf then
		-- 移动到下一个 index
		current_index = current_index + 1
		if current_index > #marks then
			current_index = 1
		end
		return do_jump() -- 递归跳到下一个
	end

	local bufnr

	-- 如果 buffer 无效，尝试打开文件
	if not vim.api.nvim_buf_is_valid(m.buf) then
		vim.cmd("edit " .. vim.fn.fnameescape(m.file))
		bufnr = vim.api.nvim_get_current_buf()
	else
		bufnr = m.buf
		vim.api.nvim_set_current_buf(bufnr)
	end

	-- 确保 buffer 出现在 :ls
	vim.bo[bufnr].buflisted = true

	-- 修正行号
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	local target_line = math.max(1, math.min(m.line, line_count))

	-- 修正列号
	local line_text = vim.api.nvim_buf_get_lines(bufnr, target_line - 1, target_line, false)[1] or ""
	local max_col = #line_text
	local target_col = math.max(0, math.min(m.col, max_col))

	-- 最终跳转
	vim.api.nvim_win_set_cursor(0, { target_line, target_col })

	-- 关闭预览窗口
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
