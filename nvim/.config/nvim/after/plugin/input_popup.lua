local existing_window, existing_buffer

-- 判断是否允许使用浮动输入框
local disabled_types = {
	buftype = {
		"nofile",
		"prompt",
		"quickfix",
		"terminal",
		"help",
	},
	filetype = {
		"dap-repl",
		"TelescopePrompt",
		"NvimTree",
		"neo-tree",
	},
}

local function is_disabled()
	local buftype = vim.bo.buftype
	local filetype = vim.bo.filetype
	return vim.tbl_contains(disabled_types.buftype, buftype) or vim.tbl_contains(disabled_types.filetype, filetype)
end

-- 输入框位置：相对于光标
local function under_cursor(input_width)
	return {
		relative = "cursor",
		row = 1,
		col = 0,
		width = input_width + 2,
		height = 1, -- 固定高度为 1 行
	}
end

-- 关闭窗口函数
local function close_window(window, buffer, on_confirm)
	vim.cmd("stopinsert")
	vim.api.nvim_win_close(window, true)
	on_confirm(nil)
end

-- 输入框函数
local function input(opts, on_confirm, win_config)
	if is_disabled() then
		vim.notify("当前 buffer 类型不支持浮动输入", vim.log.levels.DEBUG)
		return vim.ui.input_orig(opts, on_confirm) -- 使用原始输入框作为降级方案
	end

	local prompt = opts.prompt or "Input: "
	local default = opts.default or ""
	local multiline = opts.multiline or false
	on_confirm = on_confirm or function() end

	-- 计算输入框宽度
	local default_width = vim.fn.strdisplaywidth(default) + 10
	local prompt_width = vim.fn.strdisplaywidth(prompt) + 10
	local input_width = math.max(default_width, prompt_width) + 20

	local default_win_config = {
		focusable = true,
		style = "minimal",
		border = "rounded",
		width = input_width,
		height = 1, -- 固定高度
		title = prompt,
	}

	-- 合并窗口配置
	win_config = vim.tbl_deep_extend("force", default_win_config, win_config or {})
	win_config = vim.tbl_deep_extend("force", win_config, under_cursor(input_width))

	-- 如果已有窗口则重用
	if existing_window and vim.api.nvim_win_is_valid(existing_window) then
		vim.api.nvim_buf_set_text(existing_buffer, 0, 0, 0, 0, { default })
		vim.api.nvim_win_set_cursor(existing_window, { 1, vim.str_utfindex(default) + 1 })
		vim.cmd("startinsert")
		existing_window, existing_buffer = nil, nil
		return
	end

	-- 创建新的窗口和缓冲区
	local buffer = vim.api.nvim_create_buf(false, true)
	local window = vim.api.nvim_open_win(buffer, true, win_config)
	vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { default })
	vim.api.nvim_win_set_option(window, "statuscolumn", "")

	existing_window = window
	existing_buffer = buffer

	-- 进入插入模式
	vim.cmd("startinsert")
	vim.api.nvim_win_set_cursor(window, { 1, vim.str_utfindex(default) + 1 })

	-- 输入历史记录
	local input_history = {}
	local hist_index = 0

	-- 回车确认
	vim.keymap.set({ "n", "i", "v" }, "<CR>", function()
		local lines = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)
		local text = lines[1]
		if text and text ~= "" then
			table.insert(input_history, text)
			hist_index = #input_history -- 更新历史索引
		end
		on_confirm(text)
		close_window(window, buffer, on_confirm)
	end, { buffer = buffer })

	-- Ctrl+Enter 提交多行
	if multiline then
		vim.keymap.set("i", "<C-CR>", function()
			local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
			local text = table.concat(lines, "\n")
			if text and text ~= "" then
				table.insert(input_history, text)
				hist_index = #input_history
			end
			on_confirm(text)
			close_window(window, buffer, on_confirm)
		end, { buffer = buffer })
	end

	-- 上下键切换历史
	vim.keymap.set("i", "<Up>", function()
		if hist_index > 1 then
			hist_index = hist_index - 1
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { input_history[hist_index] })
		end
	end, { buffer = buffer })

	vim.keymap.set("i", "<Down>", function()
		if hist_index < #input_history then
			hist_index = hist_index + 1
			vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { input_history[hist_index] })
		end
	end, { buffer = buffer })

	-- 自动关闭浮动窗口
	local augroup = vim.api.nvim_create_augroup("FloatingInputAutoClose", { clear = true })
	vim.api.nvim_create_autocmd({ "CursorMoved", "BufLeave" }, {
		buffer = buffer,
		group = augroup,
		once = true,
		callback = function()
			close_window(window, buffer, on_confirm)
		end,
	})

	-- 取消操作
	local cancel = function()
		close_window(window, buffer, on_confirm)
	end
	vim.keymap.set("n", "<Esc>", cancel, { buffer = buffer })
	vim.keymap.set("n", "q", cancel, { buffer = buffer })
end

-- 保存原始输入接口，作为降级用
vim.ui.input_orig = vim.ui.input
vim.ui.input = input
