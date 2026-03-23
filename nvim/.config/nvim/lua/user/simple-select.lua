--- A simple implementation of vim.ui.select using a floating window.
--- Usage: vim.ui.select = require('simple-select')
return function(items, opts, on_choice)
	-- 边界处理：没有选项时直接回调 nil
	if #items == 0 then
		on_choice(nil)
		return
	end

	-- 防止重复回调的标志
	local called = false
	local function choice_callback(choice, idx)
		if not called then
			called = true
			on_choice(choice, idx)
		end
	end

	-- 创建临时缓冲区
	local bufnr = vim.api.nvim_create_buf(false, true)

	-- 格式化选项列表
	local lines = {}
	local max_length = 0
	local format_item = opts.format_item or tostring
	local title = opts.prompt or "Select one of:"
	local place_holder = opts.place_holder or "No items"

	for _, item in ipairs(items) do
		local line = format_item(item)
		table.insert(lines, line)
		max_length = math.max(max_length, #line)
	end

	-- 设置缓冲区内容
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.bo[bufnr].modifiable = false
	vim.bo[bufnr].bufhidden = "wipe" -- 缓冲区关闭时自动删除

	-- 计算窗口尺寸
	local win_width = math.min(math.max(max_length, #title), math.floor(vim.o.columns * 0.6))
	local win_height = math.min(#items, math.floor(vim.o.lines * 0.6))

	-- 获取边框样式
	local border = "single"
	if vim.fn.has("nvim-0.9") == 1 then
		border = vim.o.winborder or "single"
	end

	-- 创建浮动窗口
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = math.floor((vim.o.lines - win_height) / 2) - 1,
		col = math.floor((vim.o.columns - win_width) / 2),
		style = "minimal",
		border = border,
		title = title,
		title_pos = "center",
	})

	-- 设置窗口选项
	vim.wo[win].winfixbuf = true
	vim.wo[win].cursorline = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].wrap = false
	vim.wo[win].list = false

	-- 设置光标起始位置为第一行
	vim.api.nvim_win_set_cursor(win, { 1, 0 })

	-- 回车键：选择当前项
	vim.keymap.set("n", "<CR>", function()
		local cur_row = vim.api.nvim_win_get_cursor(win)[1]
		local idx = cur_row -- 行号即为索引（从1开始）
		if idx >= 1 and idx <= #items then
			vim.api.nvim_win_close(win, true)
			choice_callback(items[idx], idx - 1) -- 返回0索引
		else
			vim.api.nvim_win_close(win, true)
			choice_callback(nil)
		end
	end, { buffer = bufnr })

	-- ESC 键：取消选择
	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
		choice_callback(nil)
	end, { buffer = bufnr })

	-- q 键：取消选择
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(win, true)
		choice_callback(nil)
	end, { buffer = bufnr })

	-- j/k 键：上下移动（可选）
	vim.keymap.set("n", "j", function()
		local cur_row = vim.api.nvim_win_get_cursor(win)[1]
		local new_row = math.min(cur_row + 1, #items)
		vim.api.nvim_win_set_cursor(win, { new_row, 0 })
	end, { buffer = bufnr })

	vim.keymap.set("n", "k", function()
		local cur_row = vim.api.nvim_win_get_cursor(win)[1]
		local new_row = math.max(cur_row - 1, 1)
		vim.api.nvim_win_set_cursor(win, { new_row, 0 })
	end, { buffer = bufnr })

	-- 支持鼠标点击选择
	vim.keymap.set("n", "<LeftMouse>", function()
		local mouse_pos = vim.fn.getmousepos()
		if mouse_pos.winid == win then
			local cur_row = mouse_pos.line
			if cur_row >= 1 and cur_row <= #items then
				vim.api.nvim_win_close(win, true)
				choice_callback(items[cur_row], cur_row - 1)
			end
		end
	end, { buffer = bufnr })

	-- 窗口关闭事件：清理并回调 nil
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		callback = function()
			-- 避免重复回调
			if not called then
				choice_callback(nil)
			end
			-- 清理缓冲区
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end,
		once = true, -- 只触发一次
	})

	-- 可选：添加高亮当前行
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = bufnr,
		callback = function()
			vim.wo[win].cursorline = true
		end,
	})
end
