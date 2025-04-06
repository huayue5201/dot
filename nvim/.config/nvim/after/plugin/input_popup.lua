-- 定义 under_cursor 函数
local function under_cursor(input_width)
	return {
		relative = "cursor", -- 相对于光标定位
		row = 1, -- 行数
		col = 0, -- 列数
		width = input_width + 2, -- 输入框宽度，稍微增加一点
	}
end

-- 定义 window_center 函数
local function window_center(input_width)
	return {
		relative = "win",
		row = vim.api.nvim_win_get_height(0) / 2 - 1,
		col = vim.api.nvim_win_get_width(0) / 2 - input_width / 2,
	}
end

-- 定义 close_window 函数，用于关闭窗口
local function close_window(window, buffer, on_confirm)
	vim.cmd("stopinsert") -- 停止插入模式
	vim.api.nvim_win_close(window, true) -- 关闭窗口
	on_confirm(nil) -- 调用回调函数
end

-- 输入框处理函数
local function input(opts, on_confirm, win_config)
	local prompt = opts.prompt or "Input: "
	local default = opts.default or ""
	on_confirm = on_confirm or function() end

	-- 计算默认文本和提示文本的宽度，并增加额外的宽度（20）
	local default_width = vim.fn.strdisplaywidth(default) + 10
	local prompt_width = vim.fn.strdisplaywidth(prompt) + 10
	local input_width = math.max(default_width, prompt_width) + 20 -- 这里增加了额外的宽度

	local default_win_config = {
		focusable = true,
		style = "minimal",
		border = "rounded",
		width = input_width,
		height = 1,
		title = prompt,
	}

	-- 合并传入的窗口配置
	win_config = vim.tbl_deep_extend("force", default_win_config, win_config or {})

	-- 如果已有输入框窗口且有效，重用它
	if existing_window and vim.api.nvim_win_is_valid(existing_window) then
		-- 仅更新缓冲区内容和光标位置，避免重新设置窗口配置
		vim.api.nvim_buf_set_text(existing_buffer, 0, 0, 0, 0, { default })
		vim.api.nvim_win_set_cursor(existing_window, { 1, vim.str_utfindex(default) + 1 })
		vim.cmd("startinsert")
		-- 重置窗口和缓冲区引用
		existing_window = nil
		existing_buffer = nil
		return
	end

	-- 如果没有现有窗口，则创建一个新的窗口
	win_config = vim.tbl_deep_extend("force", win_config, under_cursor(input_width))

	-- 创建新的缓冲区和窗口
	local buffer = vim.api.nvim_create_buf(false, true)
	local window = vim.api.nvim_open_win(buffer, true, win_config)
	vim.api.nvim_buf_set_text(buffer, 0, 0, 0, 0, { default })

	-- 禁用状态列，避免闪烁
	vim.api.nvim_win_set_option(window, "statuscolumn", "")

	-- 保存窗口和缓冲区引用，以便以后重用
	existing_window = window
	existing_buffer = buffer

	-- 设置光标并进入插入模式
	vim.cmd("startinsert")
	vim.api.nvim_win_set_cursor(window, { 1, vim.str_utfindex(default) + 1 })

	-- 处理确认事件
	vim.keymap.set({ "n", "i", "v" }, "<CR>", function()
		local lines = vim.api.nvim_buf_get_lines(buffer, 0, 1, false)
		on_confirm(lines[1])
		close_window(window, buffer, on_confirm) -- 关闭窗口并调用回调
	end, { buffer = buffer })

	-- 提取取消操作逻辑
	local cancel = function()
		close_window(window, buffer, on_confirm) -- 关闭窗口并调用回调
	end
	vim.keymap.set("n", "<Esc>", cancel, { buffer = buffer })
	vim.keymap.set("n", "q", cancel, { buffer = buffer })
end

vim.ui.input = input
